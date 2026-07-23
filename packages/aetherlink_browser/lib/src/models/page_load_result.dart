/// open/waitForLoad 的结果（设计稿 §3）：标题 + 最终 URL（重定向后）
/// + 是否完全加载（超时但部分可读时 false）。
class PageLoadResult {
  const PageLoadResult({
    required this.title,
    required this.finalUrl,
    required this.completed,
  });

  final String title;
  final String finalUrl;

  /// false = 等待超时后截停（stopLoading），页面可能部分可读。
  final bool completed;
}
