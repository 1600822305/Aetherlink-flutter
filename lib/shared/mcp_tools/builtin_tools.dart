import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
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
    case '@aether/fetch':
      return runFetchTool(toolName, args);
    case '@aether/metaso-search':
      return runMetasoTool(toolName, args, env: env);
    case '@aether/grok-search':
      return runGrokSearchTool(toolName, args, env: env);
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

// ── Fetch ───────────────────────────────────────────────────────────────────

/// `@aether/fetch` tool execution (`fetch_url_as_html` / `fetch_url_as_json` /
/// `fetch_url_as_text`).
Future<McpToolResult> runFetchTool(
  String toolName,
  Map<String, Object?> args,
) async {
  switch (toolName) {
    case 'fetch_url_as_html':
      return _fetchUrl(args, _FetchMode.html);
    case 'fetch_url_as_json':
      return _fetchUrl(args, _FetchMode.json);
    case 'fetch_url_as_text':
      return _fetchUrl(args, _FetchMode.text);
  }
  return McpToolResult('未知的工具: $toolName', isError: true);
}

enum _FetchMode { html, json, text }

Future<McpToolResult> _fetchUrl(
  Map<String, Object?> args,
  _FetchMode mode,
) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final customHeaders = args['headers'];
    final headers = <String, String>{};
    if (customHeaders is Map) {
      for (final entry in customHeaders.entries) {
        headers['${entry.key}'] = '${entry.value}';
      }
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set('User-Agent',
            'Mozilla/5.0 (compatible; AetherLink/1.0; +https://aetherlink.app)')
        ..set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          'HTTP 错误: ${response.statusCode} ${response.reasonPhrase}',
          isError: true,
        );
      }

      switch (mode) {
        case _FetchMode.html:
          return McpToolResult(body);
        case _FetchMode.json:
          try {
            final parsed = jsonDecode(body);
            return McpToolResult(
              const JsonEncoder.withIndent('  ').convert(parsed),
            );
          } catch (e) {
            return McpToolResult(
              '解析 JSON 失败: $e',
              isError: true,
            );
          }
        case _FetchMode.text:
          final extracted = _extractHtmlContent(body);
          final buf = StringBuffer();
          if (extracted.title.isNotEmpty) {
            buf.writeln('# ${extracted.title}\n');
          }
          buf.write(extracted.content);
          return McpToolResult(buf.toString());
      }
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '获取 ${args['url']} 失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

// ── Metaso Search ───────────────────────────────────────────────────────────

/// `@aether/metaso-search` tool execution (`metaso_search` / `metaso_reader` /
/// `metaso_chat`).
Future<McpToolResult> runMetasoTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  final apiKey = env?['METASO_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    return const McpToolResult(
      '未配置秘塔AI搜索 API Key。\n\n'
      '配置方法：\n'
      '1. 访问秘塔AI开放平台: https://metaso.cn/open-app\n'
      '2. 登录并申请 API Key\n'
      '3. 在 MCP 服务器环境变量中设置 METASO_API_KEY',
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
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('搜索关键词不能为空', isError: true);
    }
    final scope = (args['scope'] as String?) ?? 'webpage';
    final size = _asIntOr(args['size'], 10);
    final includeRawContent = args['includeRawContent'] == true;

    final requestBody = jsonEncode({
      'q': query,
      'scope': scope,
      'includeSummary': false,
      'size': '$size',
      'includeRawContent': includeRawContent,
      'conciseSnippet': false,
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
          '秘塔AI搜索请求失败 (${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final webpages = (data['webpages'] as List?) ?? [];
      final total = data['total'] ?? webpages.length;

      final buf = StringBuffer();
      buf.writeln('## 秘塔AI搜索结果\n');
      buf.writeln('**查询**: $query');
      buf.writeln('**范围**: $scope');
      buf.writeln('**返回结果数**: ${webpages.length} / $total');
      if (data['credits'] != null) {
        buf.writeln('**消耗积分**: ${data['credits']}');
      }
      buf.writeln('\n---\n');

      if (webpages.isNotEmpty) {
        for (var i = 0; i < webpages.length; i++) {
          final item = webpages[i];
          if (item is! Map) continue;
          buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
          if (item['link'] != null) buf.writeln('**链接**: ${item['link']}\n');
          if (item['snippet'] != null) {
            buf.writeln('**摘要**: ${item['snippet']}\n');
          }
          if (includeRawContent && item['rawContent'] != null) {
            buf.writeln('**原文**:\n```\n${item['rawContent']}\n```\n');
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

      buf.write('*数据来源: 秘塔AI搜索 (metaso.cn)*');
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

    final requestBody = jsonEncode({'url': url});

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/reader'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', 'text/plain')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔AI阅读器请求失败 (${response.statusCode}): $body',
          isError: true,
        );
      }

      final buf = StringBuffer();
      buf.writeln('## 秘塔AI阅读器结果\n');
      buf.writeln('**源URL**: $url\n');
      buf.writeln('---\n');
      buf.writeln(body);
      buf.writeln('\n---\n');
      buf.write('*数据来源: 秘塔AI阅读器 (metaso.cn)*');
      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔AI阅读器失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

Future<McpToolResult> _metasoChat(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('查询内容不能为空', isError: true);
    }
    final scope = (args['scope'] as String?) ?? 'webpage';
    final model = (args['model'] as String?) ?? 'fast';

    final requestBody = jsonEncode({
      'model': model,
      'scope': scope,
      'stream': false,
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
          '秘塔AI对话请求失败 (${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final choices = (data['choices'] as List?) ?? [];
      final message = choices.isNotEmpty
          ? (choices[0] as Map<String, Object?>)['message'] as Map<String, Object?>?
          : null;
      final answer = (message?['content'] as String?) ?? '未获取到回答';
      final citations = (message?['citations'] as List?) ?? [];

      final buf = StringBuffer();
      buf.writeln('## 秘塔AI智能回答\n');
      buf.writeln('**问题**: $query');
      buf.writeln('**模型**: $model');
      buf.writeln('**知识范围**: $scope\n');
      buf.writeln('---\n');
      buf.writeln(answer);
      buf.writeln();

      if (citations.isNotEmpty) {
        buf.writeln('\n## 引用来源\n');
        for (var i = 0; i < citations.length; i++) {
          final cite = citations[i];
          if (cite is! Map) continue;
          buf.writeln('${i + 1}. **${cite['title'] ?? '未知标题'}**');
          if (cite['link'] != null) buf.writeln('   链接: ${cite['link']}');
          if (cite['date'] != null) buf.writeln('   日期: ${cite['date']}');
          if (cite['authors'] is List &&
              (cite['authors'] as List).isNotEmpty) {
            buf.writeln('   作者: ${(cite['authors'] as List).join(', ')}');
          }
          buf.writeln();
        }
      }

      buf.write('*数据来源: 秘塔AI (metaso.cn)*');
      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔AI对话失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

// ── Grok Search (AI联网搜索) ────────────────────────────────────────────────

/// Default system prompt for AI search.
const String _kGrokSearchSystemPrompt = '''你是一个专业的搜索助手,擅长联网搜索并提供准确、详细的答案。

当前时间: {current_time}

搜索策略:
1. 优先使用最新、权威的信息源
2. 对于时间敏感的查询,明确标注信息的时间
3. 提供多个来源的信息进行交叉验证
4. 对于技术问题,优先参考官方文档和最新版本

输出要求:
- 直接回答用户问题
- 时间相关信息必须基于上述当前时间判断''';

/// `@aether/grok-search` tool execution (`web_search`) — calls any
/// OpenAI-compatible API with web search capability (e.g. Grok, Perplexity).
Future<McpToolResult> runGrokSearchTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  if (toolName != 'web_search') {
    return McpToolResult('未知的工具: $toolName', isError: true);
  }
  final apiUrl = env?['AI_API_URL'] ?? '';
  final apiKey = env?['AI_API_KEY'] ?? '';
  final modelId = env?['AI_MODEL_ID'] ?? '';

  if (apiUrl.isEmpty || apiKey.isEmpty || modelId.isEmpty) {
    return const McpToolResult(
      '未完整配置 AI Search。请在 MCP 服务器环境变量中配置：\n'
      '  AI_API_URL — API 地址（如 https://api.x.ai/v1）\n'
      '  AI_API_KEY — API 密钥\n'
      '  AI_MODEL_ID — 搜索模型 ID（如 grok-3）',
      isError: true,
    );
  }

  final query = (args['query'] as String?)?.trim() ?? '';
  if (query.isEmpty) {
    return const McpToolResult('搜索查询内容不能为空', isError: true);
  }

  final timeout = int.tryParse(env?['AI_TIMEOUT'] ?? '60') ?? 60;
  final filterThinking =
      (env?['AI_FILTER_THINKING'] ?? 'true').toLowerCase() == 'true';
  final retryCount = int.tryParse(env?['AI_RETRY_COUNT'] ?? '1') ?? 1;
  final maxQueryPlan = int.tryParse(env?['AI_MAX_QUERY_PLAN'] ?? '1') ?? 1;
  final systemPromptTemplate =
      env?['AI_SYSTEM_PROMPT']?.isNotEmpty == true
          ? env!['AI_SYSTEM_PROMPT']!
          : _kGrokSearchSystemPrompt;

  try {
    String result;
    if (maxQueryPlan > 1) {
      result = await _grokMultiSearch(
        query: query,
        apiUrl: apiUrl,
        apiKey: apiKey,
        modelId: modelId,
        analysisModelId: env?['AI_ANALYSIS_MODEL_ID'] ?? '',
        systemPromptTemplate: systemPromptTemplate,
        timeout: timeout,
        filterThinking: filterThinking,
        retryCount: retryCount,
        maxQueryPlan: maxQueryPlan,
      );
    } else {
      result = await _grokCallApi(
        query: query,
        apiUrl: apiUrl,
        apiKey: apiKey,
        modelId: modelId,
        systemPromptTemplate: systemPromptTemplate,
        timeout: timeout,
        filterThinking: filterThinking,
        retryCount: retryCount,
      );
    }
    return McpToolResult(result);
  } catch (error) {
    return McpToolResult(
      'AI 搜索失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      '配置提示：\n'
      '  AI_API_URL — OpenAI 兼容 API 地址\n'
      '  AI_API_KEY — API 密钥\n'
      '  AI_MODEL_ID — 具有联网搜索能力的模型 ID\n'
      '  AI_MAX_QUERY_PLAN — 多维度搜索子查询数量（默认 1）',
      isError: true,
    );
  }
}

/// Multi-dimension search: split query into sub-queries and search in parallel.
Future<String> _grokMultiSearch({
  required String query,
  required String apiUrl,
  required String apiKey,
  required String modelId,
  required String analysisModelId,
  required String systemPromptTemplate,
  required int timeout,
  required bool filterThinking,
  required int retryCount,
  required int maxQueryPlan,
}) async {
  // 1. Split query using AI
  final splitModelId =
      analysisModelId.isNotEmpty ? analysisModelId : modelId;
  final splitPrompt =
      '将查询拆分成 $maxQueryPlan 个子问题，返回 JSON 数组。\n\n'
      '查询: $query\n\n'
      '只返回 JSON 数组，格式: ["子问题1", "子问题2", "子问题3"]';
  final splitSystemPrompt =
      '你是查询拆分助手。只返回 JSON 数组，不要任何解释、标记或其他文本。直接输出 JSON 数组。';

  final splitResponse = await _grokSingleRequest(
    query: splitPrompt,
    systemPrompt: splitSystemPrompt,
    apiUrl: apiUrl,
    apiKey: apiKey,
    modelId: splitModelId,
    timeout: timeout,
  );

  // Parse sub-queries
  final cleaned = splitResponse
      .trim()
      .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'^```\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'```\s*$', caseSensitive: false), '')
      .trim();

  List<String> subQueries;
  try {
    subQueries = (jsonDecode(cleaned) as List).cast<String>();
  } catch (_) {
    throw FormatException('解析子查询失败，响应内容: $cleaned');
  }
  if (subQueries.isEmpty) {
    throw const FormatException('未能拆分出任何子查询');
  }

  // 2. Execute sub-queries in parallel
  final futures = subQueries.map((sq) => _grokCallApi(
    query: sq,
    apiUrl: apiUrl,
    apiKey: apiKey,
    modelId: modelId,
    systemPromptTemplate: systemPromptTemplate,
    timeout: timeout,
    filterThinking: filterThinking,
    retryCount: retryCount,
  ));
  final results = await Future.wait(
    futures.map((f) => f.then<({String? value, Object? error})>(
      (v) => (value: v, error: null),
      onError: (e) => (value: null, error: e),
    )),
  );

  // 3. Assemble results
  final buf = StringBuffer();
  for (var i = 0; i < results.length; i++) {
    final subQuestion = i < subQueries.length ? subQueries[i] : '未知';
    final r = results[i];
    if (r.value != null) {
      buf.writeln('## 子查询 ${i + 1} 结果\n');
      buf.writeln('**子问题**: $subQuestion\n');
      buf.writeln(r.value);
      buf.writeln();
    } else {
      buf.writeln('## 子查询 ${i + 1} 失败\n');
      buf.writeln('**子问题**: $subQuestion\n');
      buf.writeln('**错误**: ${r.error}\n');
    }
  }

  final output = buf.toString().trim();
  if (output.isEmpty) throw Exception('所有子查询都失败了');
  return output;
}

/// Call API with default system prompt and retry logic.
Future<String> _grokCallApi({
  required String query,
  required String apiUrl,
  required String apiKey,
  required String modelId,
  required String systemPromptTemplate,
  required int timeout,
  required bool filterThinking,
  required int retryCount,
}) async {
  final now = DateTime.now();
  final currentTime =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  final systemPrompt = systemPromptTemplate.replaceAll('{current_time}', currentTime);

  const retryableCodes = {408, 429, 500, 502, 503, 504};
  Object? lastError;

  for (var attempt = 0; attempt <= retryCount; attempt++) {
    try {
      final result = await _grokSingleRequest(
        query: query,
        systemPrompt: systemPrompt,
        apiUrl: apiUrl,
        apiKey: apiKey,
        modelId: modelId,
        timeout: timeout,
      );
      if (filterThinking) return _filterThinkingContent(result);
      return result;
    } catch (e) {
      lastError = e;
      final msg = e.toString();
      final codeMatch = RegExp(r'\((\d+)\)').firstMatch(msg);
      final statusCode = codeMatch != null ? int.tryParse(codeMatch.group(1)!) ?? 0 : 0;
      if (attempt < retryCount &&
          (retryableCodes.contains(statusCode) || statusCode == 0)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }
      rethrow;
    }
  }
  throw lastError ?? Exception('未知错误');
}

/// Single API request to OpenAI-compatible endpoint.
Future<String> _grokSingleRequest({
  required String query,
  required String systemPrompt,
  required String apiUrl,
  required String apiKey,
  required String modelId,
  required int timeout,
}) async {
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
    'messages': [
      {'role': 'system', 'content': systemPrompt},
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
        401 => '认证失败，请检查 AI_API_KEY 是否正确',
        429 => '请求过于频繁，建议稍后重试',
        _ => 'API 请求失败 (${response.statusCode}): $body',
      };
      throw Exception(hint);
    }

    final data = jsonDecode(body) as Map<String, Object?>;
    final choices = (data['choices'] as List?) ?? [];
    if (choices.isEmpty) throw Exception('API 响应格式错误：未获取到回答内容');
    final message =
        (choices[0] as Map<String, Object?>)['message'] as Map<String, Object?>?;
    final content = message?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('API 响应格式错误：未获取到回答内容');
    }
    return content;
  } finally {
    client.close();
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
