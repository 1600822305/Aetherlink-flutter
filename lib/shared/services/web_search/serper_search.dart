import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Serper — Google 搜索结果 API。
class SerperSearch {
  SerperSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Serper');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://google.serper.dev/search';
      final (status, body) = await SearchHelpers.post(
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
      return SearchHelpers.formatResults('Serper', query, items);
    } catch (e) {
      return SearchHelpers.error('Serper', e);
    }
  }
}
