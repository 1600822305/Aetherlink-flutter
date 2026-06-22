import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// RikkaHub — RikkaHub's own search service.
class RikkaHubSearch {
  RikkaHubSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('RikkaHub');
    try {
      final baseUrl = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.rikka-ai.com/v1/search';
      final (status, body) = await SearchHelpers.post(
        Uri.parse(baseUrl),
        {
          'q': query,
          'depth': 'basic',
          'outputType': 'sourcedAnswer',
          'includeImages': 'false',
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('RikkaHub 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final answer = data['answer']?.toString();
      final sources = (data['sources'] as List?) ?? [];
      final items = sources.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['name'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults(
        'RikkaHub',
        query,
        items,
        answer: answer,
      );
    } catch (e) {
      return SearchHelpers.error('RikkaHub', e);
    }
  }
}
