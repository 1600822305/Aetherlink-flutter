// 工具参数流式生成的实时通道：引擎每收到一个参数 delta 就推一次
// （纯内存，不落库），UI 直接监听拿最新参数前缀做实时预览（红绿 diff /
// 详情抽屉）。参数流完或调用中断时 clear。落库仍由引擎按节流持久化，
// 只承担崩溃恢复，不再承担实时展示。

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一条正在流式生成参数的工具调用快照。
class StreamingToolCall {
  const StreamingToolCall({
    required this.eventId,
    required this.toolName,
    required this.argsText,
  });

  /// 对应 ToolCallEvent 的 id（UI 据此把实时参数对回事件）。
  final String eventId;
  final String toolName;

  /// 已生成的参数 JSON 前缀（可能未闭合）。
  final String argsText;
}

/// 引擎侧写入口（抽象出来让引擎不依赖 riverpod 具体实现，测试可注 fake）。
abstract class AgentToolStreamSink {
  void update(String eventId, String toolName, String argsText);
  void clear(String eventId);
}

class AgentToolStreamNotifier extends Notifier<Map<String, StreamingToolCall>>
    implements AgentToolStreamSink {
  @override
  Map<String, StreamingToolCall> build() => const {};

  @override
  void update(String eventId, String toolName, String argsText) {
    state = {
      ...state,
      eventId: StreamingToolCall(
        eventId: eventId,
        toolName: toolName,
        argsText: argsText,
      ),
    };
  }

  @override
  void clear(String eventId) {
    if (!state.containsKey(eventId)) return;
    state = Map.of(state)..remove(eventId);
  }
}

/// eventId → 实时参数快照。UI watch 后每个 delta 都会重建。
final agentToolStreamProvider = NotifierProvider<AgentToolStreamNotifier,
    Map<String, StreamingToolCall>>(AgentToolStreamNotifier.new);
