import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Bing (Local) — 免费 HTML 抓取，无需 API Key。
class BingSearch {
  BingSearch._();

  static Future<McpToolResult> search(
    String query,
    int maxResults,
    Duration timeout,
    String language,
  ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final uri = Uri.parse('https://www.bing.com/search?q=$encodedQuery');
      final client = SearchHelpers.client(timeout);
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
        return SearchHelpers.formatResults('Bing', query, items);
      } finally {
        client.close();
      }
    } catch (e) {
      return SearchHelpers.error('Bing', e);
    }
  }

  /// Parses Bing search result HTML using regex heuristics.
  static List<Map<String, String>> _parseBingHtml(String html, int max) {
    final results = <Map<String, String>>[];
    final liPattern = RegExp(
      r'<li[^>]*class="b_algo"[^>]*>(.*?)</li>',
      dotAll: true,
    );
    for (final liMatch in liPattern.allMatches(html)) {
      if (results.length >= max) break;
      final block = liMatch.group(1) ?? '';

      final linkMatch = RegExp(
        r'<h2[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      if (linkMatch == null) continue;

      final url = linkMatch.group(1) ?? '';
      final titleHtml = linkMatch.group(2) ?? '';
      final title = SearchHelpers.stripHtmlTags(titleHtml).trim();

      var snippet = '';
      final snippetMatch = RegExp(
        r'class="b_caption"[^>]*>.*?<p[^>]*>(.*?)</p>',
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
