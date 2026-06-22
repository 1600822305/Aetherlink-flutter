import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// 智谱搜索 (Zhipu) — 智谱 AI 网络搜索服务。
class ZhipuSearch {
  ZhipuSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('智谱搜索');
    try {
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://open.bigmodel.cn/api/paas/v4/web_search'),
        {
          'search_query': query,
          'search_engine': 'search_std',
          'count': maxResults,
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('智谱搜索 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final searchResult = (data['search_result'] as List?) ?? [];
      final items = searchResult.map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['link'] ?? '').toString(),
          'text': (m['content'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('智谱搜索', query, items);
    } catch (e) {
      return SearchHelpers.error('智谱搜索', e);
    }
  }
}
