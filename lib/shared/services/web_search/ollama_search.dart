import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Ollama — Ollama web search API.
class OllamaSearch {
  OllamaSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Ollama');
    try {
      final baseUrl = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://ollama.com/api/web_search';
      final (status, body) = await SearchHelpers.post(
        Uri.parse(baseUrl),
        {'query': query, 'max_results': maxResults.clamp(5, 10)},
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Ollama 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      final items = results.take(maxResults).map((item) {
        final m = item as Map<String, dynamic>;
        return {
          'title': (m['title'] ?? '').toString(),
          'url': (m['url'] ?? '').toString(),
          'text': (m['content'] ?? '').toString(),
        };
      }).toList();
      return SearchHelpers.formatResults('Ollama', query, items);
    } catch (e) {
      return SearchHelpers.error('Ollama', e);
    }
  }
}
