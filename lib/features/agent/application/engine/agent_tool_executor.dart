import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';

/// 工具执行结果（失败也是结果，回填给模型继续——循环设计稿 §1.5）。
class AgentToolResult {
  const AgentToolResult({
    required this.ok,
    required this.summary,
    this.detail,
    this.overflowPath,
    this.imagePath,
    this.imageMimeType,
  });

  final bool ok;

  /// 例：`234 行 · 0.4s`、`失败 ✗ 文件不存在`。
  final String summary;

  /// 回填内容（大输出已截断：头尾保留 + 落盘路径提示）。
  final String? detail;

  /// 大输出全文落盘路径（未截断时为 null；详情面板「查看全文」用）。
  final String? overflowPath;

  /// 图片结果落盘路径（截图类工具用；图片不进事件库，
  /// 重放层读文件注入多模态图片消息）。
  final String? imagePath;

  /// [imagePath] 图片的 MIME 类型（如 `image/jpeg`）。
  final String? imageMimeType;
}

/// 同一只读并发段内最多并行执行的工具数（对标 CC
/// MAX_TOOL_USE_CONCURRENCY=10）。
const int kMaxConcurrentReadTools = 10;

/// 引擎侧工具超时兜底的上限（对标 CC BASH_MAX_TIMEOUT_MS：默认 2 分钟、
/// 模型可传参提高、封顶 10 分钟）。
const Duration kAgentToolTimeoutMax = Duration(minutes: 10);

/// 长命令类工具的引擎兜底超时在其自身超时之上的宽限：让工具自己的
/// 优雅超时路径（部分输出 + 会话里继续跑）先于引擎硬掐触发。
const Duration kAgentToolTimeoutGrace = Duration(seconds: 30);

/// 引擎超时兜底时保留给模型的部分输出预算：头 [kAgentTimeoutPartialHeadChars]
/// + 尾 [kAgentTimeoutPartialTailChars]（错误/进度通常在尾部）。
const int kAgentTimeoutPartialHeadChars = 1000;
const int kAgentTimeoutPartialTailChars = 3000;

/// 长命令类调用的引擎兜底超时：尊重调用自带的超时参数
/// [requestedTimeoutMs]（封顶 [kAgentToolTimeoutMax]）并加
/// [kAgentToolTimeoutGrace] 宽限；未传参或不长于 [fallback] 时
/// 维持 [fallback]（兜底只放宽、不收紧）。
Duration resolveAgentToolTimeout({
  required Duration fallback,
  int? requestedTimeoutMs,
}) {
  if (requestedTimeoutMs == null || requestedTimeoutMs <= 0) return fallback;
  var requested = Duration(milliseconds: requestedTimeoutMs);
  if (requested > kAgentToolTimeoutMax) requested = kAgentToolTimeoutMax;
  final withGrace = requested + kAgentToolTimeoutGrace;
  return withGrace > fallback ? withGrace : fallback;
}

/// 超时前已流出的部分输出裁剪：超预算时保留头尾、砍中间。
String clipAgentTimeoutPartialOutput(String output) {
  const limit = kAgentTimeoutPartialHeadChars + kAgentTimeoutPartialTailChars;
  if (output.length <= limit) return output;
  final omitted = output.length - limit;
  return '${output.substring(0, kAgentTimeoutPartialHeadChars)}\n'
      '…（部分输出过长，中间省略 $omitted 字符）…\n'
      '${output.substring(output.length - kAgentTimeoutPartialTailChars)}';
}

/// 工具分发抽象：骨架期用假实现；接真实现时经 app/di 复用 ToolRoute
/// 分发（下沉共享 helper，初稿 §5.1）。
abstract class AgentToolExecutor {
  const AgentToolExecutor();

  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  );

  /// 该调用是否并发安全（只读，对标 CC isConcurrencySafe）：引擎把同一轮
  /// 里连续的并发安全调用成批并行执行；不确定时返回 false 保持串行。
  bool isConcurrencySafe(AgentToolCallRequest call);

  /// 该调用的引擎兜底超时：默认一刀切用 [fallback]（预算配置）；
  /// 长命令类工具（终端等）按 [resolveAgentToolTimeout] 分级放宽。
  Duration timeoutFor(AgentToolCallRequest call, Duration fallback) => fallback;

  /// 引擎兜底超时命中时取该调用已流出的部分输出（回填给模型看进度），
  /// 没有流式输出的工具返回 null。
  String? partialOutput(AgentToolCallRequest call) => null;
}
