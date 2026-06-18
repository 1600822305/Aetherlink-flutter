import 'dart:convert';
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
McpToolResult? runBuiltinTool(
  String serverName,
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
}) {
  switch (serverName) {
    case '@aether/calculator':
      return runCalculatorTool(toolName, args);
    case '@aether/time':
      return runTimeTool(toolName, args, now: now);
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
