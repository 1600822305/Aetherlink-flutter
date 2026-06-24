import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

/// `@aether/metaso-search` tool execution — uses the official Metaso API
/// (metaso.cn/api/v1/*). Docs: https://metaso.cn/search-api/playground
Future<McpToolResult> runMetasoTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  final apiKey = env?['METASO_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    return const McpToolResult(
      '未配置 METASO_API_KEY 环境变量。\n\n'
      '获取方法：\n'
      '1. 访问 https://metaso.cn/search-api/api-keys\n'
      '2. 登录并创建 API Key（格式 mk-xxxx）\n'
      '3. 在 MCP 服务器环境变量中设置 METASO_API_KEY\n\n'
      '定价：0.03元/次查询',
      isError: true,
    );
  }
  switch (toolName) {
    case 'metaso_search':
      return _metasoSearch(args, apiKey);
    case 'metaso_reader':
      return _metasoReader(args, apiKey);
    case 'metaso_chat':
      return _metasoChat(args, apiKey);
  }
  return McpToolResult('未知的工具: $toolName', isError: true);
}

Future<McpToolResult> _metasoSearch(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final query = (args['q'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('搜索关键词 (q) 不能为空', isError: true);
    }
    final scope = (args['scope'] as String?) ?? 'webpage';
    final size = asIntOr(args['size'], 10);
    final page = asIntOr(args['page'], 1);
    final includeSummary = args['includeSummary'] == true;
    final includeRawContent = args['includeRawContent'] == true;
    final conciseSnippet = args['conciseSnippet'] == true;

    final requestBody = jsonEncode({
      'q': query,
      'scope': scope,
      'size': size,
      'page': page,
      'includeSummary': includeSummary,
      'includeRawContent': includeRawContent,
      'conciseSnippet': conciseSnippet,
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/search'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔搜索请求失败 (HTTP ${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final webpages = (data['webpages'] as List?) ?? [];
      final total = data['total'] ?? webpages.length;
      final credits = data['credits'];

      final buf = StringBuffer();
      buf.writeln('## 秘塔AI搜索结果\n');
      buf.writeln('**查询**: $query');
      buf.writeln('**范围**: $scope | **页码**: $page');
      buf.writeln('**结果数**: ${webpages.length} / $total');
      if (credits != null) buf.writeln('**积分消耗**: $credits');
      buf.writeln('\n---\n');

      if (webpages.isNotEmpty) {
        for (var i = 0; i < webpages.length; i++) {
          final item = webpages[i];
          if (item is! Map) continue;
          buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
          if (item['link'] != null) buf.writeln('**链接**: ${item['link']}');
          if (item['snippet'] != null) buf.writeln('**摘要**: ${item['snippet']}');
          if (item['summary'] != null) buf.writeln('**AI摘要**: ${item['summary']}');
          if (includeRawContent && item['rawContent'] != null) {
            final rawContent = '${item['rawContent']}';
            final truncated = rawContent.length > 500
                ? '${rawContent.substring(0, 500)}...'
                : rawContent;
            buf.writeln('**原文**: $truncated');
          }
          if (item['score'] != null) buf.writeln('**相关度**: ${item['score']}');
          if (item['date'] != null) buf.writeln('**日期**: ${item['date']}');
          if (item['authors'] is List && (item['authors'] as List).isNotEmpty) {
            buf.writeln('**作者**: ${(item['authors'] as List).join(', ')}');
          }
          buf.writeln('\n---\n');
        }
      } else {
        buf.writeln('未找到相关结果\n');
      }

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔AI搜索失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

Future<McpToolResult> _metasoReader(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final format = (args['format'] as String?) ?? 'markdown';

    final requestBody = jsonEncode({
      'url': url,
      'format': format,
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/reader'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', format == 'markdown' ? 'text/markdown' : 'text/plain')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔阅读器请求失败 (HTTP ${response.statusCode}): $body',
          isError: true,
        );
      }

      return McpToolResult(body);
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔阅读器失败: ${error is Exception ? error.toString() : '未知错误'}\n'
      'URL: ${args['url']}',
      isError: true,
    );
  }
}

Future<McpToolResult> _metasoChat(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final query = (args['q'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('查询问题 (q) 不能为空', isError: true);
    }
    final scope = (args['scope'] as String?) ?? 'webpage';
    final model = (args['model'] as String?) ?? 'fast';
    final conciseSnippet = args['conciseSnippet'] == true;

    final requestBody = jsonEncode({
      'model': model,
      'scope': scope,
      'stream': false,
      'format': 'chat_completions',
      'conciseSnippet': conciseSnippet,
      'messages': [
        {'role': 'user', 'content': query},
      ],
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 60);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/chat/completions'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔问答请求失败 (HTTP ${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final choices = (data['choices'] as List?) ?? [];
      if (choices.isEmpty) {
        return const McpToolResult('秘塔问答未返回结果', isError: true);
      }
      final firstChoice = choices[0] as Map<String, Object?>;
      final message = firstChoice['message'] as Map<String, Object?>?;
      final answer = (message?['content'] as String?) ?? '';
      final citations = (data['citations'] as List?) ?? [];

      final buf = StringBuffer();
      buf.writeln(answer);

      if (citations.isNotEmpty) {
        buf.writeln('\n\n---\n**引用来源**:\n');
        for (var i = 0; i < citations.length; i++) {
          final cite = citations[i];
          if (cite is! Map) continue;
          final title = cite['title'] ?? '来源 ${i + 1}';
          final link = cite['link'] ?? '';
          if (link.toString().isNotEmpty) {
            buf.writeln('${i + 1}. [$title]($link)');
          } else {
            buf.writeln('${i + 1}. $title');
          }
        }
      }

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔问答失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}
