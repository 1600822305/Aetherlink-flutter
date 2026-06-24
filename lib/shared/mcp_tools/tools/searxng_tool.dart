import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

const String _kDefaultSearxngUrl = 'http://154.37.208.52:39281';

/// `@aether/searxng` tool execution (`searxng_search` / `searxng_read_url`).
Future<McpToolResult> runSearxngTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  final baseUrl = env?['SEARXNG_BASE_URL'] ?? _kDefaultSearxngUrl;
  switch (toolName) {
    case 'searxng_search':
      return _searxngSearch(args, baseUrl);
    case 'searxng_read_url':
      return _searxngReadUrl(args);
  }
  return McpToolResult('未知的工具: $toolName', isError: true);
}

Future<McpToolResult> _searxngSearch(
  Map<String, Object?> args,
  String baseUrl,
) async {
  try {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('搜索关键词不能为空', isError: true);
    }
    final engines = args['engines'] as String?;
    final language = (args['language'] as String?) ?? 'zh-CN';
    final categories = (args['categories'] as String?) ?? 'general';
    final maxResults = asIntOr(args['maxResults'], 10);
    final timeRange = args['timeRange'] as String?;
    final pageno = asIntOr(args['pageno'], 1);
    final safesearch = asIntOr(args['safesearch'], 0);

    final params = <String, String>{
      'q': query,
      'format': 'json',
      'language': language,
      'categories': categories,
      'pageno': '$pageno',
      'safesearch': '$safesearch',
    };
    if (engines != null && engines.isNotEmpty) params['engines'] = engines;
    if (timeRange != null && timeRange.isNotEmpty) {
      params['time_range'] = timeRange;
    }

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          'SearXNG 搜索请求失败 (${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final rawResults = (data['results'] as List?) ?? [];
      final results = rawResults.take(maxResults).toList();
      final totalResults = data['number_of_results'] ?? results.length;
      final suggestions = (data['suggestions'] as List?)?.cast<String>() ?? [];
      final answers = (data['answers'] as List?)?.cast<String>() ?? [];
      final corrections = (data['corrections'] as List?)?.cast<String>() ?? [];
      final infoboxes = (data['infoboxes'] as List?) ?? [];

      final buf = StringBuffer();
      buf.writeln('## SearXNG 搜索结果\n');
      buf.writeln('**查询**: $query');
      buf.writeln('**结果数**: ${results.length} / $totalResults');
      buf.writeln('**页码**: $pageno');
      if (engines != null) buf.writeln('**引擎**: $engines');
      if (timeRange != null && timeRange.isNotEmpty) {
        buf.writeln('**时间范围**: $timeRange');
      }
      buf.writeln('\n---\n');

      if (answers.isNotEmpty) {
        buf.writeln('## 直接答案\n');
        for (final answer in answers) {
          buf.writeln('> $answer\n');
        }
        buf.writeln('---\n');
      }

      if (corrections.isNotEmpty) {
        buf.writeln('**拼写建议**: ${corrections.join(', ')}\n');
      }

      for (final box in infoboxes) {
        if (box is! Map) continue;
        buf.writeln('## ${box['infobox'] ?? '信息卡片'}\n');
        if (box['content'] != null) buf.writeln('${box['content']}\n');
        final urls = box['urls'];
        if (urls is List && urls.isNotEmpty) {
          buf.writeln('**相关链接**:');
          for (final u in urls) {
            if (u is Map) {
              buf.writeln('- [${u['title'] ?? u['url']}](${u['url']})');
            }
          }
          buf.writeln();
        }
        final attrs = box['attributes'];
        if (attrs is List && attrs.isNotEmpty) {
          for (final attr in attrs) {
            if (attr is Map) {
              buf.writeln('- **${attr['label']}**: ${attr['value']}');
            }
          }
          buf.writeln();
        }
        buf.writeln('---\n');
      }

      if (results.isNotEmpty) {
        for (var i = 0; i < results.length; i++) {
          final item = results[i];
          if (item is! Map) continue;
          buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
          if (item['url'] != null) buf.writeln('**链接**: ${item['url']}\n');
          if (item['content'] != null) {
            buf.writeln('**摘要**: ${item['content']}\n');
          }
          if (item['engine'] != null) {
            buf.writeln('**来源引擎**: ${item['engine']}');
          }
          if (item['score'] != null) {
            final score = (item['score'] as num).toDouble() * 100;
            buf.writeln('**相关度**: ${score.toStringAsFixed(1)}%');
          }
          if (item['publishedDate'] != null) {
            buf.writeln('**发布时间**: ${item['publishedDate']}');
          }
          buf.writeln('\n---\n');
        }
      } else {
        buf.writeln('未找到相关结果\n');
      }

      if (suggestions.isNotEmpty) {
        buf.writeln('## 相关搜索建议\n');
        for (final s in suggestions) {
          buf.writeln('- $s');
        }
        buf.writeln();
      }

      buf.write('*数据来源: SearXNG 元搜索引擎*');

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      'SearXNG 搜索失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      '请检查 SearXNG 服务是否正常运行。',
      isError: true,
    );
  }
}

Future<McpToolResult> _searxngReadUrl(Map<String, Object?> args) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final maxLength = asIntOr(args['maxLength'], 5000);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        ..set('User-Agent',
            'Mozilla/5.0 (compatible; AetherLink/1.0; +https://aetherlink.app)')
        ..set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          'HTTP 请求失败 (${response.statusCode}): ${response.reasonPhrase}',
          isError: true,
        );
      }

      final contentType = response.headers.contentType?.toString() ?? '';
      String extracted;
      String title = '';

      if (contentType.contains('json')) {
        try {
          final json = jsonDecode(body);
          extracted = const JsonEncoder.withIndent('  ').convert(json);
        } catch (_) {
          extracted = body;
        }
      } else if (contentType.contains('html')) {
        final parsed = extractHtmlContent(body);
        title = parsed.title;
        extracted = parsed.content;
      } else {
        extracted = body;
      }

      if (extracted.length > maxLength) {
        extracted = '${extracted.substring(0, maxLength)}\n\n...(内容已截断)';
      }

      final buf = StringBuffer();
      buf.writeln('## 网页内容\n');
      buf.writeln('**URL**: $url');
      if (title.isNotEmpty) buf.writeln('**标题**: $title');
      buf.writeln('**内容长度**: ${extracted.length} 字符');
      buf.writeln('\n---\n');
      buf.write(extracted);

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '网页抓取失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      'URL: ${args['url']}',
      isError: true,
    );
  }
}

/// Lightweight HTML-to-text extraction for SearXNG read_url.
({String title, String content}) extractHtmlContent(String html) {
  final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
      .firstMatch(html);
  final title = titleMatch != null
      ? decodeHtmlEntities(titleMatch.group(1)!.trim())
      : '';

  var content = html;
  content = content.replaceAll(
    RegExp(
      r'<(script|style|nav|header|footer|aside|iframe|noscript|svg)[^>]*>[\s\S]*?</\1>',
      caseSensitive: false,
    ),
    '',
  );
  content = content.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  content = content.replaceAll(RegExp(r'<[^>]+>'), '\n');
  content = decodeHtmlEntities(content);

  content = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => line.length > 10 || RegExp(r'[。！？.!?]$').hasMatch(line))
      .join('\n');
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return (title: title, content: content.trim());
}
