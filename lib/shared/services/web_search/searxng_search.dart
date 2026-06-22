import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// SearXNG — 聚合搜索引擎，免费无需 API Key。
class SearxngSearch {
  SearxngSearch._();

  static Future<McpToolResult> search(
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
      final (status, body) = await SearchHelpers.get(uri, timeout);
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
      return SearchHelpers.formatResults('SearXNG', query, items);
    } catch (e) {
      return SearchHelpers.error('SearXNG', e);
    }
  }
}
