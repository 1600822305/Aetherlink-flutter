import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/citation_store.dart'
    as citation_store;
import 'package:aetherlink_flutter/shared/mcp_tools/math_expression.dart';

/// Local execution for the pure-computation built-in MCP servers — the port of
/// `CalculatorServer` / `TimeServer` (`src/shared/services/mcp/servers/`). The
/// chat tool-call loop (Phase C) routes a built-in tool call here; the settings
/// detail page only lists the catalog (`builtin_tool_catalog.dart`).
///
/// Returns `null` for servers that aren't locally runnable (external servers,
/// or `@aether/calendar` / `@aether/alarm`, which need native device plugins).
///
/// [env] is the server's configured environment (e.g. `SEARXNG_BASE_URL`).
Future<McpToolResult?> runBuiltinTool(
  String serverName,
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
  Map<String, String>? env,
}) async {
  switch (serverName) {
    case '@aether/calculator':
      return runCalculatorTool(toolName, args);
    case '@aether/time':
      return runTimeTool(toolName, args, now: now);
    case '@aether/searxng':
      return runSearxngTool(toolName, args, env: env);
  }
  return null;
}

/// `@aether/calculator` tool execution (`calculate` / `convert_base` /
/// `convert_unit` / `statistics`).
McpToolResult runCalculatorTool(String toolName, Map<String, Object?> args) {
  switch (toolName) {
    case 'calculate':
      return _calculate(args);
    case 'convert_base':
      return _convertBase(args);
    case 'convert_unit':
      return _convertUnit(args);
    case 'statistics':
      return _statistics(args);
  }
  return McpToolResult(
    _encode({'success': false, 'error': '未知的工具: $toolName'}),
    isError: true,
  );
}

/// `@aether/time` tool execution (`get_current_time`). [now] is injectable for
/// deterministic tests; it defaults to the wall clock.
McpToolResult runTimeTool(
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
}) {
  if (toolName == 'get_current_time') {
    return _getCurrentTime(args, now ?? DateTime.now());
  }
  return McpToolResult('获取时间失败: 未知的工具: $toolName');
}

// ── Calculator ──────────────────────────────────────────────────────────────

McpToolResult _calculate(Map<String, Object?> args) {
  final expression = (args['expression'] as String?)?.trim() ?? '';
  try {
    final result = evaluateMathExpression(expression);
    if (!result.isFinite) throw const FormatException('无效的数学表达式');
    return McpToolResult(
      _encode({
        'success': true,
        'expression': expression,
        'result': _normNum(result),
        'formatted': _formatNumber(result),
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({
        'success': false,
        'expression': expression,
        'error': _errMsg(error, '计算错误'),
      }),
      isError: true,
    );
  }
}

McpToolResult _convertBase(Map<String, Object?> args) {
  try {
    final value = '${args['value']}';
    final fromBase = _asInt(args['fromBase']);
    final toBase = _asInt(args['toBase']);
    const allowed = {2, 8, 10, 16};
    if (!allowed.contains(fromBase) || !allowed.contains(toBase)) {
      throw const FormatException('只支持 2, 8, 10, 16 进制');
    }
    final decimal = int.tryParse(value.trim(), radix: fromBase);
    if (decimal == null) throw const FormatException('无效的数值');
    var result = decimal.toRadixString(toBase);
    if (toBase == 16) result = result.toUpperCase();
    return McpToolResult(
      _encode({
        'success': true,
        'input': {'value': value, 'base': fromBase},
        'output': {'value': result, 'base': toBase},
        'decimal': decimal,
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({'success': false, 'error': _errMsg(error, '进制转换失败')}),
      isError: true,
    );
  }
}

McpToolResult _convertUnit(Map<String, Object?> args) {
  try {
    final value = _asDouble(args['value']);
    final category = (args['category'] as String?) ?? '';
    final fromUnit = (args['fromUnit'] as String?) ?? '';
    final toUnit = (args['toUnit'] as String?) ?? '';
    final result = switch (category) {
      'length' => _convertFactor(
        value,
        fromUnit,
        toUnit,
        _lengthToMeters,
        '长度',
      ),
      'weight' => _convertFactor(value, fromUnit, toUnit, _weightToKg, '重量'),
      'temperature' => _convertTemperature(value, fromUnit, toUnit),
      'area' => _convertFactor(value, fromUnit, toUnit, _areaToSqMeters, '面积'),
      'volume' => _convertFactor(
        value,
        fromUnit,
        toUnit,
        _volumeToLiters,
        '体积',
      ),
      _ => throw FormatException('不支持的单位类别: $category'),
    };
    return McpToolResult(
      _encode({
        'success': true,
        'input': '${_numStr(value)} $fromUnit',
        'output': '${_numStr(result)} $toUnit',
        'result': _normNum(result),
        'category': category,
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({'success': false, 'error': _errMsg(error, '单位转换失败')}),
      isError: true,
    );
  }
}

McpToolResult _statistics(Map<String, Object?> args) {
  try {
    final raw = args['numbers'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('请提供有效的数字数组');
    }
    final numbers = raw.map(_asDouble).toList();
    final n = numbers.length;
    final sorted = [...numbers]..sort();
    final sum = numbers.reduce((a, b) => a + b);
    final mean = sum / n;
    final median = n.isEven
        ? (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2
        : sorted[n ~/ 2];
    final variance =
        numbers
            .map((v) => math.pow(v - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        n;
    final stdDev = math.sqrt(variance);
    final maxV = numbers.reduce(math.max);
    final minV = numbers.reduce(math.min);
    return McpToolResult(
      _encode({
        'success': true,
        'count': n,
        'sum': _normNum(sum),
        'mean': _normNum(mean),
        'median': _normNum(median),
        'mode': _mode(numbers),
        'variance': _normNum(variance),
        'standardDeviation': _normNum(stdDev),
        'min': _normNum(minV),
        'max': _normNum(maxV),
        'range': _normNum(maxV - minV),
        'sorted': sorted.map(_normNum).toList(),
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({'success': false, 'error': _errMsg(error, '统计计算失败')}),
      isError: true,
    );
  }
}

const Map<String, double> _lengthToMeters = {
  'mm': 0.001,
  'cm': 0.01,
  'm': 1,
  'km': 1000,
  'inch': 0.0254,
  'foot': 0.3048,
  'yard': 0.9144,
  'mile': 1609.344,
};

const Map<String, double> _weightToKg = {
  'mg': 0.000001,
  'g': 0.001,
  'kg': 1,
  'ton': 1000,
  'oz': 0.0283495,
  'lb': 0.453592,
  'pound': 0.453592,
};

const Map<String, double> _areaToSqMeters = {
  'sqmm': 0.000001,
  'sqcm': 0.0001,
  'sqm': 1,
  'sqkm': 1000000,
  'sqinch': 0.00064516,
  'sqfoot': 0.092903,
  'sqyard': 0.836127,
  'acre': 4046.86,
  'hectare': 10000,
};

const Map<String, double> _volumeToLiters = {
  'ml': 0.001,
  'l': 1,
  'm3': 1000,
  'gallon': 3.78541,
  'quart': 0.946353,
  'pint': 0.473176,
  'cup': 0.236588,
  'floz': 0.0295735,
};

double _convertFactor(
  double value,
  String from,
  String to,
  Map<String, double> table,
  String label,
) {
  final f = table[from];
  final t = table[to];
  if (f == null || t == null) {
    throw FormatException('不支持的$label单位: $from 或 $to');
  }
  return value * f / t;
}

double _convertTemperature(double value, String from, String to) {
  double celsius;
  switch (from.toLowerCase()) {
    case 'celsius':
    case 'c':
      celsius = value;
    case 'fahrenheit':
    case 'f':
      celsius = (value - 32) * 5 / 9;
    case 'kelvin':
    case 'k':
      celsius = value - 273.15;
    default:
      throw FormatException('不支持的温度单位: $from');
  }
  switch (to.toLowerCase()) {
    case 'celsius':
    case 'c':
      return celsius;
    case 'fahrenheit':
    case 'f':
      return celsius * 9 / 5 + 32;
    case 'kelvin':
    case 'k':
      return celsius + 273.15;
    default:
      throw FormatException('不支持的温度单位: $to');
  }
}

Object? _mode(List<double> numbers) {
  final frequency = <double, int>{};
  var maxFreq = 0;
  double? mode;
  for (final num in numbers) {
    final freq = (frequency[num] ?? 0) + 1;
    frequency[num] = freq;
    if (freq > maxFreq) {
      maxFreq = freq;
      mode = num;
    }
  }
  return maxFreq > 1 ? _normNum(mode!) : null;
}

// ── Time ──────────────────────────────────────────────────────────────────

McpToolResult _getCurrentTime(Map<String, Object?> args, DateTime now) {
  try {
    final format = (args['format'] as String?) ?? 'locale';
    final timezone = args['timezone'] as String?;
    final local = now.toLocal();
    String timeString;
    final additional = <String, Object?>{};
    switch (format) {
      case 'iso':
        timeString = now.toUtc().toIso8601String();
      case 'timestamp':
        final ms = now.millisecondsSinceEpoch;
        timeString = ms.toString();
        additional['milliseconds'] = ms;
        additional['seconds'] = ms ~/ 1000;
      case 'locale':
      default:
        timeString = _formatLocale(local);
        if (timezone != null && timezone.isNotEmpty) {
          additional['timezone'] = timezone;
          additional['note'] = '时区转换暂未支持（需时区数据库），返回设备本地时间';
        }
    }
    return McpToolResult(
      _encode({
        'currentTime': timeString,
        'format': format,
        'year': local.year,
        'month': local.month,
        'day': local.day,
        'weekday': _weekdayCn(local.weekday),
        'hour': local.hour,
        'minute': local.minute,
        'second': local.second,
        ...additional,
      }),
    );
  } catch (error) {
    return McpToolResult('获取时间失败: ${_errMsg(error, '未知错误')}');
  }
}

String _formatLocale(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

const List<String> _weekdays = [
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

String _weekdayCn(int weekday) => _weekdays[(weekday - 1) % 7];

// ── Shared helpers ──────────────────────────────────────────────────────────

const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

String _encode(Object? value) => _jsonEncoder.convert(value);

/// Collapses integer-valued doubles to `int` so JSON renders `5`, not `5.0`
/// (matching the web's `JSON.stringify` of JS numbers).
Object _normNum(num value) {
  if (value is int) return value;
  final d = value.toDouble();
  if (d.isFinite && d == d.truncateToDouble()) return d.toInt();
  return d;
}

String _numStr(num value) {
  final normalized = _normNum(value);
  return normalized.toString();
}

/// Mirrors `CalculatorServer.formatNumber`: integers as-is, otherwise up to 10
/// decimals with trailing zeros trimmed.
String _formatNumber(double n) {
  if (!n.isFinite) return n.toString();
  if (n == n.truncateToDouble()) return n.toInt().toString();
  final trimmed = double.parse(n.toStringAsFixed(10));
  if (trimmed == trimmed.truncateToDouble()) return trimmed.toInt().toString();
  return trimmed.toString();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('无效的整数: $value');
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('无效的数值: $value');
}

String _errMsg(Object error, String fallback) {
  if (error is FormatException) {
    final message = error.message;
    if (message.isNotEmpty) return message;
  }
  return fallback;
}

// ── SearXNG ─────────────────────────────────────────────────────────────────

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
    final maxResults = _asIntOr(args['maxResults'], 10);
    final timeRange = args['timeRange'] as String?;
    final pageno = _asIntOr(args['pageno'], 1);
    final safesearch = _asIntOr(args['safesearch'], 0);

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
    final maxLength = _asIntOr(args['maxLength'], 5000);

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

      final contentType =
          response.headers.contentType?.toString() ?? '';
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
        final parsed = _extractHtmlContent(body);
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

/// Lightweight HTML-to-text extraction (port of `SearXNGServer.extractContent`).
({String title, String content}) _extractHtmlContent(String html) {
  final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
      .firstMatch(html);
  final title = titleMatch != null ? _decodeHtmlEntities(titleMatch.group(1)!.trim()) : '';

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
  content = _decodeHtmlEntities(content);

  content = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => line.length > 10 || RegExp(r'[。！？.!?]$').hasMatch(line))
      .join('\n');
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return (title: title, content: content.trim());
}

String _decodeHtmlEntities(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      );
}

int _asIntOr(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

// ---------------------------------------------------------------------------
// builtin_web_search — the high-level search tool injected when web search
// mode is active, wrapping the SearXNG backend and formatting results with
// citations.
// ---------------------------------------------------------------------------

/// Tool definition for `builtin_web_search` (injected into `tools` when
/// `InputMode.webSearch` is active). Matches the original
/// `createWebSearchToolDefinition`.
const McpToolDefinition kWebSearchToolDefinition = McpToolDefinition(
  name: 'builtin_web_search',
  description: '网络搜索工具，用于查找当前信息、新闻和实时数据。\n\n'
      '使用场景：\n'
      '- 用户询问实时信息（天气、新闻、股票等）\n'
      '- 用户询问你不确定的事实\n'
      '- 用户明确要求搜索网络\n'
      '- 需要最新数据来回答问题',
  inputSchema: {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': '搜索查询关键词',
      },
    },
    'required': ['query'],
  },
);

/// The system prompt injected when web search is enabled — instructs the model
/// to use `[citation](index:id)` inline references matching Kelivo's format.
const String kWebSearchSystemPrompt = '''

## builtin_web_search 工具使用说明

当用户询问需要实时信息或最新数据的问题时，使用 builtin_web_search 工具进行搜索。

### 引用格式
- 搜索结果中会包含 index（搜索结果序号）和 id（搜索结果唯一标识符），引用格式为：
  `具体的引用内容 [citation](index:id)`
- **引用必须紧跟在相关内容之后**，在标点符号后面，不得延后到回复结尾
- 正确格式：`... [citation](index:id)` `... [citation](index:id) [citation](index:id)`

### 使用规范
1. **使用时机**
   - 用户询问最新新闻、事件、数据
   - 需要查证事实信息
   - 需要获取技术文档、API 信息等

2. **引用要求**
   - 使用搜索结果时必须标注引用来源
   - 每个引用的事实都要紧跟 [citation](index:id) 标记
   - 不要将所有引用集中在回答末尾

3. **回答格式示例**
   ✅ 正确：
   - 据最新报道，该事件发生在昨天下午。[citation](1:a1b2c3)
   - 技术文档显示该功能需要版本3.0以上。[citation](2:d4e5f6) 具体配置步骤如下...[citation](3:g7h8i9)

   ❌ 错误：
   - 据最新报道，该事件发生在昨天下午。技术文档显示该功能需要版本3.0以上。
     [citation](1:a1b2c3) [citation](2:d4e5f6)
''';

/// System prompt appended when the model uses native/built-in web search
/// (Gemini grounding, OpenAI web_search, Claude web_search). The model
/// handles the search itself; we only need citation format instructions.
const String kNativeSearchSystemPrompt = '''

## 搜索结果引用格式

当你在回答中引用搜索结果时，请使用以下格式标注来源：
- 格式：`[citation](index:id)` 其中 index 为来源序号，id 为唯一标识
- 引用必须紧跟在相关内容之后，不得集中在回答末尾
- 如果搜索结果中包含来源链接，请确保引用对应的来源

示例：据最新数据显示，全球气温上升了1.5°C。[citation](1:src1)
''';

/// Builds provider-specific `extraBody` entries to enable native web search.
///
/// Returns entries that are spread into the request body via
/// `LlmChatRequest.extraBody`. The key `_nativeSearchTools` carries the
/// provider-specific tool configs that each adapter should merge into its
/// own `tools` array. For now, adapters that don't explicitly handle
/// `_nativeSearchTools` will simply ignore it — a per-adapter hook is the
/// phase-2 follow-up.
Map<String, dynamic>? buildNativeSearchBody({
  required String? providerType,
  required String? modelId,
  bool useResponsesAPI = false,
}) {
  switch (providerType) {
    case 'gemini':
    case 'google':
      return {
        '_nativeSearchTools': [
          {'google_search': {}},
        ],
      };

    case 'anthropic':
      return {
        '_nativeSearchTools': [
          {'type': 'web_search_20250305', 'name': 'web_search', 'max_uses': 3},
        ],
      };

    case 'openai':
    case 'openai-aisdk':
      if (useResponsesAPI) {
        return {
          '_nativeSearchTools': [
            {'type': 'web_search'},
          ],
        };
      }
      return null;

    case 'grok':
      return {
        '_nativeSearchTools': [
          {'type': 'web_search'},
        ],
      };

    default:
      return null;
  }
}

/// Executes `builtin_web_search` by delegating to the SearXNG backend and
/// formatting results with citation IDs so the model can reference them.
Future<McpToolResult> runWebSearchTool(
  Map<String, Object?> args, {
  Map<String, String>? env,
  WebSearchSettings searchSettings = const WebSearchSettings(),
}) async {
  final query = (args['query'] as String?)?.trim() ?? '';
  if (query.isEmpty) {
    return const McpToolResult('搜索关键词不能为空', isError: true);
  }

  final baseUrl = env?['SEARXNG_BASE_URL'] ?? _kDefaultSearxngUrl;

  try {
    final params = <String, String>{
      'q': query,
      'format': 'json',
      'language': 'zh-CN',
      'categories': 'general',
      'pageno': '1',
      'safesearch': '0',
    };

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);

    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: searchSettings.timeout);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '搜索请求失败 (${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final rawResults = (data['results'] as List?) ?? [];
      final results = rawResults.take(searchSettings.maxResults).toList();

      if (results.isEmpty) {
        return const McpToolResult('没有找到相关的搜索结果。');
      }

      // Build citation-compatible JSON output (matches Kelivo format).
      final items = <Map<String, Object?>>[];
      for (var i = 0; i < results.length; i++) {
        final item = results[i];
        if (item is! Map) continue;
        final id = _shortId();
        final url = (item['url'] ?? '').toString();
        items.add({
          'index': i + 1,
          'id': id,
          'title': item['title'] ?? '无标题',
          'url': url,
          'text': item['content'] ?? '',
        });
        if (url.isNotEmpty) {
          citation_store.storeCitation(id, url);
        }
      }

      final resultJson = jsonEncode({'items': items});

      return McpToolResult(
        '搜索查询: "$query"\n'
        '找到 ${items.length} 个相关结果。\n\n'
        '请使用 [citation](index:id) 格式引用具体信息。\n\n'
        '搜索结果:\n```json\n$resultJson\n```',
      );
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '搜索失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

/// Generates a short 6-character hex ID for citation references.
String _shortId() {
  final r = math.Random();
  return List.generate(6, (_) => r.nextInt(16).toRadixString(16)).join();
}
