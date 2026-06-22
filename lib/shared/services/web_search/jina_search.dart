import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Jina — 搜索 + 网页阅读。
class JinaSearch {
  JinaSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Jina');
    try {
      // Jina can be slow; enforce minimum 15s timeout
      final effectiveTimeout =
          timeout.inSeconds < 15 ? const Duration(seconds: 15) : timeout;
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://s.jina.ai/'),
        {'q': query},
        effectiveTimeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Jina 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final listRaw =
          (data['data'] ?? data['results'] ?? const <dynamic>[]) as List;
      final items = listRaw.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['description'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('Jina', query, items);
    } catch (e) {
      return SearchHelpers.error('Jina', e);
    }
  }
}
