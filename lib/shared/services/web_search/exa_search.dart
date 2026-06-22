import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Exa — 神经搜索引擎。
class ExaSearch {
  ExaSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Exa');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.exa.ai/search';
      final (status, body) = await SearchHelpers.post(
        Uri.parse(url),
        {
          'query': query,
          'numResults': maxResults,
          'contents': {'text': true},
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Exa 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = ((data['results'] as List?) ?? []).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['text'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('Exa', query, items);
    } catch (e) {
      return SearchHelpers.error('Exa', e);
    }
  }
}
