/// Persisted web-search configuration — the Flutter equivalent of the web's
/// `webSearchSlice` state. Controls how the `builtin_web_search` tool behaves
/// when the 网络搜索 session mode is active.
///
/// Written as a plain immutable class (no freezed) to avoid code generation
/// for this small, stable value type.
class WebSearchSettings {
  const WebSearchSettings({
    this.maxResults = 5,
    this.timeout = 10,
    this.language = 'zh-CN',
    this.categories = 'general',
  });

  /// Maximum number of results returned per search.
  final int maxResults;

  /// Request timeout in seconds.
  final int timeout;

  /// Language code for search queries (e.g. 'zh-CN', 'en').
  final String language;

  /// Default search category (general, news, science, it, etc.).
  final String categories;

  WebSearchSettings copyWith({
    int? maxResults,
    int? timeout,
    String? language,
    String? categories,
  }) =>
      WebSearchSettings(
        maxResults: maxResults ?? this.maxResults,
        timeout: timeout ?? this.timeout,
        language: language ?? this.language,
        categories: categories ?? this.categories,
      );

  factory WebSearchSettings.fromJson(Map<String, dynamic> json) =>
      WebSearchSettings(
        maxResults: json['maxResults'] as int? ?? 5,
        timeout: json['timeout'] as int? ?? 10,
        language: json['language'] as String? ?? 'zh-CN',
        categories: json['categories'] as String? ?? 'general',
      );

  Map<String, dynamic> toJson() => {
        'maxResults': maxResults,
        'timeout': timeout,
        'language': language,
        'categories': categories,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSearchSettings &&
          other.maxResults == maxResults &&
          other.timeout == timeout &&
          other.language == language &&
          other.categories == categories;

  @override
  int get hashCode => Object.hash(maxResults, timeout, language, categories);
}
