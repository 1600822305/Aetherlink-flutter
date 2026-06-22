import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Perplexity — AI 搜索引擎。
class PerplexitySearch {
  PerplexitySearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Perplexity');
    try {
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://api.perplexity.ai/search'),
        {'query': query, 'max_results': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult(
            'Perplexity 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final resultsList = (data['results'] as List?) ?? [];
      // Support both flat list and nested list shapes
      final flat = <Map<String, dynamic>>[];
      for (final item in resultsList) {
        if (item is List) {
          for (final sub in item) {
            if (sub is Map<String, dynamic>) flat.add(sub);
          }
        } else if (item is Map<String, dynamic>) {
          flat.add(item);
        }
      }
      final items = flat.take(maxResults).map((m) {
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('Perplexity', query, items);
    } catch (e) {
      return SearchHelpers.error('Perplexity', e);
    }
  }
}
