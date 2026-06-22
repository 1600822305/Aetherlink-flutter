import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Tinyfish — AI search API.
class TinyfishSearch {
  TinyfishSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Tinyfish');
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final baseUrl = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.search.tinyfish.ai';
      final uri = Uri.parse('$baseUrl?query=$encodedQuery');
      final (status, body) = await SearchHelpers.get(
        uri,
        timeout,
        headers: {'X-API-Key': config.apiKey},
      );
      if (status != 200) {
        return McpToolResult('Tinyfish 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      final items = results.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('Tinyfish', query, items);
    } catch (e) {
      return SearchHelpers.error('Tinyfish', e);
    }
  }
}
