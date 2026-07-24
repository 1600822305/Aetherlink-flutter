import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 收尾防线（每次运行一份）：正文缺失拦截与 stop hook 校验，
/// 两者各自最多触发一次（防弱模型/hook 永不满意导致死循环）。
class FinishGuards {
  FinishGuards({this.stopGuard});

  /// 收尾校验（stop hook）：返回 null 放行收尾；返回原因则阻止本次
  /// 收尾，原因以用户消息回填继续跑。
  final Future<String?> Function()? stopGuard;

  bool _stopGuardFired = false;

  /// finish_task 无正文拦截只触发一次。
  bool finishGuardFired = false;

  Future<String?> checkStopGuard() async {
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

  /// 最后一条用户消息之后是否存在非空助手正文：分析/调研类任务的
  /// 交付物就是正文，没有正文的 finish_task 视为零产出收尾。
  static bool hasFinalReply(List<AgentEvent> events) {
    for (final event in events.reversed) {
      if (event is UserMessageEvent) return false;
      if (event is AssistantTextEvent && event.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
