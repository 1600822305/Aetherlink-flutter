import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 一轮 LLM 调用内，工具调用流式预建事件的簿记：
/// 参数一流完就先落「执行中」事件（不等整轮结束），UI 实时看到块；
/// 执行循环按 call id 复用预建事件；各种中止路径把残留事件按
/// 「已中断 ✗」回填，避免永久 running。从引擎主循环拆出。
class TurnStreamBinder {
  TurnStreamBinder({
    required this.store,
    required this.taskId,
    required this.isInternalTool,
    this.toolStream,
  });

  final AgentEventStore store;
  final String taskId;

  /// 引擎内部处理的控制工具（update_plan/ask_user/…/spawn_subagent）：
  /// 不做流式预建。
  final bool Function(String name) isInternalTool;

  /// 工具参数流式生成的实时通道（纯内存）；null = 不做实时预览。
  final AgentToolStreamSink? toolStream;

  static const Duration _kMinPersistInterval = Duration(milliseconds: 500);

  /// 参数仍在流式生成中的调用：streamKey → 事件（节流落库更新）。
  final Map<String, ToolCallEvent> _streaming = {};
  final Map<String, DateTime> _persistAt = {};

  /// 参数已流完、等待执行循环领取的预建事件：call id → 事件队列。
  final Map<String, List<ToolCallEvent>> _preCreated = {};

  /// LLM 流回调：工具参数增量。实时预览走内存通道，每个 delta 都推
  /// （UI 直接监听）；落库只按节流做崩溃恢复持久化，不承担实时性。
  Future<void> onToolCallDelta(
    String streamKey,
    String? toolName,
    String argsTextSoFar,
  ) async {
    if (toolName == null || isInternalTool(toolName)) return;
    final existing = _streaming[streamKey];
    if (existing == null) {
      final created = await store.appendToolCall(
        taskId,
        AgentToolCallRequest(
          id: streamKey,
          name: toolName,
          argsJson: argsTextSoFar,
          argSummary: '生成参数中…',
        ),
        AgentToolCallState.running,
      );
      _streaming[streamKey] = created;
      _persistAt[streamKey] = DateTime.now();
      toolStream?.update(created.id, toolName, argsTextSoFar);
      return;
    }
    toolStream?.update(existing.id, toolName, argsTextSoFar);
    final now = DateTime.now();
    final last = _persistAt[streamKey];
    if (last != null && now.difference(last) < _kMinPersistInterval) {
      return;
    }
    _persistAt[streamKey] = now;
    _streaming[streamKey] = await store.updateToolCall(
      taskId,
      existing,
      state: AgentToolCallState.running,
      argsDetail: argsTextSoFar,
    );
  }

  /// LLM 流回调：单个工具调用参数流完，转成待执行的预建事件。
  Future<void> onToolCall(AgentToolCallRequest call, String? streamKey) async {
    if (isInternalTool(call.name)) return;
    final streamed = streamKey == null ? null : _streaming.remove(streamKey);
    if (streamed != null) toolStream?.clear(streamed.id);
    final event = streamed != null
        ? await store.updateToolCall(
            taskId,
            streamed,
            state: AgentToolCallState.running,
            argSummary: call.argSummary,
            argsDetail: call.argsJson,
          )
        : await store.appendToolCall(taskId, call, AgentToolCallState.running);
    _preCreated.putIfAbsent(call.id, () => []).add(event);
  }

  /// 执行循环领取预建事件；没有（非流式路径）则新建 running 事件。
  Future<ToolCallEvent> claimEvent(AgentToolCallRequest call) async {
    final pre = _preCreated[call.id];
    if (pre != null && pre.isNotEmpty) return pre.removeAt(0);
    return store.appendToolCall(taskId, call, AgentToolCallState.running);
  }

  /// 流中断：参数仍在流式生成中的事件按失败回填。
  Future<void> failStreaming() async {
    for (final event in _streaming.values) {
      toolStream?.clear(event.id);
      await store.updateToolCall(taskId, event,
          state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
    }
    _streaming.clear();
  }

  /// 预建了但未随 turn 返回的调用（流中断）按失败回填。
  Future<void> failUnreturned(Set<String> returnedIds) async {
    for (final entry in _preCreated.entries) {
      if (returnedIds.contains(entry.key)) continue;
      for (final event in entry.value) {
        await store.updateToolCall(taskId, event,
            state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
      }
      entry.value.clear();
    }
  }

  /// 本轮中止：尚未执行的全部预建事件按中断回填，避免永久停在
  /// running（包括 turn 已返回但未来得及执行的调用）。
  Future<void> failAllPending() async {
    for (final entry in _preCreated.values) {
      for (final event in entry) {
        await store.updateToolCall(taskId, event,
            state: AgentToolCallState.failure, resultSummary: '已中断 ✗');
      }
      entry.clear();
    }
  }
}
