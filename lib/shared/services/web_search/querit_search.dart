import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Querit — 搜索聚合。
class QueritSearch {
  QueritSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Querit');
    try {
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://api.querit.ai/v1/search'),
        {'query': query, 'count': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Querit 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = (data['results'] as Map?)?['result'] as List?;
      final items = (results ?? []).take(maxResults).map((item) {
        final m = (item as Map).cast<String, dynamic>();
        final snippet = m['snippet']?.toString().trim() ?? '';
        return {
          'title':
              (m['title']?.toString().trim() ?? m['url']?.toString() ?? ''),
          'url': (m['url'] ?? '').toString(),
          'text': snippet,
        };
      }).toList();
      return SearchHelpers.formatResults('Querit', query, items);
    } catch (e) {
      return SearchHelpers.error('Querit', e);
    }
  }
}
