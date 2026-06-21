/// Persisted web-search settings (provider selection, result count, timeout).
///
/// Plain Dart class (no freezed) — same pattern as [NetworkProxySettings] so
/// it can be serialized through [JsonKvNotifier] without `build_runner`.
class WebSearchSettings {
  const WebSearchSettings({
    this.selectedProvider = 0,
    this.maxResults = 5,
    this.timeout = 10,
  });

  factory WebSearchSettings.fromJson(Map<String, dynamic> json) {
    return WebSearchSettings(
      selectedProvider: (json['selectedProvider'] as num?)?.toInt() ?? 0,
      maxResults: (json['maxResults'] as num?)?.toInt() ?? 5,
      timeout: (json['timeout'] as num?)?.toInt() ?? 10,
    );
  }

  /// Index into the provider list (currently only SearXNG = 0).
  final int selectedProvider;

  /// Maximum number of search results per query.
  final int maxResults;

  /// Search request timeout in seconds.
  final int timeout;

  Map<String, dynamic> toJson() => {
    'selectedProvider': selectedProvider,
    'maxResults': maxResults,
    'timeout': timeout,
  };

  WebSearchSettings copyWith({
    int? selectedProvider,
    int? maxResults,
    int? timeout,
  }) {
    return WebSearchSettings(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      maxResults: maxResults ?? this.maxResults,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WebSearchSettings &&
            selectedProvider == other.selectedProvider &&
            maxResults == other.maxResults &&
            timeout == other.timeout;
  }

  @override
  int get hashCode => Object.hash(selectedProvider, maxResults, timeout);
}
