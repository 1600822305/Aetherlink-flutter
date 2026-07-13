import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 模型发起的一次工具调用请求（function calling 的最小映射）。
class AgentToolCallRequest {
  const AgentToolCallRequest({
    required this.id,
    required this.name,
    required this.argsJson,
    required this.argSummary,
  });

  final String id;
  final String name;

  /// 完整参数 JSON（落 ToolCallEvent.argsDetail）。
  final String argsJson;

  /// 单行关键参数（落 ToolCallEvent.argSummary）。
  final String argSummary;
}

/// 一轮 LLM 调用的最终结果（文本已通过 onTextDelta 流式吐出）。
class AgentLlmTurn {
  const AgentLlmTurn({
    this.text = '',
    this.toolCalls = const [],
    this.tokensUsed = 0,
    this.contextTokens = 0,
  });

  final String text;
  final List<AgentToolCallRequest> toolCalls;

  /// 本次调用的 token 用量（计费口径，跨轮累加进 task.tokenCount）。
  final int tokensUsed;

  /// 本次请求结束时的上下文占用（输入+输出，对比窗口上限）。0 = 未知。
  final int contextTokens;
}

/// 一轮调用的上下文：任务 + 事件流（压缩视图后续在引擎内做）。
class AgentLlmContext {
  const AgentLlmContext({required this.task, required this.events});

  final AgentTask task;
  final List<AgentEvent> events;
}

/// LLM 调用抽象：骨架期用假实现跑通状态机，接真实现时经 app/di
/// 复用 provider 层流式调用（初稿 §5.2 系统提示组装也在真实现里做）。
abstract class AgentLlmClient {
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    AgentCancellationToken? cancel,
  });

  /// 上下文压缩（设计初稿 §5.3）：把一段较早的事件压缩成一条摘要文本，
  /// 供 CompactionEvent 在后续重放中替代被覆盖区间。非流式、不带工具。
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  );
}
