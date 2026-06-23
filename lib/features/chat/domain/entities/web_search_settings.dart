import 'package:flutter/foundation.dart';

/// A single search-provider configuration — the Flutter port of the web's
/// `WebSearchProviderConfig`. Each provider the user adds gets one of these.
@immutable
class SearchProviderConfig {
  const SearchProviderConfig({
    required this.id,
    required this.name,
    this.apiHost = '',
    this.apiKey = '',
    this.isEnabled = true,
  });

  final String id;
  final String name;
  final String apiHost;
  final String apiKey;
  final bool isEnabled;

  SearchProviderConfig copyWith({
    String? id,
    String? name,
    String? apiHost,
    String? apiKey,
    bool? isEnabled,
  }) =>
      SearchProviderConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        apiHost: apiHost ?? this.apiHost,
        apiKey: apiKey ?? this.apiKey,
        isEnabled: isEnabled ?? this.isEnabled,
      );

  factory SearchProviderConfig.fromJson(Map<String, dynamic> json) =>
      SearchProviderConfig(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        apiHost: json['apiHost'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apiHost': apiHost,
        'apiKey': apiKey,
        'isEnabled': isEnabled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchProviderConfig &&
          other.id == id &&
          other.name == name &&
          other.apiHost == apiHost &&
          other.apiKey == apiKey &&
          other.isEnabled == isEnabled;

  @override
  int get hashCode => Object.hash(id, name, apiHost, apiKey, isEnabled);
}

/// The default search provider seeded for every fresh install: SearXNG needs
/// no API key and falls back to a built-in public instance when [apiHost] is
/// empty, so web search works out of the box without any setup. Kept as a
/// const so it can back the default [WebSearchSettings.providers].
const SearchProviderConfig kDefaultSearchProvider = SearchProviderConfig(
  id: 'searxng',
  name: 'SearXNG',
);

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
    this.activeProviderId = 'searxng',
    this.providers = const [kDefaultSearchProvider],
  });

  /// Maximum number of results returned per search.
  final int maxResults;

  /// Request timeout in seconds.
  final int timeout;

  /// Language code for search queries (e.g. 'zh-CN', 'en').
  final String language;

  /// Default search category (general, news, science, it, etc.).
  final String categories;

  /// The currently active provider id used for searching.
  final String activeProviderId;

  /// User-added search providers (only these are shown in the list page).
  final List<SearchProviderConfig> providers;

  WebSearchSettings copyWith({
    int? maxResults,
    int? timeout,
    String? language,
    String? categories,
    String? activeProviderId,
    List<SearchProviderConfig>? providers,
  }) =>
      WebSearchSettings(
        maxResults: maxResults ?? this.maxResults,
        timeout: timeout ?? this.timeout,
        language: language ?? this.language,
        categories: categories ?? this.categories,
        activeProviderId: activeProviderId ?? this.activeProviderId,
        providers: providers ?? this.providers,
      );

  factory WebSearchSettings.fromJson(Map<String, dynamic> json) =>
      WebSearchSettings(
        maxResults: json['maxResults'] as int? ?? 5,
        timeout: json['timeout'] as int? ?? 10,
        language: json['language'] as String? ?? 'zh-CN',
        categories: json['categories'] as String? ?? 'general',
        activeProviderId: json['activeProviderId'] as String? ?? 'searxng',
        providers: (json['providers'] as List<dynamic>?)
                ?.map((e) =>
                    SearchProviderConfig.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'maxResults': maxResults,
        'timeout': timeout,
        'language': language,
        'categories': categories,
        'activeProviderId': activeProviderId,
        'providers': providers.map((p) => p.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSearchSettings &&
          other.maxResults == maxResults &&
          other.timeout == timeout &&
          other.language == language &&
          other.categories == categories &&
          other.activeProviderId == activeProviderId &&
          listEquals(other.providers, providers);

  @override
  int get hashCode => Object.hash(
        maxResults,
        timeout,
        language,
        categories,
        activeProviderId,
        Object.hashAll(providers),
      );
}
