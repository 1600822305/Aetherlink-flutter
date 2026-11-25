import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 收尾防线（每次运行一份）：正文缺失拦截与 stop hook 校验，
/// 两者各自最多触发一次（防弱模型/hook 永不满意导致死循环）。
class FinishGuards {
  FinishGuards({this.stopGuard});

  /// 收尾校验（stop hook）：返回 null 放行收尾；返回原因则阻止本次
  /// 收尾，原因以用户消息回填继续跑。
  final Future<String?> Function()? stopGuard;

  bool _stopGuardFired = false;

  /// 无工具调用兜底路径的「缺正文」提醒只触发一次（finish_task 已改为
  /// result 参数交付，不再走这道拦截）。
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
  /// 引擎自己注入的提示（[系统] 续跑/空回复/未调工具提醒、stop hook
  /// 阻止）虽然落成 UserMessageEvent，但不是用户的新请求，不能把它
  /// 之前已经输出的正文作废，否则模型按提醒调 finish_task 会被误拒。
  static bool hasFinalReply(List<AgentEvent> events) {
    for (final event in events.reversed) {
      if (event is UserMessageEvent) {
        if (isEngineInjected(event.text)) continue;
        return false;
      }
      if (event is AssistantTextEvent && event.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// 最后一条真实用户消息之后的最后一段非空助手正文（无则 null）。
  static String? lastReplyText(List<AgentEvent> events) {
    for (final event in events.reversed) {
      if (event is UserMessageEvent) {
        if (isEngineInjected(event.text)) continue;
        return null;
      }
      if (event is AssistantTextEvent && event.text.trim().isNotEmpty) {
        return event.text;
      }
    }
    return null;
  }

  /// 引擎注入的系统提示前缀（与 agent_engine / control_tool_flow 中
  /// appendUserMessage 的文案保持一致）。
  static bool isEngineInjected(String text) {
    final t = text.trimLeft();
    return t.startsWith('[系统]') || t.startsWith('[stop hook');
  }
}
