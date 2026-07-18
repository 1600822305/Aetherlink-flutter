import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/fetch_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Fetch — 网页直读提供商。把查询中的 URL 直接抓取并转成 Markdown 正文
/// 返回给模型，不做关键词搜索。无需 API Key。
class FetchSearch {
  FetchSearch._();

  /// Max characters of extracted content kept per fetched page.
  static const _maxContentLength = 8000;

  static final _urlPattern = RegExp(
    r'''https?://[^\s<>"'\)\]]+''',
    caseSensitive: false,
  );

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    final urls = _extractUrls(query);
    if (urls.isEmpty) {
      return const McpToolResult(
        'Fetch 提供商仅支持抓取网页链接，请在查询中提供以 http(s):// 开头的 URL，'
        '或改用其它搜索提供商进行关键词搜索',
        isError: true,
      );
    }

    final items = <Map<String, String>>[];
    for (final url in urls.take(maxResults)) {
      items.add(await _fetchOne(url, timeout));
    }
    return SearchHelpers.formatResults('Fetch', query, items);
  }

  /// Pulls every http(s) URL out of [query]; a bare-URL query yields itself.
  static List<String> _extractUrls(String query) {
    final trimmed = query.trim();
    final matches =
        _urlPattern.allMatches(trimmed).map((m) => m.group(0)!).toList();
    if (matches.isEmpty && trimmed.isNotEmpty && !trimmed.contains(' ')) {
      // Bare domain like "example.com/page" — try it as https.
      if (RegExp(r'^[\w-]+(\.[\w-]+)+(/\S*)?$').hasMatch(trimmed)) {
        matches.add('https://$trimmed');
      }
    }
    // De-duplicate while keeping order.
    final seen = <String>{};
    return [
      for (final url in matches)
        if (seen.add(url)) url,
    ];
  }

  static Future<Map<String, String>> _fetchOne(
    String url,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        )
        ..set(
          'Accept',
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        );
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return {
          'title': url,
          'url': url,
          'text': '抓取失败: HTTP ${response.statusCode}',
        };
      }

      final contentType = response.headers.contentType?.toString() ?? '';
      String content;
      var title = url;
      if (contentType.contains('html') || body.trimLeft().startsWith('<')) {
        content = htmlToMarkdown(body);
        // htmlToMarkdown puts the page <title> on a leading "# " line.
        final firstLine = content.split('\n').first;
        if (firstLine.startsWith('# ')) {
          title = firstLine.substring(2).trim();
        }
      } else {
        content = body;
      }
      if (content.length > _maxContentLength) {
        content = '${content.substring(0, _maxContentLength)}\n\n…(内容已截断)';
      }
      return {'title': title, 'url': url, 'text': content};
    } catch (e) {
      return {'title': url, 'url': url, 'text': '抓取失败: $e'};
    } finally {
      client.close();
    }
  }
}
