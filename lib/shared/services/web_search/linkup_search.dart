import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// LinkUp — 链接聚合搜索服务。
class LinkUpSearch {
  LinkUpSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('LinkUp');
    try {
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://api.linkup.so/v1/search'),
        {
          'q': query,
          'depth': 'standard',
          'outputType': 'sourcedAnswer',
          'includeImages': 'false',
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('LinkUp 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final sources = (data['sources'] as List?) ?? [];
      final items = sources.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['name'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('LinkUp', query, items,
          answer: data['answer']?.toString());
    } catch (e) {
      return SearchHelpers.error('LinkUp', e);
    }
  }
}
