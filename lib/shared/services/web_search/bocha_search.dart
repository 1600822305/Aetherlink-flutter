import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// 博查 (Bocha) — AI 搜索引擎。
class BochaSearch {
  BochaSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Bocha');
    try {
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://api.bochaai.com/v1/web-search'),
        {'query': query, 'count': maxResults, 'summary': true},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Bocha 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final d = (data['data'] ?? const {}) as Map<String, dynamic>;
      final webPages = (d['webPages'] ?? const {}) as Map<String, dynamic>;
      final value = (webPages['value'] as List?) ?? [];
      final items = value.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['name'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': ((m['summary'] ?? m['snippet']) ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('博查 (Bocha)', query, items);
    } catch (e) {
      return SearchHelpers.error('Bocha', e);
    }
  }
}
