import 'dart:async';
import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_file_restore.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_guard.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_context_overflow.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_manual_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
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

/// 计划模式控制工具（对标 CC EnterPlanMode/ExitPlanMode）：引擎内部处理，
/// 模式切换需重建工具目录，由 [AgentEngine.onModeSwitchRestart] 回调续跑。
const String kToolEnterPlanMode = 'enter_plan_mode';
const String kToolExitPlanMode = 'exit_plan_mode';

/// enter_plan_mode 成功后回填给模型的行为指令（对标 CC 工具结果）。
const String kEnterPlanModeResult = '已进入计划模式。接下来你应该：\n'
    '1. 用只读工具充分探索代码，理解既有模式与相似实现\n'
    '2. 权衡多种实现路径的取舍\n'
    '3. 需要澄清需求时用 ask_user 提问\n'
    '4. 用 update_plan 增量维护方案要点\n'
    '5. 方案完整后调用 exit_plan_mode 提交全文请求批准\n'
    '记住：现在不要修改任何文件，这是只读的探索与设计阶段。';

/// exit_plan_mode 被用户拒绝时的回填前缀（对标 CC PLAN_REJECTION_PREFIX）。
const String kPlanRejectionPrefix =
    '用户拒绝了该方案，选择继续留在计划模式。不要开始实现，根据以下反馈修订方案后'
    '重新提交 exit_plan_mode：';

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
    this.toolStream,
    this.stopGuard,
    this.hookStopSignal,
    this.onTurnStart,
    this.onTurnEnd,
    this.onTaskEnd,
    this.onNotification,
    this.onPreCompact,
    this.onPostCompact,
    this.onCompactionFailed,
    this.manualCompactSignal,
    this.onModeSwitchRestart,
  });

  final AgentLlmClient llm;
  final AgentToolExecutor tools;
  final ApprovalGate approval;
  final AgentEventStore store;
  final AgentTaskGateway gateway;
  final AgentBudget budget;

  /// 子代理启动器；null = 本层不支持派生（子代理自身不可再嵌套）。
  final AgentSubagentLauncher? subagents;

  /// 工具参数流式生成的实时通道（纯内存）；null = 不做实时预览。
  final AgentToolStreamSink? toolStream;

  /// 收尾校验（stop hook）：返回 null 放行收尾；返回原因则阻止本次
  /// 收尾，原因以用户消息回填继续跑。每次运行最多阻止一次
  /// （防 hook 永远不满意导致死循环）。
  final Future<String?> Function()? stopGuard;

  /// hook 的任务终止信号（stdout JSON `{"continue":false}`，对标
  /// Claude Code）：返回非 null（stopReason）即在安全点终止整个
  /// 任务，stopReason 展示给用户；调用即消费（取后清除）。
  final String? Function()? hookStopSignal;

  /// 每轮开始（LLM 调用前）/ 每轮结束（本轮工具全部执行完）的
  /// 生命周期回调（turnStart/turnEnd hooks）：同步触发、不等待、
  /// 不阻断循环。
  final void Function()? onTurnStart;
  final void Function()? onTurnEnd;

  /// 任务正常结束（转 done）后的生命周期回调（taskEnd hooks）：
  /// 同步触发、不等待、不阻断。
  final void Function()? onTaskEnd;

  /// 需要用户注意的时刻（notification hooks，对标 CC
  /// Notification）：审批挂起（type=approval）/ ask_user 等待
  /// （type=question）时同步触发、不等待、不阻断。
  final void Function(String message, String type)? onNotification;

  /// 上下文压缩前 / 后的回调（preCompact / postCompact hooks，
  /// 对标 CC）：同步触发、不等待、不阻断；postCompact 带压缩摘要。
  final void Function()? onPreCompact;
  final void Function(String summary)? onPostCompact;

  /// 压缩失败（onPreCompact 已触发但摘要未落库）时回调：调用方据此
  /// 清理「压缩中」实况 UI，避免失败后状态行挂死到任务结束。
  final void Function()? onCompactionFailed;

  /// 手动压缩信号（升级计划 ⑤，对标 CC /compact）：返回非空请求即在
  /// 下一个安全点强制压缩一次（忽略触发阈值与熔断，仍走 keep 规则），
  /// 请求可携带用户关注点（升级计划 ⑦）；调用即消费（取后清除）。
  final ManualCompactRequest? Function()? manualCompactSignal;

  /// 计划模式切换后的续跑回调：模式已落库，但工具目录/系统提示是
  /// 按模式在运行开始时构建的，需要调用方以新模式重启运行。
  /// 引擎调用完立即 return；回调为 null 时任务停在 running，
  /// 由用户手动续跑。
  final void Function(AgentTask task)? onModeSwitchRestart;

  bool _stopGuardFired = false;

  /// finish_task 无正文拦截只触发一次（防弱模型反复空收尾死循环）。
  bool _finishGuardFired = false;

  /// 最后一条用户消息之后是否存在非空助手正文：分析/调研类任务的
  /// 交付物就是正文，没有正文的 finish_task 视为零产出收尾。
  static bool _hasFinalReply(List<AgentEvent> events) {
    for (final event in events.reversed) {
      if (event is UserMessageEvent) return false;
      if (event is AssistantTextEvent && event.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<String?> _checkStopGuard() async {
    final guard = stopGuard;
    if (guard == null || _stopGuardFired) return null;
    String? reason;
    try {
      reason = await guard();
    } catch (_) {
      return null; // hook 自身异常不阻断收尾
    }
    if (reason != null) _stopGuardFired = true;
    return reason;
  }

  /// 压缩失败只提示一次（每次运行一个引擎实例）。
  bool _compactionFailureNotified = false;
  bool _compactionWarningNotified = false;

  /// 反应式压缩（升级计划 ⑧，对标 CC hasAttemptedReactiveCompact）：
  /// 每次运行只兜底一次，压缩后重试仍超限则直接报错（防死循环）。
  bool _reactiveCompactAttempted = false;

  /// 压缩熔断器（升级计划 ④）：连续失败达上限后本次运行内不再尝试，
  /// 成功一次即重置；随引擎实例生灭，续跑重新计数。
  final CompactionCircuitBreaker _compactionBreaker =
      CompactionCircuitBreaker();

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

    // 方案审批（exit_plan_mode）的挂起 + 裁决处理：批准后恢复
    // prePlanMode（autoAccept 则切 Auto 免审）并请求重启（返回 true，
    // 调用方应 return）；拒绝后留在 Plan 模式回填理由继续循环（返回
    // false）。启动恢复与循环内两个入口共用。
    Future<bool> resolvePlanApproval(
      ToolCallEvent event,
      AgentToolCallRequest call,
      String plan,
    ) async {
      await store.appendStatusChange(current.id, '等待方案批准');
      current = await save(current.copyWith(
        status: AgentTaskStatus.waitingApproval,
        updatedAt: DateTime.now(),
        lastEventSummary: '等待方案批准',
      ));
      onNotification?.call('等待方案批准', 'approval');
      final verdict = await approval.waitForVerdict(call, current, cancel);
      if (!verdict.approved) {
        await store.updateToolCall(current.id, event,
            state: AgentToolCallState.denied,
            resultSummary: '用户拒绝方案',
            resultDetail: '$kPlanRejectionPrefix\n${verdict.reason}');
        await store.appendStatusChange(current.id, '方案被拒绝，继续修订');
        current = await save(current.copyWith(
          status: AgentTaskStatus.running,
          updatedAt: DateTime.now(),
          lastEventSummary: '方案被拒绝，继续修订',
        ));
        budget.recordToolResult(ok: false);
        cancel.consumeToolInterrupt();
        return false;
      }
      final edited = verdict.editedPlan?.trim();
      final wasEdited =
          edited != null && edited.isNotEmpty && edited != plan;
      final effectivePlan = wasEdited ? edited : plan;
      final restored = verdict.autoAccept
          ? AgentSessionMode.auto
          : (current.prePlanMode ?? AgentSessionMode.code);
      await store.updateToolCall(current.id, event,
          state: AgentToolCallState.success,
          // 编辑后批准：批准版方案回写参数详情，UI/重放都以它为准。
          argsDetail: wasEdited ? jsonEncode({'plan': effectivePlan}) : null,
          resultSummary: '方案已批准',
          resultDetail: '用户已批准方案${wasEdited ? '（经用户编辑，以下为最终版本）' : ''}，'
              '现在可以开始实现。先用 update_plan 同步执行计划，然后按方案执行。'
              '\n\n## 已批准的方案：\n$effectivePlan');
      await store.appendStatusChange(
          current.id,
          '模式切换：plan → ${restored.name}'
          '（方案已批准${verdict.autoAccept ? '，免审执行' : ''}）');
      current = await save(current.copyWith(
        status: AgentTaskStatus.running,
        mode: restored,
        clearPrePlanMode: true,
        updatedAt: DateTime.now(),
        lastEventSummary: '方案已批准，开始执行',
      ));
      cancel.consumeToolInterrupt();
      onModeSwitchRestart?.call(current);
      return true;
    }

    try {
      if (current.status != AgentTaskStatus.running) {
        current = await save(current.copyWith(
          status: AgentTaskStatus.running,
          updatedAt: DateTime.now(),
        ));
      }

      // 恢复语义（L7）：上次进程死亡时半途的工具调用（仍 running /
      // waitingApproval）按失败回填，重放时模型可重新发起并重过审批；
      // 例外：Plan 模式下挂起中的方案审批（exit_plan_mode）不回填，
      // 下方直接重建审批挂起，不用模型重发一轮。
      final pendingPlanApproval = await _backfillInterruptedToolCalls(
        current.id,
        keepPendingPlanApproval: current.mode == AgentSessionMode.plan,
      );
      if (pendingPlanApproval != null) {
        final plan = _planOfArgs(pendingPlanApproval.argsDetail);
        if (plan.isEmpty) {
          await store.updateToolCall(current.id, pendingPlanApproval,
              state: AgentToolCallState.failure,
              resultSummary: '进程中断，未执行完成');
        } else {
          final resumed = await resolvePlanApproval(
            pendingPlanApproval,
            AgentToolCallRequest(
              id: pendingPlanApproval.id,
              name: kToolExitPlanMode,
              argsJson: pendingPlanApproval.argsDetail ?? '{}',
              argSummary: '请求批准方案',
            ),
            plan,
          );
          if (resumed) return;
        }
      }

      outer:
      while (true) {
        // ① 安全点：排队消息正式进上下文（L3）。
        await store.consumeQueuedUserMessages(current.id);

        // ② 取消/暂停/预算检查。
        if (cancel.cancelRequested) {
          current = await transition(AgentTaskStatus.cancelled, '用户强制终止');
          return;
        }
        final hookStop = hookStopSignal?.call();
        if (hookStop != null) {
          current =
              await transition(AgentTaskStatus.cancelled, 'hook 终止任务：$hookStop');
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
        onTurnStart?.call();
        final events = await store.getEvents(current.id);
        final writer = _StreamingEventWriter(store, current.id);
        // 工具调用参数一流完就先落「执行中」事件（不等整轮结束），
        // UI 实时看到块；后续执行循环按 id 复用预建事件。
        const engineTools = {
          kToolUpdatePlan,
          kToolAskUser,
          kToolFinishTask,
          kToolEnterPlanMode,
          kToolExitPlanMode,
        };
        bool internalTool(String name) =>
            engineTools.contains(name) || name == kToolSpawnSubagent;
        final preCreated = <String, List<ToolCallEvent>>{};
        // 参数仍在流式生成中的调用：streamKey → 事件（节流落库更新）。
        final streamingEvents = <String, ToolCallEvent>{};
        final streamingWriteAt = <String, DateTime>{};
        Future<AgentLlmTurn> callTurn() => llm.completeTurn(
          AgentLlmContext(
            task: current,
            events: events,
            microCompactEnabled: budget.microCompactEnabled,
            microCompactTriggerChars: budget.microCompactTriggerChars,
          ),
          cancel: cancel,
          onReasoningDelta: writer.onReasoningDelta,
          onTextDelta: writer.onTextDelta,
          onToolCallDelta: (streamKey, toolName, argsTextSoFar) async {
            if (toolName == null || internalTool(toolName)) return;
            final existing = streamingEvents[streamKey];
            if (existing == null) {
              final created = await store.appendToolCall(
                current.id,
                AgentToolCallRequest(
                  id: streamKey,
                  name: toolName,
                  argsJson: argsTextSoFar,
                  argSummary: '生成参数中…',
                ),
                AgentToolCallState.running,
              );
              streamingEvents[streamKey] = created;
              streamingWriteAt[streamKey] = DateTime.now();
              toolStream?.update(created.id, toolName, argsTextSoFar);
              return;
            }
            // 实时预览走内存通道，每个 delta 都推（UI 直接监听）；落库只按
            // 节流做崩溃恢复持久化，不承担实时性。
            toolStream?.update(existing.id, toolName, argsTextSoFar);
            final now = DateTime.now();
            final last = streamingWriteAt[streamKey];
            if (last != null &&
                now.difference(last) < const Duration(milliseconds: 500)) {
              return;
            }
            streamingWriteAt[streamKey] = now;
            streamingEvents[streamKey] = await store.updateToolCall(
              current.id,
              existing,
              state: AgentToolCallState.running,
              argsDetail: argsTextSoFar,
            );
          },
          onToolCall: (call, streamKey) async {
            if (internalTool(call.name)) return;
            final streamed =
                streamKey == null ? null : streamingEvents.remove(streamKey);
            if (streamed != null) toolStream?.clear(streamed.id);
            final event = streamed != null
                ? await store.updateToolCall(
                    current.id,
                    streamed,
                    state: AgentToolCallState.running,
                    argSummary: call.argSummary,
                    argsDetail: call.argsJson,
                  )
                : await store.appendToolCall(
                    current.id, call, AgentToolCallState.running);
            preCreated.putIfAbsent(call.id, () => []).add(event);
          },
        );
        final AgentLlmTurn turn;
        try {
          turn = await callTurn();
        } catch (e) {
          // 反应式压缩（升级计划 ⑧，对标 CC prompt-too-long recovery）：
          // 供应商拒绝超长 prompt 时兜底强制压缩一次后重试本轮；
          // 每次运行只尝试一次，仍超限则报错（防死循环）。
          if (_reactiveCompactAttempted || !isContextOverflowError(e)) {
            rethrow;
          }
          _reactiveCompactAttempted = true;
          // 半途流出的思考/正文定格落库，避免流式事件永久 streaming。
          await writer.finish('');
          // 本轮已流式预建的工具事件按中断回填，避免永久 running。
          for (final event in streamingEvents.values) {
            toolStream?.clear(event.id);
            await store.updateToolCall(current.id, event,
                state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
          }
          streamingEvents.clear();
          for (final entry in preCreated.values) {
            for (final event in entry) {
              await store.updateToolCall(current.id, event,
                  state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
            }
            entry.clear();
          }
          await store.appendStatusChange(
              current.id, '上下文超限（供应商拒绝），兜底压缩后重试本轮');
          // 强制压缩（失败向上抛 → 任务 failed，因为不压缩重试也必然超限）；
          // 压缩后回到循环顶部重试本轮（重读事件，折叠视图已缩小）。
          await _maybeCompact(current, events, force: true);
          continue;
        }
        await writer.finish(turn.text);
        // 流中断时未闭合/未回到 turn 的预建事件按失败回填，避免永久 running。
        for (final event in streamingEvents.values) {
          toolStream?.clear(event.id);
          await store.updateToolCall(current.id, event,
              state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
        }
        streamingEvents.clear();
        final returnedIds = {for (final c in turn.toolCalls) c.id};
        for (final entry in preCreated.entries) {
          if (returnedIds.contains(entry.key)) continue;
          for (final event in entry.value) {
            await store.updateToolCall(current.id, event,
                state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
          }
          entry.value.clear();
        }
        // 本轮中止时把尚未执行的预建工具事件按中断回填，避免永久
        // 停在 running（包括 turn 已返回但未来得及执行的调用）。
        Future<void> failPendingToolEvents() async {
          for (final entry in preCreated.values) {
            for (final event in entry) {
              await store.updateToolCall(current.id, event,
                  state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
            }
            entry.clear();
          }
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

        // 暂停/强停会中断 LLM 流并返回无工具调用的 turn，不能据此判
        // 收尾；回到循环顶部走 paused/cancelled 分支。
        if (cancel.stopRequested) {
          await failPendingToolEvents();
          continue;
        }

        // 「立即打断并发送」在 LLM 流阶段命中：turn 已被截断，
        // 消费打断标记回到循环顶部先注入排队消息，不按
        // 「无工具调用」判收尾。
        if (cancel.consumeToolInterrupt()) {
          await failPendingToolEvents();
          continue;
        }

        // ⑤ 无工具调用 → 兜底判收尾（L1）。
        if (turn.toolCalls.isEmpty) {
          if (!_finishGuardFired &&
              !_hasFinalReply(await store.getEvents(current.id))) {
            _finishGuardFired = true;
            await store.appendUserMessage(
                current.id,
                '[系统] 你还没有输出面向用户的正文回复。请先把最终结论/报告'
                '作为正文完整输出，再结束任务。');
            continue;
          }
          final blocked = await _checkStopGuard();
          if (blocked != null) {
            await store.appendUserMessage(
                current.id, '[stop hook 阻止收尾] $blocked');
            continue;
          }
          current = await transition(AgentTaskStatus.done, '任务完成');
          onTaskEnd?.call();
          return;
        }

        // 单个工具的执行 + 结果落库（串行与只读并发段共用）：
        // 带超时，超时自己发出的中断信号按代号定向回收，
        // 不影响同轮其他工具，也不吞窗口内用户的新打断。
        Future<void> runToolCall(
          AgentToolCallRequest call,
          ToolCallEvent event,
        ) async {
          final stopwatch = Stopwatch()..start();
          var timeoutInterruptGen = 0;
          final result = await tools
              .execute(call, cancel)
              .timeout(budget.toolTimeout, onTimeout: () {
            // 同时中止仍在运行的底层工具，避免模型重发同一命令时
            // 与旧命令并发（双重执行）。
            timeoutInterruptGen = cancel.requestToolInterrupt();
            return const AgentToolResult(ok: false, summary: '超时 ✗');
          });
          stopwatch.stop();
          if (timeoutInterruptGen > 0) {
            cancel.consumeToolInterruptOf(timeoutInterruptGen);
          }
          await store.updateToolCall(current.id, event,
              state: result.ok
                  ? AgentToolCallState.success
                  : AgentToolCallState.failure,
              resultSummary: result.summary,
              resultDetail: result.detail,
              resultOverflowPath: result.overflowPath,
              elapsed: stopwatch.elapsed);
          budget.recordToolResult(ok: result.ok);
        }

        // ⑥ 逐个执行工具调用；同一轮连续的 spawn_subagent 成批并行，
        // 连续的只读（并发安全）调用成批并发（对标 CC
        // runToolsConcurrently），写/执行类保持串行。
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
            final (question, suggestions) = _parseUserQuestion(call);
            await store.appendUserQuestion(current.id, question,
                suggestions: suggestions,
                toolCallId: call.id,
                argsJson: call.argsJson);
            current = await transition(
                AgentTaskStatus.waitingInput, '等待回答：$question');
            onNotification?.call('等待回答：$question', 'question');
            return;
          }
          // 控制工具的结果落库（append + update 两步，与普通工具同款事件）。
          Future<ToolCallEvent> logControlResult(
            AgentToolCallRequest call, {
            required bool ok,
            required String summary,
            required String detail,
            String argSummary = '',
          }) async {
            final event = await store.appendToolCall(
                current.id,
                AgentToolCallRequest(
                  id: call.id,
                  name: call.name,
                  argsJson: call.argsJson,
                  argSummary: argSummary,
                ),
                AgentToolCallState.running);
            return store.updateToolCall(current.id, event,
                state: ok
                    ? AgentToolCallState.success
                    : AgentToolCallState.failure,
                resultSummary: summary,
                resultDetail: detail);
          }

          if (call.name == kToolEnterPlanMode) {
            if (current.mode == AgentSessionMode.plan ||
                current.mode == AgentSessionMode.ask) {
              await logControlResult(call,
                  ok: false,
                  summary: '已在只读模式',
                  detail: '当前已是只读模式，无需进入计划模式，直接继续分析与规划。');
              budget.recordToolResult(ok: false);
              continue;
            }
            final previous = current.mode;
            await logControlResult(call,
                ok: true, summary: '已进入计划模式', detail: kEnterPlanModeResult);
            await store.appendStatusChange(
                current.id, '模式切换：${previous.name} → plan（模型请求先规划）');
            current = await save(current.copyWith(
              mode: AgentSessionMode.plan,
              prePlanMode: previous,
              updatedAt: DateTime.now(),
              lastEventSummary: '已进入计划模式',
            ));
            await failPendingToolEvents();
            onModeSwitchRestart?.call(current);
            return;
          }
          if (call.name == kToolExitPlanMode) {
            if (current.mode != AgentSessionMode.plan) {
              await logControlResult(call,
                  ok: false,
                  summary: '不在计划模式',
                  detail: '当前不在计划模式。若方案已获批准，直接继续实现即可。');
              budget.recordToolResult(ok: false);
              continue;
            }
            final plan = _stringArg(call, 'plan')?.trim() ?? '';
            if (plan.isEmpty) {
              await logControlResult(call,
                  ok: false,
                  summary: '缺少方案内容',
                  detail: 'plan 参数为空：需提交完整的实现方案全文供用户审批。');
              budget.recordToolResult(ok: false);
              continue;
            }
            final event = await store.appendToolCall(
                current.id,
                AgentToolCallRequest(
                  id: call.id,
                  name: call.name,
                  argsJson: call.argsJson,
                  argSummary: '请求批准方案',
                ),
                AgentToolCallState.waitingApproval);
            if (await resolvePlanApproval(event, call, plan)) {
              await failPendingToolEvents();
              return;
            }
            continue;
          }
          if (call.name == kToolFinishTask) {
            if (!_finishGuardFired &&
                !_hasFinalReply(await store.getEvents(current.id))) {
              _finishGuardFired = true;
              await logControlResult(call,
                  ok: false,
                  summary: '收尾被拒：缺少正文回复',
                  detail: '你还没有输出面向用户的正文回复。分析、调研、解答类'
                      '任务的正文就是交付物：请先把最终结论/报告作为正文完整'
                      '输出，再调用 finish_task；summary 只是一句话标题，'
                      '不能替代正文。');
              budget.recordToolResult(ok: false);
              continue;
            }
            final blocked = await _checkStopGuard();
            if (blocked != null) {
              await store.appendUserMessage(
                  current.id, '[stop hook 阻止收尾] $blocked');
              continue outer;
            }
            final summary = _stringArg(call, 'summary') ?? '任务完成';
            current = await transition(AgentTaskStatus.done, summary);
            onTaskEnd?.call();
            return;
          }

          // 只读并发段：连续≥ 2 个并发安全且审批直通（allow）的调用
          // 成批 Future.wait 并行；遇到需要审批/禁止/不安全的调用在
          // 其前截断，剩余的回到串行路径逐个处理（evaluate 有缓存，
          // 重评不重跑 hooks）。
          if (tools.isConcurrencySafe(call)) {
            final batch = <AgentToolCallRequest>[];
            var j = i;
            while (j < turn.toolCalls.length &&
                batch.length < kMaxConcurrentReadTools &&
                !internalTool(turn.toolCalls[j].name) &&
                tools.isConcurrencySafe(turn.toolCalls[j]) &&
                await approval.evaluate(turn.toolCalls[j], current) ==
                    ApprovalRequirement.allow) {
              batch.add(turn.toolCalls[j]);
              j++;
            }
            if (batch.length >= 2) {
              i = j - 1;
              final batchEvents = <ToolCallEvent>[];
              for (final c in batch) {
                final pre = preCreated[c.id];
                batchEvents.add((pre != null && pre.isNotEmpty)
                    ? pre.removeAt(0)
                    : await store.appendToolCall(
                        current.id, c, AgentToolCallState.running));
              }
              await Future.wait([
                for (var k = 0; k < batch.length; k++)
                  runToolCall(batch[k], batchEvents[k]),
              ]);
              if (cancel.stopRequested) break;
              final batchHookStop = hookStopSignal?.call();
              if (batchHookStop != null) {
                await failPendingToolEvents();
                current = await transition(
                    AgentTaskStatus.cancelled, 'hook 终止任务：$batchHookStop');
                return;
              }
              if (cancel.consumeToolInterrupt()) {
                await failPendingToolEvents();
                break;
              }
              continue;
            }
            // 不足两个可并发的调用：走下方串行路径。
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
            onNotification?.call('等待审批：${call.name}', 'approval');
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
            // 审批等待期间遗留的打断标记是针对「挂起中的审批」的（打断
            // 发送会同步把挂起审批按拒绝回填）；能走到这里说明用户最终
            // 选择了批准，先消费掉陈旧标记，避免刚批准的工具被瞬间打断
            // 而没有真正执行。排队消息仍会在下一轮循环顶部正常注入。
            cancel.consumeToolInterrupt();
          }

          await runToolCall(call, event);

          if (cancel.stopRequested) break;
          // hook 输出 continue:false：中止本轮剩余工具并终止整个任务，
          // stopReason 展示给用户。
          final toolHookStop = hookStopSignal?.call();
          if (toolHookStop != null) {
            await failPendingToolEvents();
            current = await transition(
                AgentTaskStatus.cancelled, 'hook 终止任务：$toolHookStop');
            return;
          }
          // 「立即打断并发送」在工具阶段命中：中止本轮剩余工具，
          // 剩余预建事件按中断回填，回到循环顶部先注入排队消息。
          if (cancel.consumeToolInterrupt()) {
            await failPendingToolEvents();
            break;
          }
        }

        onTurnEnd?.call();

        // ⑦ 自动 compaction（设计初稿 §5.3）：重放视图超阈值时把最早
        // 一段摘要成 CompactionEvent；失败不阻断任务（下轮再试）。
        // 复用本轮开头读的事件列表（事件只在尾部追加，前缀选择
        // 不受影响），避免每轮额外一次全表读取+解码。
        try {
          await _maybeCompact(current, events);
        } catch (e) {
          // 压缩中实况行随失败清理（onPostCompact 不会再触发）。
          onCompactionFailed?.call();
          // 压缩失败不阻断任务（下轮再试），但给一次可见提示，
          // 避免上下文持续膨胀到预算暂停时用户不知原因。
          final justOpened = _compactionBreaker.recordFailure();
          if (justOpened) {
            // 熔断（升级计划 ④）：连续失败达上限，本次运行内停止再尝试，
            // 避免每轮白调一次 LLM；给一次可见提示。
            try {
              await store.appendStatusChange(
                  current.id,
                  '上下文压缩连续失败 '
                  '${_compactionBreaker.maxConsecutiveFailures} 次，本次运行内'
                  '不再尝试（续跑恢复）：$e');
            } catch (_) {}
          } else if (!_compactionFailureNotified) {
            _compactionFailureNotified = true;
            try {
              await store.appendStatusChange(
                  current.id, '上下文压缩失败（不影响任务，下轮重试）：$e');
            } catch (_) {}
          }
        }
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

  /// 回填中断的工具调用；[keepPendingPlanApproval] 时挂起中的方案审批
  /// （exit_plan_mode waitingApproval）不回填，原样返回给调用方重建挂起。
  Future<ToolCallEvent?> _backfillInterruptedToolCalls(
    String taskId, {
    bool keepPendingPlanApproval = false,
  }) async {
    final events = await store.getEvents(taskId);
    ToolCallEvent? pendingPlanApproval;
    for (final event in events.whereType<ToolCallEvent>()) {
      if (event.state == AgentToolCallState.running ||
          event.state == AgentToolCallState.waitingApproval) {
        if (keepPendingPlanApproval &&
            event.state == AgentToolCallState.waitingApproval &&
            event.toolName == kToolExitPlanMode) {
          pendingPlanApproval = event;
          continue;
        }
        await store.updateToolCall(
          taskId,
          event,
          state: AgentToolCallState.failure,
          resultSummary: '进程中断，未执行完成',
        );
      }
    }
    return pendingPlanApproval;
  }

  /// 从 exit_plan_mode 的参数 JSON 取方案全文（恢复时用）。
  static String _planOfArgs(String? argsJson) {
    if (argsJson == null || argsJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(argsJson);
      if (decoded is Map<String, dynamic>) {
        final plan = decoded['plan'];
        if (plan is String) return plan.trim();
      }
    } catch (_) {}
    return '';
  }

  Future<void> _maybeCompact(
    AgentTask task,
    List<AgentEvent> events, {
    bool force = false,
  }) async {
    // 与重放侧同款视图：先折叠、再 microcompact，确保 LLM 压缩的
    // 触发判断基于模型实际看到的内容量（两级降压：先 micro 后 LLM）。
    final folded = foldCompactedEvents(events);
    final entries = applyToolResultBudget(budget.microCompactEnabled
        ? microCompactEntries(
            folded,
            triggerChars: budget.microCompactTriggerChars,
          )
        : folded);
    // 手动压缩（升级计划 ⑤）：用户主动触发时跳过阈值/预警/熔断，
    // 直接走 keep 前缀选择。
    final manualRequest = manualCompactSignal?.call();
    // force：反应式压缩（升级计划 ⑧）与手动压缩同样跳过阈值/预警/熔断。
    final forced = force || manualRequest != null;
    // 触发判定（升级计划 ③）：优先用 API usage 的真实上下文 token 对比
    // 模型窗口（减摘要预留、乘触发比例），拿不到 usage 时回退字符估算。
    final overThreshold = shouldTriggerCompaction(
      contextTokens: task.contextTokens,
      contextLimitTokens: budget.contextLimitTokens,
      estimatedChars: totalContextChars(entries),
      fallbackTriggerChars: budget.compactionTriggerChars,
      triggerRatio: budget.compactionTriggerRatio,
    );
    // 自动压缩总开关：关掉后阈值不再自动触发（预警照发），
    // 手动压缩（forced）不受影响。
    final shouldCompact = forced || (budget.autoCompactEnabled && overThreshold);
    if (!shouldCompact) {
      // 预警（升级计划 ④）：进入触发阈值的 90% 区间时提前提示一次
      // （可见状态行 + notification hook，type=compactWarning）；
      // 自动压缩关闭且已超阈值时同样只提示一次，提醒可手动压缩。
      if (!_compactionWarningNotified &&
          (overThreshold ||
              isNearCompactionThreshold(
                contextTokens: task.contextTokens,
                contextLimitTokens: budget.contextLimitTokens,
                estimatedChars: totalContextChars(entries),
                fallbackTriggerChars: budget.compactionTriggerChars,
                triggerRatio: budget.compactionTriggerRatio,
              ))) {
        _compactionWarningNotified = true;
        final message = overThreshold
            ? '上下文已超过压缩阈值（自动压缩已关闭），可手动压缩'
            : '上下文即将达到压缩阈值，稍后将自动压缩';
        try {
          await store.appendStatusChange(task.id, message);
        } catch (_) {}
        onNotification?.call(message, 'compactWarning');
      }
      return;
    }
    if (!forced && _compactionBreaker.isOpen) return;
    final covered = selectCompactionPrefix(
      entries,
      keepChars: budget.compactionKeepChars,
    );
    if (covered.isEmpty) {
      if (forced) {
        try {
          await store.appendStatusChange(task.id, '内容太少，无需压缩');
        } catch (_) {}
        // 强制请求已消费但没有落压缩事件：清理「压缩中」实况行。
        onCompactionFailed?.call();
      }
      return;
    }
    onPreCompact?.call();
    final summary = await llm.summarizeForCompaction(
      task,
      covered,
      customInstructions: manualRequest?.customInstructions,
    );
    if (summary.trim().isEmpty) {
      throw StateError('压缩摘要为空（可能是模型未配置或模型返回空结果）');
    }
    // 压缩后文件恢复（升级计划 ⑥）：被覆盖区间里最近读过的文件
    // 快照随摘要一起注入视图，模型不必重读。
    final restored = selectRestoredFiles(
      covered: covered,
      kept: entries.sublist(covered.length),
    );
    await store.appendCompaction(
      task.id,
      coveredCount: covered.length,
      summary: summary.trim(),
      restoredFiles: restored,
    );
    _compactionBreaker.recordSuccess();
    // 压缩成功后允许再次预警（对齐 CC suppressCompactWarning 语义：
    // 压缩把上下文降下来了，之后再逼近阈值应再次提醒）。
    _compactionWarningNotified = false;
    onPostCompact?.call(summary.trim());
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

  /// 解析 ask_user 参数（RooCode ask_followup_question 风格）：
  /// question + follow_up 建议答案列表。
  (String, List<String>) _parseUserQuestion(AgentToolCallRequest call) {
    try {
      final json = jsonDecode(call.argsJson) as Map<String, dynamic>;
      final question = (json['question'] as String? ?? '').trim();
      if (question.isNotEmpty) {
        return (question, _trimmedStrings(json['follow_up']));
      }
    } catch (_) {
      // 解析失败时仍落一个可回答的问题，避免任务挂起但 UI 无内容。
    }
    return ('需要你的输入', const []);
  }

  static List<String> _trimmedStrings(Object? raw) {
    if (raw is! List<dynamic>) return const [];
    final result = <String>[];
    for (final item in raw.take(4)) {
      if (item is! String) continue;
      final normalized = item.trim();
      if (normalized.isEmpty || result.contains(normalized)) continue;
      result.add(normalized);
    }
    return result;
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
