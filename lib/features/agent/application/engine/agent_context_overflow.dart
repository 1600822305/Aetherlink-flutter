/// prompt-too-long 反应式压缩（升级计划 ⑧，对标 Claude Code
/// `query.ts` 的 prompt-too-long recovery）：识别供应商「上下文超限」
/// 类错误，供引擎兜底压缩后重试本轮。纯函数，独立于执行层便于单测。
library;

/// 各供应商上下文超限报错的关键词（小写匹配）：
/// - Anthropic：`prompt is too long: X tokens > Y maximum`
/// - OpenAI：`context_length_exceeded` / `maximum context length`
/// - Google：`input token count exceeds the maximum`
/// - 通用网关：`request too large` / `too many tokens`
const List<String> _kContextOverflowPatterns = [
  'prompt is too long',
  'prompt_too_long',
  'context_length_exceeded',
  'context length exceeded',
  'maximum context length',
  'input is too long',
  'input token count exceeds',
  'exceeds the maximum number of tokens',
  'too many tokens',
  'request too large',
];

/// 判断一个异常是否是「上下文超限」类错误（可通过压缩恢复）。
bool isContextOverflowError(Object error) {
  final text = error.toString().toLowerCase();
  return _kContextOverflowPatterns.any(text.contains);
}
