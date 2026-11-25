import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 收尾防线（每次运行一份）：stop hook 校验最多触发一次（防 hook 永不
/// 满意导致死循环），以及引擎注入消息的识别。
class FinishGuards {
  FinishGuards({this.stopGuard});

  /// 收尾校验（stop hook）：返回 null 放行收尾；返回原因则阻止本次
  /// 收尾，原因以用户消息回填继续跑。
  final Future<String?> Function()? stopGuard;

  bool _stopGuardFired = false;

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
