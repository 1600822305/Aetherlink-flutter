/// 抓取一个网页并转成可摄取的正文（设计文档 §5「URL 抓取 → Markdown 快照」）。
///
/// 具体实现（HTTP 请求 + HTML→Markdown）由组合根注入，知识核心只持有这个函数，
/// 与 [KnowledgeEmbedderResolver] 一样保持可测（单测传一个假抓取器即可，不触网）。
typedef KnowledgeUrlFetcher = Future<KnowledgeFetchedPage> Function(String url);

/// URL 抓取结果：转好的正文快照（Markdown / 纯文本）+ 可选页面标题。
class KnowledgeFetchedPage {
  const KnowledgeFetchedPage({required this.markdown, this.title});

  /// 抓取并转换后的正文，直接喂给切块 + 嵌入管线。
  final String markdown;

  /// 页面标题（来自 `<title>`）；为空时调用方回落到 URL 本身作为条目标题。
  final String? title;
}
