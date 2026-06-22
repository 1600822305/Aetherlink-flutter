import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// Unified web search dispatcher — routes a search request to the provider
/// identified by [SearchProviderConfig.id] and formats the result as a
/// [McpToolResult] that the LLM can consume.
///
/// Provider implementations follow the same conventions as Kelivo's search
/// services but use `dart:io` [HttpClient] (the project standard for
/// builtin tools) instead of `package:http`.
class WebSearchService {
  WebSearchService._();

  /// Execute a search with the given [config] provider.
  ///
  /// [query] is the search string.
  /// [maxResults], [timeout], [language], [categories] come from
  /// [WebSearchSettings] or per-call overrides.
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
        return _searxng(config, query, maxResults, timeoutDuration, language, categories);
      case 'bing-free':
        return _bingLocal(query, maxResults, timeoutDuration, language);
      case 'duckduckgo':
        return _duckDuckGo(query, maxResults, timeoutDuration, language);
      case 'tavily':
        return _tavily(config, query, maxResults, timeoutDuration);
      case 'exa':
        return _exa(config, query, maxResults, timeoutDuration);
      case 'brave':
        return _brave(config, query, maxResults, timeoutDuration);
      case 'serper':
        return _serper(config, query, maxResults, timeoutDuration);
      case 'bocha':
        return _bocha(config, query, maxResults, timeoutDuration);
      case 'zhipu':
        return _zhipu(config, query, maxResults, timeoutDuration);
      case 'jina':
        return _jina(config, query, maxResults, timeoutDuration);
      case 'perplexity':
        return _perplexity(config, query, maxResults, timeoutDuration);
      case 'metaso':
        return _metaso(config, query, maxResults, timeoutDuration);
      case 'linkup':
        return _linkUp(config, query, maxResults, timeoutDuration);
      case 'querit':
        return _querit(config, query, maxResults, timeoutDuration);
      case 'grok':
        return _grok(config, query, maxResults, timeoutDuration);
      default:
        return McpToolResult(
          '不支持的搜索提供商: ${config.name} (${config.id})',
          isError: true,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  static HttpClient _client(Duration timeout) =>
      HttpClient()..connectionTimeout = timeout;

  /// GET request returning decoded UTF-8 body.
  static Future<(int statusCode, String body)> _get(
    Uri uri,
    Duration timeout, {
    Map<String, String> headers = const {},
  }) async {
    final client = _client(timeout);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      for (final e in headers.entries) {
        request.headers.set(e.key, e.value);
      }
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      return (response.statusCode, body);
    } finally {
      client.close();
    }
  }

  /// POST request with JSON body returning decoded UTF-8 body.
  static Future<(int statusCode, String body)> _post(
    Uri uri,
    Map<String, dynamic> payload,
    Duration timeout, {
    Map<String, String> headers = const {},
  }) async {
    final client = _client(timeout);
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      for (final e in headers.entries) {
        request.headers.set(e.key, e.value);
      }
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      return (response.statusCode, body);
    } finally {
      client.close();
    }
  }

  /// Format a list of result maps into the Markdown format the LLM expects.
  static McpToolResult _formatResults(
    String providerName,
    String query,
    List<Map<String, String>> results, {
    String? answer,
  }) {
    final buf = StringBuffer();
    buf.writeln('## $providerName 搜索结果\n');
    buf.writeln('**查询**: $query');
    buf.writeln('**结果数**: ${results.length}');
    buf.writeln('\n---\n');

    if (answer != null && answer.isNotEmpty) {
      buf.writeln('## 摘要\n');
      buf.writeln('> $answer\n');
      buf.writeln('---\n');
    }

    if (results.isEmpty) {
      buf.writeln('未找到相关结果\n');
    } else {
      for (var i = 0; i < results.length; i++) {
        final item = results[i];
        buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
        if (item['url']?.isNotEmpty == true) {
          buf.writeln('**链接**: ${item['url']}\n');
        }
        if (item['text']?.isNotEmpty == true) {
          buf.writeln('**摘要**: ${item['text']}\n');
        }
        buf.writeln('---\n');
      }
    }

    buf.write('*数据来源: $providerName*');
    return McpToolResult(buf.toString());
  }

  static McpToolResult _error(String provider, Object error) =>
      McpToolResult('$provider 搜索失败: $error', isError: true);

  static McpToolResult _apiKeyMissing(String provider) =>
      McpToolResult('$provider 需要 API Key，请在设置中配置', isError: true);

  // ---------------------------------------------------------------------------
  // SearXNG
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _searxng(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
    String language,
    String categories,
  ) async {
    try {
      final baseUrl = (config.apiHost.isNotEmpty
              ? config.apiHost
              : 'http://154.37.208.52:39281')
          .replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
        'q': query,
        'format': 'json',
        'language': language,
        'categories': categories,
      });
      final (status, body) = await _get(uri, timeout);
      if (status != 200) {
        return McpToolResult('SearXNG 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, Object?>;
      final rawResults = (data['results'] as List?) ?? [];
      final items = rawResults.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['content'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('SearXNG', query, items);
    } catch (e) {
      return _error('SearXNG', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Bing (Local HTML scraping)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _bingLocal(
    String query,
    int maxResults,
    Duration timeout,
    String language,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse('https://www.bing.com/search?q=$encodedQuery');
      final client = _client(timeout);
      try {
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
        request.headers.set('Accept-Language', language);
        final response = await request.close().timeout(timeout);
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode != 200) {
          return McpToolResult(
            'Bing 请求失败 (${response.statusCode})',
            isError: true,
          );
        }

        final items = _parseBingHtml(body, maxResults);
        return _formatResults('Bing', query, items);
      } finally {
        client.close();
      }
    } catch (e) {
      return _error('Bing', e);
    }
  }

  /// Parses Bing search result HTML without an HTML parser dependency.
  /// Extracts `<li class="b_algo">` blocks using regex heuristics.
  static List<Map<String, String>> _parseBingHtml(String html, int max) {
    final results = <Map<String, String>>[];
    // Match each <li class="b_algo"> ... </li> block
    final liPattern = RegExp(
      r'<li[^>]*class="b_algo"[^>]*>(.*?)</li>',
      dotAll: true,
    );
    for (final liMatch in liPattern.allMatches(html)) {
      if (results.length >= max) break;
      final block = liMatch.group(1) ?? '';

      // Extract title + URL from <h2><a href="...">title</a></h2>
      final linkMatch = RegExp(
        r'<h2[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      if (linkMatch == null) continue;

      final url = linkMatch.group(1) ?? '';
      final titleHtml = linkMatch.group(2) ?? '';
      final title = _stripHtmlTags(titleHtml).trim();

      // Extract snippet from <p> inside .b_caption or .b_algoSlug
      var snippet = '';
      final snippetMatch = RegExp(
        r'class="b_caption"[^>]*>.*?<p[^>]*>(.*?)</p>',
        dotAll: true,
      ).firstMatch(block);
      if (snippetMatch != null) {
        snippet = _stripHtmlTags(snippetMatch.group(1) ?? '').trim();
      }

      if (title.isNotEmpty || url.isNotEmpty) {
        results.add({'title': title, 'url': url, 'text': snippet});
      }
    }
    return results;
  }

  /// Strips HTML tags from a string.
  static String _stripHtmlTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '');

  // ---------------------------------------------------------------------------
  // DuckDuckGo (HTML lite version — no external package needed)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _duckDuckGo(
    String query,
    int maxResults,
    Duration timeout,
    String language,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse(
          'https://html.duckduckgo.com/html/?q=$encodedQuery&kl=$language');
      final client = _client(timeout);
      try {
        final request = await client.getUrl(uri);
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
        final response = await request.close().timeout(timeout);
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode != 200) {
          return McpToolResult(
            'DuckDuckGo 请求失败 (${response.statusCode})',
            isError: true,
          );
        }

        final items = _parseDdgHtml(body, maxResults);
        return _formatResults('DuckDuckGo', query, items);
      } finally {
        client.close();
      }
    } catch (e) {
      return _error('DuckDuckGo', e);
    }
  }

  /// Parses DuckDuckGo HTML lite search results.
  static List<Map<String, String>> _parseDdgHtml(String html, int max) {
    final results = <Map<String, String>>[];
    // DuckDuckGo HTML lite uses <div class="result results_links results_links_deep web-result">
    final resultPattern = RegExp(
      r'<div[^>]*class="[^"]*result[^"]*results_links[^"]*"[^>]*>(.*?)</div>\s*</div>',
      dotAll: true,
    );
    for (final match in resultPattern.allMatches(html)) {
      if (results.length >= max) break;
      final block = match.group(1) ?? '';

      // Title + URL from <a class="result__a" href="...">title</a>
      final linkMatch = RegExp(
        r'<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      if (linkMatch == null) continue;

      var url = linkMatch.group(1) ?? '';
      // DuckDuckGo wraps URLs through a redirect
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (uddgMatch != null) {
        url = Uri.decodeComponent(uddgMatch.group(1) ?? url);
      }
      final title = _stripHtmlTags(linkMatch.group(2) ?? '').trim();

      // Snippet from <a class="result__snippet" ...>
      var snippet = '';
      final snippetMatch = RegExp(
        r'class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      if (snippetMatch != null) {
        snippet = _stripHtmlTags(snippetMatch.group(1) ?? '').trim();
      }

      if (title.isNotEmpty || url.isNotEmpty) {
        results.add({'title': title, 'url': url, 'text': snippet});
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Tavily
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _tavily(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Tavily');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.tavily.com/search';
      final (status, body) = await _post(
        Uri.parse(url),
        {'query': query, 'max_results': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Tavily 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = ((data['results'] as List?) ?? []).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['content'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('Tavily', query, items,
          answer: data['answer']?.toString());
    } catch (e) {
      return _error('Tavily', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Exa
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _exa(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Exa');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.exa.ai/search';
      final (status, body) = await _post(
        Uri.parse(url),
        {
          'query': query,
          'numResults': maxResults,
          'contents': {'text': true},
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Exa 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = ((data['results'] as List?) ?? []).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['text'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('Exa', query, items);
    } catch (e) {
      return _error('Exa', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Brave Search
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _brave(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Brave');
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final baseUrl = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.search.brave.com/res/v1/web/search';
      final uri = Uri.parse('$baseUrl?q=$encodedQuery&count=$maxResults');
      final (status, body) = await _get(
        uri,
        timeout,
        headers: {'X-Subscription-Token': config.apiKey},
      );
      if (status != 200) {
        return McpToolResult('Brave 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final webResults = (data['web']?['results'] as List?) ?? [];
      final items = webResults.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['description'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('Brave Search', query, items);
    } catch (e) {
      return _error('Brave Search', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Serper (Google)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _serper(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Serper');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://google.serper.dev/search';
      final (status, body) = await _post(
        Uri.parse(url),
        {'q': query},
        timeout,
        headers: {'X-API-KEY': config.apiKey},
      );
      if (status != 200) {
        return McpToolResult('Serper 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final organic = (data['organic'] as List?) ?? [];
      final items = organic.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['link'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('Serper', query, items);
    } catch (e) {
      return _error('Serper', e);
    }
  }

  // ---------------------------------------------------------------------------
  // 博查 (Bocha)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _bocha(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Bocha');
    try {
      final (status, body) = await _post(
        Uri.parse('https://api.bochaai.com/v1/web-search'),
        {'query': query, 'count': maxResults, 'summary': true},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Bocha 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final d = (data['data'] ?? const {}) as Map<String, dynamic>;
      final webPages = (d['webPages'] ?? const {}) as Map<String, dynamic>;
      final value = (webPages['value'] as List?) ?? [];
      final items = value.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['name'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': ((m['summary'] ?? m['snippet']) ?? '').toString(),
        };
      }).toList();
      return _formatResults('博查 (Bocha)', query, items);
    } catch (e) {
      return _error('Bocha', e);
    }
  }

  // ---------------------------------------------------------------------------
  // 智谱搜索 (Zhipu)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _zhipu(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('智谱搜索');
    try {
      final (status, body) = await _post(
        Uri.parse('https://open.bigmodel.cn/api/paas/v4/web_search'),
        {
          'search_query': query,
          'search_engine': 'search_std',
          'count': maxResults,
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('智谱搜索 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final searchResult = (data['search_result'] as List?) ?? [];
      final items = searchResult.map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['link'] ?? '').toString(),
          'text': (m['content'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('智谱搜索', query, items);
    } catch (e) {
      return _error('智谱搜索', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Jina
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _jina(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Jina');
    try {
      // Jina can be slow; enforce minimum 15s timeout
      final effectiveTimeout =
          timeout.inSeconds < 15 ? const Duration(seconds: 15) : timeout;
      final (status, body) = await _post(
        Uri.parse('https://s.jina.ai/'),
        {'q': query},
        effectiveTimeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Jina 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final listRaw =
          (data['data'] ?? data['results'] ?? const <dynamic>[]) as List;
      final items = listRaw.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['description'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('Jina', query, items);
    } catch (e) {
      return _error('Jina', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Perplexity
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _perplexity(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Perplexity');
    try {
      final (status, body) = await _post(
        Uri.parse('https://api.perplexity.ai/search'),
        {'query': query, 'max_results': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult(
            'Perplexity 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final resultsList = (data['results'] as List?) ?? [];
      // Support both flat list and nested list shapes
      final flat = <Map<String, dynamic>>[];
      for (final item in resultsList) {
        if (item is List) {
          for (final sub in item) {
            if (sub is Map<String, dynamic>) flat.add(sub);
          }
        } else if (item is Map<String, dynamic>) {
          flat.add(item);
        }
      }
      final items = flat.take(maxResults).map((m) {
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('Perplexity', query, items);
    } catch (e) {
      return _error('Perplexity', e);
    }
  }

  // ---------------------------------------------------------------------------
  // 秘塔 (Metaso)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _metaso(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('秘塔');
    try {
      final (status, body) = await _post(
        Uri.parse('https://metaso.cn/api/v1/search'),
        {
          'q': query,
          'scope': 'webpage',
          'size': maxResults,
          'includeSummary': false,
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('秘塔 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final webpages = (data['webpages'] as List?) ?? [];
      final items = webpages.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['link'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('秘塔 (Metaso)', query, items);
    } catch (e) {
      return _error('秘塔', e);
    }
  }

  // ---------------------------------------------------------------------------
  // LinkUp
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _linkUp(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('LinkUp');
    try {
      final (status, body) = await _post(
        Uri.parse('https://api.linkup.so/v1/search'),
        {
          'q': query,
          'depth': 'standard',
          'outputType': 'sourcedAnswer',
          'includeImages': 'false',
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('LinkUp 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final sources = (data['sources'] as List?) ?? [];
      final items = sources.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['name'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return _formatResults('LinkUp', query, items,
          answer: data['answer']?.toString());
    } catch (e) {
      return _error('LinkUp', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Querit
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _querit(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Querit');
    try {
      final (status, body) = await _post(
        Uri.parse('https://api.querit.ai/v1/search'),
        {'query': query, 'count': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Querit 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = (data['results'] as Map?)?['result'] as List?;
      final items = (results ?? []).take(maxResults).map((item) {
        final m = (item as Map).cast<String, dynamic>();
        final snippet = m['snippet']?.toString().trim() ?? '';
        return {
          'title': (m['title']?.toString().trim() ?? m['url']?.toString() ?? ''),
          'url': (m['url'] ?? '').toString(),
          'text': snippet,
        };
      }).toList();
      return _formatResults('Querit', query, items);
    } catch (e) {
      return _error('Querit', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Grok (xAI Responses API with web_search tool)
  // ---------------------------------------------------------------------------

  static Future<McpToolResult> _grok(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return _apiKeyMissing('Grok');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.x.ai/v1/responses';
      final (status, body) = await _post(
        Uri.parse(url),
        {
          'model': 'grok-3-mini',
          'input': [
            {
              'role': 'system',
              'content':
                  'You are a search assistant. Answer the user query using web search. Be concise.',
            },
            {'role': 'user', 'content': query},
          ],
          'tools': [
            {'type': 'web_search'},
          ],
          'store': false,
          'stream': false,
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Grok 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Extract text answer from output
      final output = (data['output'] as List?) ?? [];
      String? answer;
      for (final item in output) {
        if (item is Map && item['type'] == 'message' && item['role'] == 'assistant') {
          final content = (item['content'] as List?) ?? [];
          for (final c in content) {
            if (c is Map && c['type'] == 'output_text') {
              answer = c['text']?.toString();
              break;
            }
          }
        }
      }

      // Extract citations as search results
      final items = <Map<String, String>>[];
      final seenUrls = <String>{};
      void addCitations(Object? citations) {
        final citationList = (citations as List?) ?? [];
        for (final citation in citationList) {
          if (items.length >= maxResults) return;
          if (citation is String) {
            final url = citation.trim();
            if (url.isNotEmpty && seenUrls.add(url)) {
              items.add({'title': url, 'url': url, 'text': ''});
            }
          } else if (citation is Map && citation['type'] == 'url_citation') {
            final url = citation['url']?.toString().trim() ?? '';
            if (url.isNotEmpty && seenUrls.add(url)) {
              items.add({
                'title': citation['title']?.toString() ?? url,
                'url': url,
                'text': '',
              });
            }
          }
        }
      }

      addCitations(data['citations']);
      // Also check annotations in text content
      for (final item in output) {
        if (item is Map && item['type'] == 'message') {
          for (final c in ((item['content'] as List?) ?? [])) {
            if (c is Map) addCitations(c['annotations']);
          }
        }
      }

      return _formatResults('Grok', query, items, answer: answer);
    } catch (e) {
      return _error('Grok', e);
    }
  }
}
