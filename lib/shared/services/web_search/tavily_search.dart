import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Tavily — AI 优化的搜索 API。
class TavilySearch {
  TavilySearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Tavily');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.tavily.com/search';
      final (status, body) = await SearchHelpers.post(
        Uri.parse(url),
        {'query': query, 'max_results': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Tavily 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = ((data['results'] as List?) ?? []).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['content'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('Tavily', query, items,
          answer: data['answer']?.toString());
    } catch (e) {
      return SearchHelpers.error('Tavily', e);
    }
  }
}
