import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// DuckDuckGo — 免费搜索，无需 API Key。
///
/// 使用 DuckDuckGo 的 HTML lite 版本抓取。注意：DuckDuckGo 可能对自动化
/// 请求返回 CAPTCHA 验证页面，导致搜索失败。在移动设备上直接发起请求通常
/// 比服务端/数据中心 IP 更可靠。
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
        final request = await client.postUrl(uri);
        // 模拟移动浏览器 — 降低被 CAPTCHA 拦截的概率
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
        request.headers
            .set('Content-Type', 'application/x-www-form-urlencoded');
        request.headers.set('Referer', 'https://html.duckduckgo.com/');
        request.write('q=${Uri.encodeComponent(query)}&kl=$language');
        final response = await request.close().timeout(timeout);
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode != 200) {
          return McpToolResult(
            'DuckDuckGo 请求失败 (${response.statusCode})',
            isError: true,
          );
        }

        // 检测 CAPTCHA 页面
        if (body.contains('please click') &&
            body.contains('is not a robot') ||
            body.contains('duckduckgo-captcha')) {
          return McpToolResult(
            'DuckDuckGo 返回了验证页面 (CAPTCHA)，无法自动搜索。'
            '建议切换到其他搜索提供商（如 Bing 免费 或 SearXNG）。',
            isError: true,
          );
        }

        final items = _parseDdgHtml(body, maxResults);
        if (items.isEmpty) {
          return McpToolResult(
            'DuckDuckGo 未能解析到搜索结果。DuckDuckGo 的反机器人机制可能阻止了请求。'
            '建议切换到 Bing 免费 或 SearXNG 等其他提供商。',
            isError: true,
          );
        }
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
    // DDG HTML lite result blocks
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
      // DDG wraps real URLs in a redirect with uddg= parameter
      final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(url);
      if (uddgMatch != null) {
        url = Uri.decodeComponent(uddgMatch.group(1) ?? url);
      }
      final title =
          SearchHelpers.stripHtmlTags(linkMatch.group(2) ?? '').trim();

      var snippet = '';
      final snippetMatch = RegExp(
        r'class="result__snippet"[^>]*>(.*?)</a>',
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
