import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Bing (Local) — 免费 HTML 抓取，无需 API Key。
///
/// 使用移动端 User-Agent 获取服务端渲染的 HTML（桌面端 Bing 返回纯 JS
/// 渲染的页面，无法用 regex 解析）。
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
        // 移动端 UA — Bing 对移动端返回服务端渲染的 HTML，桌面端则是
        // 纯 JS 渲染，regex 无法解析。
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
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
        if (items.isEmpty) {
          return McpToolResult(
            'Bing 未能解析到搜索结果，可能页面结构已变化',
            isError: true,
          );
        }
        return SearchHelpers.formatResults('Bing', query, items);
      } finally {
        client.close();
      }
    } catch (e) {
      return SearchHelpers.error('Bing', e);
    }
  }

  /// Parses Bing mobile search result HTML using regex heuristics.
  ///
  /// Mobile Bing HTML structure (2024+):
  /// ```html
  /// <li class="b_algo">
  ///   <div class="b_tpcn"><a class="tilk" href="...">...</a></div>
  ///   <div class="b_algoheader"><a href="URL"><h2>TITLE</h2></a></div>
  ///   <div class="b_caption"><p>SNIPPET</p></div>
  /// </li>
  /// ```
  static List<Map<String, String>> _parseBingHtml(String html, int max) {
    final results = <Map<String, String>>[];
    final liPattern = RegExp(
      r'<li[^>]*class="b_algo"[^>]*>(.*?)</li>',
      dotAll: true,
    );
    for (final liMatch in liPattern.allMatches(html)) {
      if (results.length >= max) break;
      final block = liMatch.group(1) ?? '';

      // 优先匹配 b_algoheader 内的 a > h2 结构（移动端 Bing 2024+ 格式）
      var url = '';
      var title = '';
      final headerMatch = RegExp(
        r'class="b_algoheader"[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>\s*<h2[^>]*>(.*?)</h2>',
        dotAll: true,
      ).firstMatch(block);
      if (headerMatch != null) {
        url = headerMatch.group(1) ?? '';
        title = SearchHelpers.stripHtmlTags(headerMatch.group(2) ?? '').trim();
      } else {
        // 回退：旧版桌面端 h2 > a 结构
        final linkMatch = RegExp(
          r'<h2[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
          dotAll: true,
        ).firstMatch(block);
        if (linkMatch == null) continue;
        url = linkMatch.group(1) ?? '';
        title = SearchHelpers.stripHtmlTags(linkMatch.group(2) ?? '').trim();
      }

      var snippet = '';
      final snippetMatch = RegExp(
        r'class="b_caption"[^>]*>.*?<p[^>]*>(.*?)</p>',
        dotAll: true,
      ).firstMatch(block);
      if (snippetMatch != null) {
        snippet =
            SearchHelpers.stripHtmlTags(snippetMatch.group(1) ?? '').trim();
      }

      if (title.isNotEmpty || url.isNotEmpty) {
        results.add({'title': title, 'url': url, 'text': snippet});
      }
    }
    return results;
  }
}
