import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Brave Search — 独立搜索引擎 API。
class BraveSearch {
  BraveSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Brave');
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final baseUrl = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.search.brave.com/res/v1/web/search';
      final uri = Uri.parse('$baseUrl?q=$encodedQuery&count=$maxResults');
      final (status, body) = await SearchHelpers.get(
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
      return SearchHelpers.formatResults('Brave Search', query, items);
    } catch (e) {
      return SearchHelpers.error('Brave Search', e);
    }
  }
}
