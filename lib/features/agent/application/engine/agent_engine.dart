import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 任务写回抽象：引擎每次状态/统计变更都经这里落库并同步 UI 态。
abstract class AgentTaskGateway {
  Future<void> save(AgentTask task);
}

/// agent 专属控制工具（初稿 §5.4）：引擎内部处理，不进 executor。
const String kToolUpdatePlan = 'update_plan';
const String kToolAskUser = 'ask_user';
const String kToolFinishTask = 'finish_task';

/// 循环内核（循环设计稿 §3.1/§3.2）：纯编排，依赖全部注入。
/// 每步先落事件再继续（杀进程可恢复）；状态迁移全部出 StatusChangeEvent。
class AgentEngine {
  AgentEngine({
    required this.llm,
    required this.tools,
    required this.approval,
    required this.store,
    required this.gateway,
    required this.budget,
  });

  final AgentLlmClient llm;
  final AgentToolExecutor tools;
  final ApprovalGate approval;
  final AgentEventStore store;
  final AgentTaskGateway gateway;
  final AgentBudget budget;

  Future<void> run(AgentTask task, AgentCancellationToken cancel) async {
    var current = task;

    Future<AgentTask> save(AgentTask next) async {
      await gateway.save(next);
      return next;
    }

    Future<AgentTask> transition(
      AgentTaskStatus status,
      String description,
    ) async {
      await store.appendStatusChange(current.id, description);
      return save(current.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        lastEventSummary: description,
      ));
    }

    try {
      if (current.status != AgentTaskStatus.running) {
        current = await save(current.copyWith(
          status: AgentTaskStatus.running,
          updatedAt: DateTime.now(),
        ));
      }

      // 恢复语义（L7）：上次进程死亡时半途的工具调用（仍 running /
      // waitingApproval）按失败回填，重放时模型可重新发起并重过审批。
      await _backfillInterruptedToolCalls(current.id);

      while (true) {
        // ① 安全点：排队消息正式进上下文（L3）。
        await store.consumeQueuedUserMessages(current.id);

        // ② 取消/暂停/预算检查。
        if (cancel.cancelRequested) {
          current = await transition(AgentTaskStatus.cancelled, '用户强制终止');
          return;
        }
        if (cancel.pauseRequested) {
          current = await transition(AgentTaskStatus.paused, '用户暂停');
          return;
        }
        final over = budget.exceededReason;
        if (over != null) {
          current = await transition(AgentTaskStatus.paused, over);
          return;
        }

        // ③ 组上下文 + ④ LLM 流式调用（文本原位 upsert，L6）。
        budget.recordRound();
        current = await save(current.copyWith(
          rounds: current.rounds + 1,
          updatedAt: DateTime.now(),
        ));
        final events = await store.getEvents(current.id);
        AssistantTextEvent? textEvent;
        ReasoningEvent? reasoningEvent;
        DateTime? reasoningStart;
        // 增量落库串行化（同一事件 id 原位覆盖，避免乱序）。
        var pendingWrite = Future<void>.value();
        final turn = await llm.completeTurn(
          AgentLlmContext(task: current, events: events),
          cancel: cancel,
          onReasoningDelta: (reasoningSoFar) {
            reasoningStart ??= DateTime.now();
            pendingWrite = pendingWrite.then((_) async {
              reasoningEvent = reasoningEvent == null
                  ? await store.appendReasoning(current.id, reasoningSoFar,
                      streaming: true)
                  : await store.updateReasoning(
                      current.id, reasoningEvent!, reasoningSoFar,
                      streaming: true);
            });
          },
          onTextDelta: (textSoFar) {
            pendingWrite = pendingWrite.then((_) async {
              // 文本开始 → 思考定格（收起为"思考了 Xs"）。
              if (reasoningEvent != null && reasoningEvent!.streaming) {
                reasoningEvent = await store.updateReasoning(
                  current.id, reasoningEvent!, reasoningEvent!.text,
                  streaming: false,
                  elapsed: reasoningStart == null
                      ? null
                      : DateTime.now().difference(reasoningStart!),
                );
              }
              textEvent = textEvent == null
                  ? await store.appendAssistantText(current.id, textSoFar,
                      streaming: true)
                  : await store.updateAssistantText(current.id, textEvent!,
                      textSoFar,
                      streaming: true);
            });
          },
        );
        await pendingWrite;
        // 只有思考、没有正文时也要把思考定格。
        if (reasoningEvent != null && reasoningEvent!.streaming) {
          reasoningEvent = await store.updateReasoning(
            current.id, reasoningEvent!, reasoningEvent!.text,
            streaming: false,
            elapsed: reasoningStart == null
                ? null
                : DateTime.now().difference(reasoningStart!),
          );
        }
        if (textEvent != null || turn.text.isNotEmpty) {
          textEvent = textEvent == null
              ? await store.appendAssistantText(current.id, turn.text,
                  streaming: false)
              : await store.updateAssistantText(current.id, textEvent!,
                  turn.text.isEmpty ? textEvent!.text : turn.text,
                  streaming: false);
        }
        budget.recordTokens(turn.tokensUsed);
        current = await save(current.copyWith(
          tokenCount: current.tokenCount + turn.tokensUsed,
          updatedAt: DateTime.now(),
          lastEventSummary:
              turn.text.isNotEmpty ? turn.text : current.lastEventSummary,
        ));

        // ⑤ 无工具调用 → 兜底判收尾（L1）。
        if (turn.toolCalls.isEmpty) {
          current = await transition(AgentTaskStatus.done, '任务完成');
          return;
        }

        // ⑥ 逐个执行工具调用。
        for (final call in turn.toolCalls) {
          // 控制工具在引擎内处理。
          if (call.name == kToolUpdatePlan) {
            await store.appendPlanUpdate(current.id, _parsePlan(call));
            continue;
          }
          if (call.name == kToolAskUser) {
            final question = _stringArg(call, 'question') ?? '需要你的输入';
            await store.appendAssistantText(current.id, question,
                streaming: false);
            current = await transition(
                AgentTaskStatus.waitingInput, '等待用户输入');
            return;
          }
          if (call.name == kToolFinishTask) {
            final summary = _stringArg(call, 'summary') ?? '任务完成';
            current = await transition(AgentTaskStatus.done, summary);
            return;
          }

          var event = await store.appendToolCall(
              current.id, call, AgentToolCallState.running);

          // 审批（L2）：拒绝回填继续跑；挂起无超时。
          final requirement = await approval.evaluate(call, current);
          if (requirement == ApprovalRequirement.forbid) {
            event = await store.updateToolCall(current.id, event,
                state: AgentToolCallState.denied,
                resultSummary: '策略禁止');
            budget.recordToolResult(ok: false);
            continue;
          }
          if (requirement == ApprovalRequirement.needsUser) {
            event = await store.updateToolCall(current.id, event,
                state: AgentToolCallState.waitingApproval);
            current = await transition(
                AgentTaskStatus.waitingApproval, '等待审批：${call.name}');
            final verdict =
                await approval.waitForVerdict(call, current, cancel);
            if (!verdict.approved) {
              event = await store.updateToolCall(current.id, event,
                  state: AgentToolCallState.denied,
                  resultSummary: '用户拒绝：${verdict.reason}');
              current = await transition(AgentTaskStatus.running, '继续执行');
              budget.recordToolResult(ok: false);
              continue;
            }
            event = await store.updateToolCall(current.id, event,
                state: AgentToolCallState.running);
            current = await transition(AgentTaskStatus.running, '审批通过，继续执行');
          }

          final stopwatch = Stopwatch()..start();
          final result = await tools
              .execute(call, cancel)
              .timeout(budget.toolTimeout,
                  onTimeout: () => const AgentToolResult(
                      ok: false, summary: '超时 ✗'));
          stopwatch.stop();
          await store.updateToolCall(current.id, event,
              state: result.ok
                  ? AgentToolCallState.success
                  : AgentToolCallState.failure,
              resultSummary: result.summary,
              resultDetail: result.detail,
              elapsed: stopwatch.elapsed);
          budget.recordToolResult(ok: result.ok);

          if (cancel.stopRequested) break;
        }

        // ⑦ 自动 compaction（设计初稿 §5.3）：重放视图超阈值时把最早
        // 一段摘要成 CompactionEvent；失败不阻断任务（下轮再试）。
        try {
          await _maybeCompact(current);
        } catch (_) {}
      }
    } catch (e) {
      await store.appendStatusChange(current.id, '执行出错：$e');
      await gateway.save(current.copyWith(
        status: AgentTaskStatus.failed,
        updatedAt: DateTime.now(),
        lastEventSummary: '执行出错：$e',
      ));
    }
  }

  Future<void> _backfillInterruptedToolCalls(String taskId) async {
    final events = await store.getEvents(taskId);
    for (final event in events.whereType<ToolCallEvent>()) {
      if (event.state == AgentToolCallState.running ||
          event.state == AgentToolCallState.waitingApproval) {
        await store.updateToolCall(
          taskId,
          event,
          state: AgentToolCallState.failure,
          resultSummary: '进程中断，未执行完成',
        );
      }
    }
  }

  Future<void> _maybeCompact(AgentTask task) async {
    final events = await store.getEvents(task.id);
    final entries = foldCompactedEvents(events);
    if (totalContextChars(entries) <= budget.compactionTriggerChars) return;
    final covered = selectCompactionPrefix(
      entries,
      keepChars: budget.compactionKeepChars,
    );
    if (covered.isEmpty) return;
    final summary = await llm.summarizeForCompaction(task, covered);
    if (summary.trim().isEmpty) return;
    await store.appendCompaction(
      task.id,
      coveredCount: covered.length,
      summary: summary.trim(),
    );
  }

  List<AgentPlanItem> _parsePlan(AgentToolCallRequest call) {
    try {
      final json = jsonDecode(call.argsJson) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? const [];
      return [
        for (final item in items.cast<Map<String, dynamic>>())
          AgentPlanItem(
            content: item['content'] as String? ?? '',
            status: switch (item['status'] as String?) {
              'in_progress' || 'inProgress' => AgentPlanItemStatus.inProgress,
              'completed' => AgentPlanItemStatus.completed,
              _ => AgentPlanItemStatus.pending,
            },
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  String? _stringArg(AgentToolCallRequest call, String key) {
    try {
      final json = jsonDecode(call.argsJson) as Map<String, dynamic>;
      return json[key] as String?;
    } catch (_) {
      return null;
    }
  }
}
