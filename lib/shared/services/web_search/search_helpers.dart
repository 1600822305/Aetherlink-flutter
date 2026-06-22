import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// Shared HTTP and formatting helpers for all search provider implementations.
class SearchHelpers {
  SearchHelpers._();

  static HttpClient client(Duration timeout) =>
      HttpClient()..connectionTimeout = timeout;

  /// GET request returning decoded UTF-8 body.
  static Future<(int statusCode, String body)> get(
    Uri uri,
    Duration timeout, {
    Map<String, String> headers = const {},
  }) async {
    final c = client(timeout);
    try {
      final request = await c.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      for (final e in headers.entries) {
        request.headers.set(e.key, e.value);
      }
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      return (response.statusCode, body);
    } finally {
      c.close();
    }
  }

  /// POST request with JSON body returning decoded UTF-8 body.
  static Future<(int statusCode, String body)> post(
    Uri uri,
    Map<String, dynamic> payload,
    Duration timeout, {
    Map<String, String> headers = const {},
  }) async {
    final c = client(timeout);
    try {
      final request = await c.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      for (final e in headers.entries) {
        request.headers.set(e.key, e.value);
      }
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      return (response.statusCode, body);
    } finally {
      c.close();
    }
  }

  /// Format a list of result maps into the Markdown format the LLM expects.
  static McpToolResult formatResults(
    String providerName,
    String query,
    List<Map<String, String>> results, {
    String? answer,
  }) {
    final buf = StringBuffer();
    buf.writeln('## $providerName 搜索结果\n');
    buf.writeln('**查询**: $query');
    buf.writeln('**结果数**: ${results.length}');
    buf.writeln('\n---\n');

    if (answer != null && answer.isNotEmpty) {
      buf.writeln('## 摘要\n');
      buf.writeln('> $answer\n');
      buf.writeln('---\n');
    }

    if (results.isEmpty) {
      buf.writeln('未找到相关结果\n');
    } else {
      for (var i = 0; i < results.length; i++) {
        final item = results[i];
        buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
        if (item['url']?.isNotEmpty == true) {
          buf.writeln('**链接**: ${item['url']}\n');
        }
        if (item['text']?.isNotEmpty == true) {
          buf.writeln('**摘要**: ${item['text']}\n');
        }
        buf.writeln('---\n');
      }
    }

    buf.write('*数据来源: $providerName*');
    return McpToolResult(buf.toString());
  }

  static McpToolResult error(String provider, Object error) =>
      McpToolResult('$provider 搜索失败: $error', isError: true);

  static McpToolResult apiKeyMissing(String provider) =>
      McpToolResult('$provider 需要 API Key，请在设置中配置', isError: true);

  /// Strips HTML tags from a string.
  static String stripHtmlTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '');
}
