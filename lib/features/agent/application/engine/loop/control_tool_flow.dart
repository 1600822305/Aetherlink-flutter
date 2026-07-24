import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/control_tool_parsing.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/finish_guards.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/task_transition.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// enter_plan_mode 成功后回填给模型的行为指令（对标 CC 工具结果）。
const String kEnterPlanModeResult =
    '已进入计划模式。接下来你应该：\n'
    '1. 用只读工具充分探索代码，理解既有模式与相似实现\n'
    '2. 权衡多种实现路径的取舍\n'
    '3. 需要澄清需求时用 ask_user 提问\n'
    '4. 用 update_plan 维护方案要点（全量覆盖式提交）\n'
    '5. 方案完整后调用 exit_plan_mode 提交全文请求批准\n'
    '记住：现在不要修改任何文件，这是只读的探索与设计阶段。';

/// 验证类计划条目的识别模式（对标 CC verification nudge 的 /verif/i）。
final RegExp _kVerifyItemPattern = RegExp(
  'verif|test|check|验证|测试|校验|检查|自测',
  caseSensitive: false,
);

/// 一次收尾 3+ 项且无验证类条目时附加在 update_plan 结果里的提醒
/// （对标 CC TodoWriteTool verification nudge）。
const String kPlanVerificationNudge =
    '\n\n注意：本次收尾了 3 个以上条目，'
    '但计划中没有任何验证类步骤。写最终总结前，先运行相应的验证'
    '（测试 / 静态分析 / 构建等）确认成果；不要用总结里的保留意见'
    '代替实际验证。';

/// 控制工具处理后循环该往哪走。
enum ControlToolOutcome {
  /// 处理完毕，继续本轮下一个工具调用。
  nextCall,

  /// 中止本轮剩余工具，回到循环顶部（下一轮）。
  nextTurn,

  /// 结束本次运行（收尾/挂起/请求重启）。
  stopRun,
}

/// agent 专属控制工具的引擎内处理（初稿 §5.4）：update_plan /
/// ask_user / enter_plan_mode / exit_plan_mode / finish_task。
/// 状态迁移经 [tx] 写回，调用方处理完从 `tx.current` 取最新任务快照。
class ControlToolFlow {
  ControlToolFlow({
    required this.store,
    required this.budget,
    required this.tx,
    required this.guards,
    this.onNotification,
    this.onTaskEnd,
    this.onModeSwitchRestart,
  });

  final AgentEventStore store;
  final AgentBudget budget;
  final TaskTransitions tx;
  final FinishGuards guards;
  final void Function(String message, String type)? onNotification;
  final void Function()? onTaskEnd;
  final void Function(AgentTask task)? onModeSwitchRestart;

  /// 处理一个控制工具调用；非控制工具返回 null（走普通执行路径）。
  /// [failPendingToolEvents] 回填本轮剩余预建事件；
  /// [resolvePlanApproval] 为方案审批裁决，返回 true 表示已批准并
  /// 请求重启。
  Future<ControlToolOutcome?> handle(
    AgentToolCallRequest call, {
    required Future<void> Function() failPendingToolEvents,
    required Future<bool> Function(
      ToolCallEvent event,
      AgentToolCallRequest call,
      String plan,
    )
    resolvePlanApproval,
  }) {
    return switch (call.name) {
      kToolAskUser => _askUser(call, failPendingToolEvents),
      kToolUpdatePlan => _updatePlan(call),
      kToolEnterPlanMode => _enterPlanMode(call, failPendingToolEvents),
      kToolExitPlanMode => _exitPlanMode(
        call,
        failPendingToolEvents,
        resolvePlanApproval,
      ),
      kToolFinishTask => _finishTask(call, failPendingToolEvents),
      _ => Future.value(null),
    };
  }

  Future<ControlToolOutcome> _askUser(
    AgentToolCallRequest call,
    Future<void> Function() failPendingToolEvents,
  ) async {
    final (question, suggestions) = parseUserQuestion(call);
    await store.appendUserQuestion(
      tx.current.id,
      question,
      suggestions: suggestions,
      toolCallId: call.id,
      argsJson: call.argsJson,
    );
    await failPendingToolEvents();
    await tx.transition(AgentTaskStatus.waitingInput, '等待回答：$question');
    onNotification?.call('等待回答：$question', 'question');
    return ControlToolOutcome.stopRun;
  }

  /// 控制工具的结果落库（append + update 两步，与普通工具同款事件）。
  Future<ToolCallEvent> _logControlResult(
    AgentToolCallRequest call, {
    required bool ok,
    required String summary,
    required String detail,
    String argSummary = '',
  }) async {
    final event = await store.appendToolCall(
      tx.current.id,
      AgentToolCallRequest(
        id: call.id,
        name: call.name,
        argsJson: call.argsJson,
        argSummary: argSummary,
      ),
      AgentToolCallState.running,
    );
    return store.updateToolCall(
      tx.current.id,
      event,
      state: ok ? AgentToolCallState.success : AgentToolCallState.failure,
      resultSummary: summary,
      resultDetail: detail,
    );
  }

  Future<ControlToolOutcome> _updatePlan(AgentToolCallRequest call) async {
    switch (parsePlanUpdate(call)) {
      case PlanUpdateInvalid(:final reason):
        await _logControlResult(
          call,
          ok: false,
          summary: '计划参数无效',
          detail:
              'update_plan 参数无效，本次提交已忽略（已有计划保持'
              '不变）：$reason\n请修正后全量重新提交。',
          argSummary: '计划更新',
        );
        budget.recordToolResult(ok: false);
      case PlanUpdateOk(:final items):
        final done = items
            .where((i) => i.status == AgentPlanItemStatus.completed)
            .length;
        final allDone = done == items.length;
        // 全部完成即收尾：清空计划（对标 CC TodoWrite allDone）。
        await store.appendPlanUpdate(tx.current.id, allDone ? const [] : items);
        // 验证提醒（对标 CC verification nudge）：一次收尾 3+ 项
        // 且计划里没有任何验证类条目时，在结果里附加提醒，
        // 防"标完成不验证"。
        final needsVerifyNudge =
            allDone &&
            items.length >= 3 &&
            !items.any((i) => _kVerifyItemPattern.hasMatch(i.content));
        await _logControlResult(
          call,
          ok: true,
          summary: allDone ? '计划全部完成' : '计划已更新 $done/${items.length}',
          detail: allDone
              ? '所有条目已完成，计划已清空。'
                    '${needsVerifyNudge ? kPlanVerificationNudge : ''}'
              : '计划已更新（$done/${items.length} 完成）。继续按计划'
                    '推进；完成或开始某项时全量重新提交以更新状态。',
          argSummary: '${items.length} 项计划',
        );
        budget.recordToolResult(ok: true);
    }
    return ControlToolOutcome.nextCall;
  }

  Future<ControlToolOutcome> _enterPlanMode(
    AgentToolCallRequest call,
    Future<void> Function() failPendingToolEvents,
  ) async {
    final current = tx.current;
    if (current.mode == AgentSessionMode.plan ||
        current.mode == AgentSessionMode.ask) {
      await _logControlResult(
        call,
        ok: false,
        summary: '已在只读模式',
        detail: '当前已是只读模式，无需进入计划模式，直接继续分析与规划。',
      );
      budget.recordToolResult(ok: false);
      return ControlToolOutcome.nextCall;
    }
    final previous = current.mode;
    await _logControlResult(
      call,
      ok: true,
      summary: '已进入计划模式',
      detail: kEnterPlanModeResult,
    );
    await store.appendStatusChange(
      current.id,
      '模式切换：${previous.name} → plan（模型请求先规划）',
    );
    final next = await tx.save(
      current.copyWith(
        mode: AgentSessionMode.plan,
        prePlanMode: previous,
        updatedAt: DateTime.now(),
        lastEventSummary: '已进入计划模式',
      ),
    );
    await failPendingToolEvents();
    onModeSwitchRestart?.call(next);
    return ControlToolOutcome.stopRun;
  }

  Future<ControlToolOutcome> _exitPlanMode(
    AgentToolCallRequest call,
    Future<void> Function() failPendingToolEvents,
    Future<bool> Function(
      ToolCallEvent event,
      AgentToolCallRequest call,
      String plan,
    )
    resolvePlanApproval,
  ) async {
    if (tx.current.mode != AgentSessionMode.plan) {
      await _logControlResult(
        call,
        ok: false,
        summary: '不在计划模式',
        detail: '当前不在计划模式。若方案已获批准，直接继续实现即可。',
      );
      budget.recordToolResult(ok: false);
      return ControlToolOutcome.nextCall;
    }
    final plan = stringArgOf(call, 'plan')?.trim() ?? '';
    if (plan.isEmpty) {
      await _logControlResult(
        call,
        ok: false,
        summary: '缺少方案内容',
        detail: 'plan 参数为空：需提交完整的实现方案全文供用户审批。',
      );
      budget.recordToolResult(ok: false);
      return ControlToolOutcome.nextCall;
    }
    final event = await store.appendToolCall(
      tx.current.id,
      AgentToolCallRequest(
        id: call.id,
        name: call.name,
        argsJson: call.argsJson,
        argSummary: '请求批准方案',
      ),
      AgentToolCallState.waitingApproval,
    );
    if (await resolvePlanApproval(event, call, plan)) {
      await failPendingToolEvents();
      return ControlToolOutcome.stopRun;
    }
    return ControlToolOutcome.nextCall;
  }

  Future<ControlToolOutcome> _finishTask(
    AgentToolCallRequest call,
    Future<void> Function() failPendingToolEvents,
  ) async {
    final current = tx.current;
    if (!guards.finishGuardFired &&
        !FinishGuards.hasFinalReply(await store.getEvents(current.id))) {
      guards.finishGuardFired = true;
      await _logControlResult(
        call,
        ok: false,
        summary: '收尾被拒：缺少正文回复',
        detail:
            '你还没有输出面向用户的正文回复。分析、调研、解答类'
            '任务的正文就是交付物：请先把最终结论/报告作为正文完整'
            '输出，再调用 finish_task；summary 只是一句话标题，'
            '不能替代正文。',
      );
      budget.recordToolResult(ok: false);
      return ControlToolOutcome.nextCall;
    }
    final blocked = await guards.checkStopGuard();
    if (blocked != null) {
      await store.appendUserMessage(current.id, '[stop hook 阻止收尾] $blocked');
      return ControlToolOutcome.nextTurn;
    }
    // summary 只进任务列表（lastEventSummary）；事件流里正文
    // 就是结束语，状态行只留元信息，不再重复展示 summary。
    final summary = stringArgOf(call, 'summary') ?? '任务完成';
    await failPendingToolEvents();
    await store.appendStatusChange(current.id, '任务完成 · ${current.rounds} 轮');
    await tx.save(
      current.copyWith(
        status: AgentTaskStatus.done,
        updatedAt: DateTime.now(),
        lastEventSummary: summary,
      ),
    );
    onTaskEnd?.call();
    return ControlToolOutcome.stopRun;
  }
}
