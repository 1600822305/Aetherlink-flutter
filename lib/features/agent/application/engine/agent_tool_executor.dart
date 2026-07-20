import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';

/// 工具执行结果（失败也是结果，回填给模型继续——循环设计稿 §1.5）。
class AgentToolResult {
  const AgentToolResult({
    required this.ok,
    required this.summary,
    this.detail,
    this.overflowPath,
  });

  final bool ok;

  /// 例：`234 行 · 0.4s`、`失败 ✗ 文件不存在`。
  final String summary;

  /// 回填内容（大输出已截断：头尾保留 + 落盘路径提示）。
  final String? detail;

  /// 大输出全文落盘路径（未截断时为 null；详情面板「查看全文」用）。
  final String? overflowPath;
}

/// 同一只读并发段内最多并行执行的工具数（对标 CC
/// MAX_TOOL_USE_CONCURRENCY=10）。
const int kMaxConcurrentReadTools = 10;

/// 工具分发抽象：骨架期用假实现；接真实现时经 app/di 复用 ToolRoute
/// 分发（下沉共享 helper，初稿 §5.1）。
abstract class AgentToolExecutor {
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  );

  /// 该调用是否并发安全（只读，对标 CC isConcurrencySafe）：引擎把同一轮
  /// 里连续的并发安全调用成批并行执行；不确定时返回 false 保持串行。
  bool isConcurrencySafe(AgentToolCallRequest call);
}
