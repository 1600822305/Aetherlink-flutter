/// open 的结果（设计稿 §3）：标题 + 最终 URL（重定向后）。
/// 加载超时不返回结果，而是抛 navigationTimeout（设计稿 §19.2）。
class PageLoadResult {
  const PageLoadResult({
    required this.title,
    required this.finalUrl,
  });

  final String title;
  final String finalUrl;
}
