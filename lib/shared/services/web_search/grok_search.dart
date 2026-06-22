import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Grok — xAI Responses API with web_search tool。
class GrokSearch {
  GrokSearch._();

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    if (config.apiKey.isEmpty) return SearchHelpers.apiKeyMissing('Grok');
    try {
      final url = config.apiHost.isNotEmpty
          ? config.apiHost
          : 'https://api.x.ai/v1/responses';
      final (status, body) = await SearchHelpers.post(
        Uri.parse(url),
        {
          'model': 'grok-3-mini',
          'input': [
            {
              'role': 'system',
              'content':
                  'You are a search assistant. Answer the user query using web search. Be concise.',
            },
            {'role': 'user', 'content': query},
          ],
          'tools': [
            {'type': 'web_search'},
          ],
          'store': false,
          'stream': false,
        },
        timeout,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      );
      if (status != 200) {
        return McpToolResult('Grok 请求失败 ($status): $body', isError: true);
      }
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Extract text answer from output
      final output = (data['output'] as List?) ?? [];
      String? answer;
      for (final item in output) {
        if (item is Map &&
            item['type'] == 'message' &&
            item['role'] == 'assistant') {
          final content = (item['content'] as List?) ?? [];
          for (final c in content) {
            if (c is Map && c['type'] == 'output_text') {
              answer = c['text']?.toString();
              break;
            }
          }
        }
      }

      // Extract citations as search results
      final items = <Map<String, String>>[];
      final seenUrls = <String>{};
      void addCitations(Object? citations) {
        final citationList = (citations as List?) ?? [];
        for (final citation in citationList) {
          if (items.length >= maxResults) return;
          if (citation is String) {
            final url = citation.trim();
            if (url.isNotEmpty && seenUrls.add(url)) {
              items.add({'title': url, 'url': url, 'text': ''});
            }
          } else if (citation is Map && citation['type'] == 'url_citation') {
            final url = citation['url']?.toString().trim() ?? '';
            if (url.isNotEmpty && seenUrls.add(url)) {
              items.add({
                'title': citation['title']?.toString() ?? url,
                'url': url,
                'text': '',
              });
            }
          }
        }
      }

      addCitations(data['citations']);
      for (final item in output) {
        if (item is Map && item['type'] == 'message') {
          for (final c in ((item['content'] as List?) ?? [])) {
            if (c is Map) addCitations(c['annotations']);
          }
        }
      }

      return SearchHelpers.formatResults('Grok', query, items, answer: answer);
    } catch (e) {
      return SearchHelpers.error('Grok', e);
    }
  }
}
