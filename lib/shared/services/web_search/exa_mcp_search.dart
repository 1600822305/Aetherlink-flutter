import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/services/web_search/search_helpers.dart';

/// Exa MCP — 通过 Exa 官方 MCP 端点（https://mcp.exa.ai/mcp）搜索，
/// 走 JSON-RPC `tools/call` 调用 `web_search_exa` 工具，响应为 SSE 或
/// 直接 JSON。无需 API Key 即可使用公共端点；配置了 Key 时按官方约定
/// 以 `exaApiKey` 查询参数携带以获得更高配额。
class ExaMcpSearch {
  ExaMcpSearch._();

  static const _defaultHost = 'https://mcp.exa.ai/mcp';

  static Future<McpToolResult> search(
    SearchProviderConfig config,
    String query,
    int maxResults,
    Duration timeout,
  ) async {
    try {
      var uri = Uri.parse(
        config.apiHost.isNotEmpty ? config.apiHost : _defaultHost,
      );
      final apiKey = config.apiKey.trim();
      if (apiKey.isNotEmpty) {
        uri = uri.replace(
          queryParameters: {...uri.queryParameters, 'exaApiKey': apiKey},
        );
      }
      final (status, body) = await SearchHelpers.post(
        uri,
        {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {
            'name': 'web_search_exa',
            'arguments': {
              'query': query,
              'type': 'auto',
              'numResults': maxResults,
              'livecrawl': 'fallback',
            },
          },
        },
        timeout,
        headers: {'Accept': 'application/json, text/event-stream'},
      );
      if (status != 200) {
        return McpToolResult('Exa MCP 请求失败 ($status): $body', isError: true);
      }
      final items = _parseResponse(body);
      return SearchHelpers.formatResults(
        'Exa MCP',
        query,
        items.take(maxResults).toList(),
      );
    } catch (e) {
      return SearchHelpers.error('Exa MCP', e);
    }
  }

  /// Parses the MCP response body — SSE (`data: {...}` lines) or plain
  /// JSON-RPC — into result maps for [SearchHelpers.formatResults].
  static List<Map<String, String>> _parseResponse(String body) {
    final payloadTexts = <String>[];

    for (final line in body.split('\n')) {
      if (!line.startsWith('data: ')) continue;
      final payload = line.substring(6).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      final text = _extractContentText(payload);
      if (text != null) payloadTexts.add(text);
    }

    if (payloadTexts.isEmpty) {
      final direct = _extractContentText(body);
      if (direct != null) payloadTexts.add(direct);
    }

    if (payloadTexts.isEmpty && body.contains('Title:')) {
      payloadTexts.add(body);
    }

    return _parseTextChunks(payloadTexts.join('\n\n'));
  }

  /// Extracts the joined `result.content[].text` of a JSON-RPC payload.
  static String? _extractContentText(String payload) {
    try {
      final parsed = jsonDecode(payload);
      if (parsed is! Map<String, dynamic>) return null;
      final result = parsed['result'];
      if (result is! Map<String, dynamic>) return null;
      final content = result['content'];
      if (content is! List) return null;
      final text = content
          .whereType<Map<String, dynamic>>()
          .map((item) => (item['text'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty)
          .join('\n\n');
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Splits the `Title:` / `URL:` / `Text:`(或 `Highlights:`) chunked
  /// plain-text format Exa MCP returns into individual results.
  static List<Map<String, String>> _parseTextChunks(String raw) {
    final items = <Map<String, String>>[];
    for (final chunk in raw.split('\n\n')) {
      final lines = chunk.split('\n');
      var title = '';
      var url = '';
      var text = '';
      var textStartIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('Title:')) {
          title = line.substring(6).trim();
        } else if (line.startsWith('URL:')) {
          url = line.substring(4).trim();
        } else if (line.startsWith('Text:') && textStartIndex == -1) {
          textStartIndex = i;
          text = line.substring(5).trim();
        } else if (line.startsWith('Highlights:') && textStartIndex == -1) {
          textStartIndex = i;
          text = line.substring(11).trim();
        }
      }
      if (textStartIndex != -1) {
        final rest = lines.sublist(textStartIndex + 1).join('\n').trim();
        if (rest.isNotEmpty) {
          text = text.isEmpty ? rest : '$text\n$rest';
        }
      }
      if (title.isNotEmpty || url.isNotEmpty || text.isNotEmpty) {
        items.add({'title': title, 'url': url, 'text': text});
      }
    }
    return items;
  }
}
