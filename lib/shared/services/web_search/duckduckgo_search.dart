import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// DuckDuckGo — 免费 HTML lite 版本抓取，无需 API Key。
class DuckDuckGoSearch {
  DuckDuckGoSearch._();

  static Future<McpToolResult> search(
    String query,
    int maxResults,
    Duration timeout,
    String language,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse(
          'https://html.duckduckgo.com/html/?q=$encodedQuery&kl=$language');
      final client = SearchHelpers.client(timeout);
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
        return SearchHelpers.formatResults('DuckDuckGo', query, items);
      } finally {
        client.close();
      }
    } catch (e) {
      return SearchHelpers.error('DuckDuckGo', e);
    }
  }

  /// Parses DuckDuckGo HTML lite search results.
  static List<Map<String, String>> _parseDdgHtml(String html, int max) {
    final results = <Map<String, String>>[];
    final resultPattern = RegExp(
      r'<div[^>]*class="[^"]*result[^"]*results_links[^"]*"[^>]*>(.*?)</div>\s*</div>',
      dotAll: true,
    );
    for (final match in resultPattern.allMatches(html)) {
      if (results.length >= max) break;
      final block = match.group(1) ?? '';

      final linkMatch = RegExp(
        r'<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      if (linkMatch == null) continue;

      var url = linkMatch.group(1) ?? '';
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (uddgMatch != null) {
        url = Uri.decodeComponent(uddgMatch.group(1) ?? url);
      }
      final title = SearchHelpers.stripHtmlTags(linkMatch.group(2) ?? '').trim();

      var snippet = '';
      final snippetMatch = RegExp(
        r'class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      if (snippetMatch != null) {
        snippet = SearchHelpers.stripHtmlTags(snippetMatch.group(1) ?? '').trim();
      }

      if (title.isNotEmpty || url.isNotEmpty) {
        results.add({'title': title, 'url': url, 'text': snippet});
      }
    }
    return results;
  }
}
