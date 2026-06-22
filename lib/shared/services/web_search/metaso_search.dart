import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// 秘塔 (Metaso) — 中文 AI 搜索引擎。
class MetasoSearch {
  MetasoSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('秘塔');
    try {
      final (status, body) = await SearchHelpers.post(
        Uri.parse('https://metaso.cn/api/v1/search'),
        {
          'q': query,
          'scope': 'webpage',
          'size': maxResults,
          'includeSummary': false,
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('秘塔 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final webpages = (data['webpages'] as List?) ?? [];
      final items = webpages.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['link'] ?? '').toString(),
          'text': (m['snippet'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('秘塔 (Metaso)', query, items);
    } catch (e) {
      return SearchHelpers.error('秘塔', e);
    }
  }
}
