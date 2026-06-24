import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

/// `@aether/grok-search` tool execution (`web_search`) — uses xAI's native
/// `search_parameters` in `/v1/chat/completions` for real-time web search.
/// Docs: https://docs.x.ai/developers/rest-api-reference/inference/chat
/// and: https://docs.x.ai/developers/tools/web-search
Future<McpToolResult> runGrokSearchTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  if (toolName != 'web_search') {
    return McpToolResult('未知的工具: $toolName', isError: true);
  }

  final apiKey = env?['XAI_API_KEY'] ?? env?['AI_API_KEY'] ?? '';
  final apiUrl = env?['XAI_API_URL'] ?? env?['AI_API_URL'] ?? 'https://api.x.ai';
  final modelId = env?['XAI_MODEL_ID'] ?? env?['AI_MODEL_ID'] ?? 'grok-3';

  if (apiKey.isEmpty) {
    return const McpToolResult(
      '未配置 xAI API Key。请在 MCP 服务器环境变量中配置：\n\n'
      '  XAI_API_KEY — xAI API 密钥（https://console.x.ai 获取）\n'
      '  XAI_MODEL_ID — 模型 ID（默认 grok-3，推荐 grok-4.3）\n'
      '  XAI_API_URL — API 地址（默认 https://api.x.ai）\n\n'
      '也可使用兼容变量名：AI_API_KEY / AI_MODEL_ID / AI_API_URL',
      isError: true,
    );
  }

  final query = (args['query'] as String?)?.trim() ?? '';
  if (query.isEmpty) {
    return const McpToolResult('搜索查询内容 (query) 不能为空', isError: true);
  }

  // Build search_parameters from tool args (xAI native feature)
  final searchMode = (args['mode'] as String?) ?? 'on';
  final searchParams = <String, Object?>{
    'mode': searchMode,
    'return_citations': true,
  };
  if (args['max_search_results'] != null) {
    searchParams['max_search_results'] = asIntOr(args['max_search_results'], 10);
  }
  if (args['from_date'] is String) {
    searchParams['from_date'] = args['from_date'];
  }
  if (args['to_date'] is String) {
    searchParams['to_date'] = args['to_date'];
  }
  if (args['sources'] is List) {
    searchParams['sources'] = args['sources'];
  }

  final timeout = int.tryParse(env?['XAI_TIMEOUT'] ?? env?['AI_TIMEOUT'] ?? '60') ?? 60;

  try {
    // Build endpoint
    var endpoint = apiUrl;
    if (!endpoint.endsWith('/v1/chat/completions')) {
      if (endpoint.endsWith('/')) {
        endpoint += 'v1/chat/completions';
      } else {
        endpoint += '/v1/chat/completions';
      }
    }

    final requestBody = jsonEncode({
      'model': modelId,
      'search_parameters': searchParams,
      'messages': [
        {'role': 'user', 'content': query},
      ],
      'stream': false,
    });

    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeout);
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        final hint = switch (response.statusCode) {
          401 => '认证失败，请检查 XAI_API_KEY 是否正确',
          403 => 'API 权限不足，请确认 Key 有搜索权限',
          429 => '请求过于频繁，请稍后重试',
          _ => 'xAI API 请求失败 (HTTP ${response.statusCode})',
        };
        return McpToolResult('$hint\n\n响应: $body', isError: true);
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final choices = (data['choices'] as List?) ?? [];
      if (choices.isEmpty) {
        return const McpToolResult('xAI 未返回搜索结果', isError: true);
      }

      final firstChoice = choices[0] as Map<String, Object?>;
      final message = firstChoice['message'] as Map<String, Object?>?;
      final content = (message?['content'] as String?) ?? '';

      // Extract citations if present
      final citations = (data['citations'] as List?) ?? [];

      final buf = StringBuffer();
      buf.write(_filterThinkingContent(content));

      if (citations.isNotEmpty) {
        buf.writeln('\n\n---\n**搜索引用来源**:\n');
        for (var i = 0; i < citations.length; i++) {
          final cite = citations[i];
          if (cite is String) {
            buf.writeln('${i + 1}. $cite');
          } else if (cite is Map) {
            final title = cite['title'] ?? '来源 ${i + 1}';
            final url = cite['url'] ?? cite['link'] ?? '';
            if (url.toString().isNotEmpty) {
              buf.writeln('${i + 1}. [$title]($url)');
            } else {
              buf.writeln('${i + 1}. $title');
            }
          }
        }
      }

      final result = buf.toString().trim();
      if (result.isEmpty) {
        return const McpToolResult('xAI 搜索未返回有效内容', isError: true);
      }
      return McpToolResult(result);
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      'xAI 搜索失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      '请确认配置：\n'
      '  XAI_API_KEY — xAI API 密钥\n'
      '  XAI_MODEL_ID — 当前: $modelId\n'
      '  XAI_API_URL — 当前: $apiUrl',
      isError: true,
    );
  }
}

/// Remove <think>/<thinking> blocks from AI response.
String _filterThinkingContent(String content) {
  var result = content.replaceAll(
    RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(
    RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return result.trim();
}
