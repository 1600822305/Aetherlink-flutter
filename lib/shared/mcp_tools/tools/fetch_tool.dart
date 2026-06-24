import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

/// `@aether/fetch` tool execution — follows the official MCP fetch server
/// pattern (modelcontextprotocol/servers). Single `fetch` tool that retrieves
/// URL content and converts HTML to Markdown for LLM consumption.
/// Supports chunked reading via `start_index` for large pages.
Future<McpToolResult> runFetchTool(
  String toolName,
  Map<String, Object?> args,
) async {
  if (toolName != 'fetch') {
    return McpToolResult('未知的工具: $toolName', isError: true);
  }
  return _fetchAndConvert(args);
}

Future<McpToolResult> _fetchAndConvert(Map<String, Object?> args) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final maxLength = asIntOr(args['max_length'], 5000);
    final startIndex = asIntOr(args['start_index'], 0);
    final raw = args['raw'] == true;
    final customHeaders = args['headers'];
    final headers = <String, String>{};
    if (customHeaders is Map) {
      for (final entry in customHeaders.entries) {
        headers['${entry.key}'] = '${entry.value}';
      }
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set('User-Agent',
            'ModelContextProtocol/1.0 (Fetch Tool; AetherLink)')
        ..set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        ..set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '获取 URL 失败: HTTP ${response.statusCode}\nURL: $url',
          isError: true,
        );
      }

      final contentType = response.headers.contentType?.toString() ?? '';
      String content;

      if (raw) {
        content = body;
      } else if (contentType.contains('json')) {
        try {
          final parsed = jsonDecode(body);
          content = const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (_) {
          content = body;
        }
      } else if (contentType.contains('html') || body.trimLeft().startsWith('<')) {
        content = htmlToMarkdown(body);
      } else {
        content = body;
      }

      final totalLength = content.length;
      if (startIndex >= totalLength) {
        return McpToolResult(
          'start_index ($startIndex) 超出内容长度 ($totalLength)\n'
          'URL: $url',
          isError: true,
        );
      }

      final endIndex = (startIndex + maxLength).clamp(0, totalLength);
      final slice = content.substring(startIndex, endIndex);
      final hasMore = endIndex < totalLength;

      final buf = StringBuffer(slice);
      if (hasMore) {
        buf.writeln();
        buf.writeln();
        buf.writeln('<content_truncated>');
        buf.writeln('已返回字符 $startIndex-$endIndex / 共 $totalLength 字符。');
        buf.write('如需继续阅读，请使用 start_index=$endIndex 再次调用。');
        buf.writeln('</content_truncated>');
      }

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '获取 URL 失败: ${error is Exception ? error.toString() : '未知错误'}\n'
      'URL: ${args['url']}',
      isError: true,
    );
  }
}

/// Convert HTML to simplified Markdown — a lightweight port of the
/// readability + markdownify approach used by the official MCP fetch server.
String htmlToMarkdown(String html) {
  final titleMatch = RegExp(
    r'<title[^>]*>([\s\S]*?)</title>',
    caseSensitive: false,
  ).firstMatch(html);
  final title = titleMatch != null
      ? decodeHtmlEntities(titleMatch.group(1)!.trim())
      : '';

  var content = html;
  // Remove non-content elements
  content = content.replaceAll(
    RegExp(
      r'<(script|style|nav|header|footer|aside|iframe|noscript|svg)[^>]*>[\s\S]*?</\1>',
      caseSensitive: false,
    ),
    '',
  );
  content = content.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

  // Convert heading tags to Markdown
  content = content.replaceAllMapped(
    RegExp(r'<h([1-6])[^>]*>([\s\S]*?)</h\1>', caseSensitive: false),
    (m) {
      final level = int.parse(m.group(1)!);
      final text = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      return '\n${'#' * level} $text\n';
    },
  );

  // Convert links to Markdown
  content = content.replaceAllMapped(
    RegExp(r'<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>', caseSensitive: false),
    (m) {
      final href = m.group(1)!;
      final text = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (text.isEmpty) return '';
      return '[$text]($href)';
    },
  );

  // Convert images to Markdown
  content = content.replaceAllMapped(
    RegExp(r'<img[^>]*src="([^"]*)"[^>]*/?>', caseSensitive: false),
    (m) {
      final src = m.group(1)!;
      final altMatch = RegExp(r'alt="([^"]*)"').firstMatch(m.group(0)!);
      final alt = altMatch?.group(1) ?? '';
      return '![${alt.isEmpty ? 'image' : alt}]($src)';
    },
  );

  // Convert list items
  content = content.replaceAllMapped(
    RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false),
    (m) => '\n- ${m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}',
  );

  // Convert <br> to newline
  content = content.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );

  // Convert <p> to paragraphs
  content = content.replaceAllMapped(
    RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false),
    (m) => '\n\n${m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}\n',
  );

  // Convert bold/strong
  content = content.replaceAllMapped(
    RegExp(r'<(strong|b)[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '**${m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}**',
  );

  // Convert italic/em
  content = content.replaceAllMapped(
    RegExp(r'<(em|i)[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '*${m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}*',
  );

  // Convert code blocks
  content = content.replaceAllMapped(
    RegExp(r'<pre[^>]*><code[^>]*>([\s\S]*?)</code></pre>', caseSensitive: false),
    (m) => '\n```\n${decodeHtmlEntities(m.group(1)!)}\n```\n',
  );
  content = content.replaceAllMapped(
    RegExp(r'<code[^>]*>([\s\S]*?)</code>', caseSensitive: false),
    (m) => '`${decodeHtmlEntities(m.group(1)!)}`',
  );

  // Strip remaining tags
  content = content.replaceAll(RegExp(r'<[^>]+>'), '');
  content = decodeHtmlEntities(content);

  // Clean up whitespace
  content = content
      .split('\n')
      .map((line) => line.trim())
      .join('\n');
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  final buf = StringBuffer();
  if (title.isNotEmpty) buf.writeln('# $title\n');
  buf.write(content.trim());
  return buf.toString();
}
