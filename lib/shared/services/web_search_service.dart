import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/bing_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/bocha_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/brave_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/duckduckgo_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/exa_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/grok_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/jina_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/linkup_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/metaso_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/perplexity_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/querit_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/searxng_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/serper_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/tavily_search.dart';
import 'package:aetherlink_flutter/shared/services/web_search/zhipu_search.dart';

/// Unified web search dispatcher — routes a search request to the provider
/// identified by [SearchProviderConfig.id] and formats the result as a
/// [McpToolResult] that the LLM can consume.
///
/// Each provider lives in its own file under `web_search/`. This class is
/// a thin dispatcher that delegates to the appropriate provider class.
class WebSearchService {
  WebSearchService._();

  /// Execute a search with the given [config] provider.
  static Future<McpToolResult> search({
    required SearchProviderConfig config,
    required String query,
    int maxResults = 5,
    int timeout = 10,
    String language = 'zh-CN',
    String categories = 'general',
  }) async {
    final timeoutDuration = Duration(seconds: timeout);

    switch (config.id) {
      case 'searxng':
        return SearxngSearch.search(config, query, maxResults, timeoutDuration, language, categories);
      case 'bing-free':
        return BingSearch.search(query, maxResults, timeoutDuration, language);
      case 'duckduckgo':
        return DuckDuckGoSearch.search(query, maxResults, timeoutDuration, language);
      case 'tavily':
        return TavilySearch.search(config, query, maxResults, timeoutDuration);
      case 'exa':
        return ExaSearch.search(config, query, maxResults, timeoutDuration);
      case 'brave':
        return BraveSearch.search(config, query, maxResults, timeoutDuration);
      case 'serper':
        return SerperSearch.search(config, query, maxResults, timeoutDuration);
      case 'bocha':
        return BochaSearch.search(config, query, maxResults, timeoutDuration);
      case 'zhipu':
        return ZhipuSearch.search(config, query, maxResults, timeoutDuration);
      case 'jina':
        return JinaSearch.search(config, query, maxResults, timeoutDuration);
      case 'perplexity':
        return PerplexitySearch.search(config, query, maxResults, timeoutDuration);
      case 'metaso':
        return MetasoSearch.search(config, query, maxResults, timeoutDuration);
      case 'linkup':
        return LinkUpSearch.search(config, query, maxResults, timeoutDuration);
      case 'querit':
        return QueritSearch.search(config, query, maxResults, timeoutDuration);
      case 'grok':
        return GrokSearch.search(config, query, maxResults, timeoutDuration);
      default:
        return McpToolResult(
          '不支持的搜索提供商: ${config.name} (${config.id})',
          isError: true,
        );
    }
  }
}
