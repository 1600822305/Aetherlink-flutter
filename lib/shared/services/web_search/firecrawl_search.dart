import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Firecrawl — web crawling + search API.
class FirecrawlSearch {
  FirecrawlSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Firecrawl');
    try {
      final baseUrl = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.firecrawl.dev/v2/search';
      final (status, body) = await SearchHelpers.post(
        Uri.parse(baseUrl),
        {'query': query, 'limit': maxResults},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Firecrawl 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final resultData =
          (data['data'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
      final webItems = (resultData['web'] as List?) ?? [];
      final newsItems = (resultData['news'] as List?) ?? [];
      final items = <Map<String, String>>[];
      for (final item in webItems.take(maxResults)) {
        final m = item as Map<String, dynamic>;
        items.add({
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['description'] ?? '').toString(),
        });
      }
      for (final item in newsItems.take(maxResults - items.length)) {
        final m = item as Map<String, dynamic>;
        items.add({
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': '${m['snippet'] ?? ''} ${m['date'] ?? ''}'.trim(),
        });
      }
      return SearchHelpers.formatResults('Firecrawl', query, items);
    } catch (e) {
      return SearchHelpers.error('Firecrawl', e);
    }
  }
}
