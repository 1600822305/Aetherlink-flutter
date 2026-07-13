import 'dart:async';
import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
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
    this.subagents,
  });

  final AgentLlmClient llm;
  final AgentToolExecutor tools;
  final ApprovalGate approval;
  final AgentEventStore store;
  final AgentTaskGateway gateway;
  final AgentBudget budget;

  /// 子代理启动器；null = 本层不支持派生（子代理自身不可再嵌套）。
  final AgentSubagentLauncher? subagents;

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
        final writer = _StreamingEventWriter(store, current.id);
        // 工具调用参数一流完就先落「执行中」事件（不等整轮结束），
        // UI 实时看到块；后续执行循环按 id 复用预建事件。
        const engineTools = {kToolUpdatePlan, kToolAskUser, kToolFinishTask};
        final preCreated = <String, List<ToolCallEvent>>{};
        final turn = await llm.completeTurn(
          AgentLlmContext(task: current, events: events),
          cancel: cancel,
          onReasoningDelta: writer.onReasoningDelta,
          onTextDelta: writer.onTextDelta,
          onToolCall: (call) async {
            if (engineTools.contains(call.name) ||
                call.name == kToolSpawnSubagent) {
              return;
            }
            final event = await store.appendToolCall(
                current.id, call, AgentToolCallState.running);
            preCreated.putIfAbsent(call.id, () => []).add(event);
          },
        );
        await writer.finish(turn.text);
        // 流中断时未回到 turn 的预建事件按失败回填，避免永久 running。
        final returnedIds = {for (final c in turn.toolCalls) c.id};
        for (final entry in preCreated.entries) {
          if (returnedIds.contains(entry.key)) continue;
          for (final event in entry.value) {
            await store.updateToolCall(current.id, event,
                state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
          }
          entry.value.clear();
        }
        budget.recordTokens(turn.tokensUsed);
        current = await save(current.copyWith(
          tokenCount: current.tokenCount + turn.tokensUsed,
          contextTokens: turn.contextTokens > 0
              ? turn.contextTokens
              : current.contextTokens,
          updatedAt: DateTime.now(),
          lastEventSummary:
              turn.text.isNotEmpty ? turn.text : current.lastEventSummary,
        ));

        // ⑤ 无工具调用 → 兜底判收尾（L1）。
        if (turn.toolCalls.isEmpty) {
          current = await transition(AgentTaskStatus.done, '任务完成');
          return;
        }

        // ⑥ 逐个执行工具调用；同一轮连续的 spawn_subagent 成批并行。
        for (var i = 0; i < turn.toolCalls.length; i++) {
          final call = turn.toolCalls[i];
          if (call.name == kToolSpawnSubagent) {
            final batch = <AgentToolCallRequest>[call];
            while (i + 1 < turn.toolCalls.length &&
                turn.toolCalls[i + 1].name == kToolSpawnSubagent) {
              batch.add(turn.toolCalls[++i]);
            }
            current = await _runSubagentBatch(current, batch, cancel);
            if (cancel.stopRequested) break;
            continue;
          }
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

          final pre = preCreated[call.id];
          var event = (pre != null && pre.isNotEmpty)
              ? pre.removeAt(0)
              : await store.appendToolCall(
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
              resultOverflowPath: result.overflowPath,
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

  /// 同批子代理并行跑（对标 Cursor：同轮多个 spawn 并行，父级阻塞等
  /// 全部结果）。派生本身不过审批门：子代理内部的每个工具调用仍走
  /// 自身的审批链。
  Future<AgentTask> _runSubagentBatch(
    AgentTask current,
    List<AgentToolCallRequest> batch,
    AgentCancellationToken cancel,
  ) async {
    final launcher = subagents;
    final events = <ToolCallEvent>[];
    for (final call in batch) {
      events.add(await store.appendToolCall(
          current.id, call, AgentToolCallState.running));
    }
    if (launcher == null) {
      for (final event in events) {
        await store.updateToolCall(current.id, event,
            state: AgentToolCallState.failure,
            resultSummary: '子代理不可用 ✗',
            resultDetail: '当前上下文不支持派生子代理（子代理内不可再嵌套）');
        budget.recordToolResult(ok: false);
      }
      return current;
    }
    await Future.wait([
      for (var i = 0; i < batch.length; i++)
        () async {
          final stopwatch = Stopwatch()..start();
          AgentToolResult result;
          try {
            result = await launcher.launch(
              parent: current,
              call: batch[i],
              toolEventId: events[i].id,
              cancel: cancel,
            );
          } catch (e) {
            result = AgentToolResult(ok: false, summary: '子代理异常 ✗', detail: '$e');
          }
          stopwatch.stop();
          await store.updateToolCall(current.id, events[i],
              state: result.ok
                  ? AgentToolCallState.success
                  : AgentToolCallState.failure,
              resultSummary: result.summary,
              resultDetail: result.detail,
              elapsed: stopwatch.elapsed);
          budget.recordToolResult(ok: result.ok);
        }(),
    ]);
    return current;
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

/// 流式增量的合并限流落库（L6 原位 upsert 之上的写入节流）。
///
/// LLM 每个 SSE 增量都会回调一次；逐条 upsert 会让写库频率跟着网络包走
/// （每秒几十次），而每次写库都触发 UI watch 对整条事件流的全量重解码——
/// 长任务（几十轮、几百 KB 工具输出）下 UI isolate 被解码洪流打满，
/// 表现为整页冻结甚至 ANR。这里按 latest-wins 合并：增量只更新内存态，
/// 每 [_kMinWriteInterval] 至多落库一次，收尾时 [finish] 强制写终值。
class _StreamingEventWriter {
  _StreamingEventWriter(this._store, this._taskId);

  static const Duration _kMinWriteInterval = Duration(milliseconds: 200);

  final AgentEventStore _store;
  final String _taskId;

  AssistantTextEvent? _textEvent;
  ReasoningEvent? _reasoningEvent;
  DateTime? _reasoningStart;

  String _text = '';
  String _reasoning = '';
  bool _textDirty = false;
  bool _reasoningDirty = false;

  bool _writing = false;
  bool _finished = false;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  Future<void> _drainFuture = Future<void>.value();

  void onReasoningDelta(String reasoningSoFar) {
    _reasoningStart ??= DateTime.now();
    _reasoning = reasoningSoFar;
    _reasoningDirty = true;
    _schedule();
  }

  void onTextDelta(String textSoFar) {
    _text = textSoFar;
    _textDirty = true;
    _schedule();
  }

  /// 收尾：停掉节流定时器，等在途写入结束，把思考定格、正文以终值
  /// （非流式）落库。[finalText] 为空时以最后一次增量的全文为准。
  Future<void> finish(String finalText) async {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    await _drainFuture;
    if (_reasoningEvent != null && _reasoningEvent!.streaming) {
      _reasoningEvent = await _store.updateReasoning(
        _taskId, _reasoningEvent!, _reasoningEvent!.text,
        streaming: false,
        elapsed: _reasoningElapsed(),
      );
    }
    final text = finalText.isEmpty ? _text : finalText;
    if (_textEvent != null || text.isNotEmpty) {
      _textEvent = _textEvent == null
          ? await _store.appendAssistantText(_taskId, text, streaming: false)
          : await _store.updateAssistantText(_taskId, _textEvent!, text,
              streaming: false);
    }
  }

  Duration? _reasoningElapsed() => _reasoningStart == null
      ? null
      : DateTime.now().difference(_reasoningStart!);

  void _schedule() {
    if (_writing || _finished || _timer != null) return;
    final wait = _kMinWriteInterval - DateTime.now().difference(_lastWrite);
    if (wait <= Duration.zero) {
      _drainFuture = _drain();
    } else {
      _timer = Timer(wait, () {
        _timer = null;
        if (!_writing && !_finished) _drainFuture = _drain();
      });
    }
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      if (_reasoningDirty) {
        _reasoningDirty = false;
        final reasoning = _reasoning;
        _reasoningEvent = _reasoningEvent == null
            ? await _store.appendReasoning(_taskId, reasoning,
                streaming: true)
            : await _store.updateReasoning(
                _taskId, _reasoningEvent!, reasoning,
                streaming: true);
      }
      if (_textDirty) {
        _textDirty = false;
        // 文本开始 → 思考定格（收起为"思考了 Xs"）。
        if (_reasoningEvent != null && _reasoningEvent!.streaming) {
          _reasoningEvent = await _store.updateReasoning(
            _taskId, _reasoningEvent!, _reasoningEvent!.text,
            streaming: false,
            elapsed: _reasoningElapsed(),
          );
        }
        final text = _text;
        _textEvent = _textEvent == null
            ? await _store.appendAssistantText(_taskId, text, streaming: true)
            : await _store.updateAssistantText(_taskId, _textEvent!, text,
                streaming: true);
      }
    } finally {
      _lastWrite = DateTime.now();
      _writing = false;
    }
    if (!_finished && (_reasoningDirty || _textDirty)) _schedule();
  }
}
