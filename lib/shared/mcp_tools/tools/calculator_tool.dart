import 'dart:math' as math;

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/math_expression.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

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
    encodeJson({'success': false, 'error': '未知的工具: $toolName'}),
    isError: true,
  );
}

McpToolResult _calculate(Map<String, Object?> args) {
  final expression = (args['expression'] as String?)?.trim() ?? '';
  try {
    final result = evaluateMathExpression(expression);
    if (!result.isFinite) throw const FormatException('无效的数学表达式');
    return McpToolResult(
      encodeJson({
        'success': true,
        'expression': expression,
        'result': normNum(result),
        'formatted': formatNumber(result),
      }),
    );
  } catch (error) {
    return McpToolResult(
      encodeJson({
        'success': false,
        'expression': expression,
        'error': errMsg(error, '计算错误'),
      }),
      isError: true,
    );
  }
}

McpToolResult _convertBase(Map<String, Object?> args) {
  try {
    final value = '${args['value']}';
    final fromBase = asInt(args['fromBase']);
    final toBase = asInt(args['toBase']);
    const allowed = {2, 8, 10, 16};
    if (!allowed.contains(fromBase) || !allowed.contains(toBase)) {
      throw const FormatException('只支持 2, 8, 10, 16 进制');
    }
    final decimal = int.tryParse(value.trim(), radix: fromBase);
    if (decimal == null) throw const FormatException('无效的数值');
    var result = decimal.toRadixString(toBase);
    if (toBase == 16) result = result.toUpperCase();
    return McpToolResult(
      encodeJson({
        'success': true,
        'input': {'value': value, 'base': fromBase},
        'output': {'value': result, 'base': toBase},
        'decimal': decimal,
      }),
    );
  } catch (error) {
    return McpToolResult(
      encodeJson({'success': false, 'error': errMsg(error, '进制转换失败')}),
      isError: true,
    );
  }
}

McpToolResult _convertUnit(Map<String, Object?> args) {
  try {
    final value = asDouble(args['value']);
    final category = (args['category'] as String?) ?? '';
    final fromUnit = (args['fromUnit'] as String?) ?? '';
    final toUnit = (args['toUnit'] as String?) ?? '';
    final result = switch (category) {
      'length' => _convertFactor(value, fromUnit, toUnit, _lengthToMeters, '长度'),
      'weight' => _convertFactor(value, fromUnit, toUnit, _weightToKg, '重量'),
      'temperature' => _convertTemperature(value, fromUnit, toUnit),
      'area' => _convertFactor(value, fromUnit, toUnit, _areaToSqMeters, '面积'),
      'volume' => _convertFactor(value, fromUnit, toUnit, _volumeToLiters, '体积'),
      _ => throw FormatException('不支持的单位类别: $category'),
    };
    return McpToolResult(
      encodeJson({
        'success': true,
        'input': '${numStr(value)} $fromUnit',
        'output': '${numStr(result)} $toUnit',
        'result': normNum(result),
        'category': category,
      }),
    );
  } catch (error) {
    return McpToolResult(
      encodeJson({'success': false, 'error': errMsg(error, '单位转换失败')}),
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
    final numbers = raw.map(asDouble).toList();
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
      encodeJson({
        'success': true,
        'count': n,
        'sum': normNum(sum),
        'mean': normNum(mean),
        'median': normNum(median),
        'mode': _mode(numbers),
        'variance': normNum(variance),
        'standardDeviation': normNum(stdDev),
        'min': normNum(minV),
        'max': normNum(maxV),
        'range': normNum(maxV - minV),
        'sorted': sorted.map(normNum).toList(),
      }),
    );
  } catch (error) {
    return McpToolResult(
      encodeJson({'success': false, 'error': errMsg(error, '统计计算失败')}),
      isError: true,
    );
  }
}

// ── Unit conversion tables ──────────────────────────────────────────────────

const Map<String, double> _lengthToMeters = {
  'mm': 0.001, 'cm': 0.01, 'm': 1, 'km': 1000,
  'inch': 0.0254, 'foot': 0.3048, 'yard': 0.9144, 'mile': 1609.344,
};

const Map<String, double> _weightToKg = {
  'mg': 0.000001, 'g': 0.001, 'kg': 1, 'ton': 1000,
  'oz': 0.0283495, 'lb': 0.453592, 'pound': 0.453592,
};

const Map<String, double> _areaToSqMeters = {
  'sqmm': 0.000001, 'sqcm': 0.0001, 'sqm': 1, 'sqkm': 1000000,
  'sqinch': 0.00064516, 'sqfoot': 0.092903, 'sqyard': 0.836127,
  'acre': 4046.86, 'hectare': 10000,
};

const Map<String, double> _volumeToLiters = {
  'ml': 0.001, 'l': 1, 'm3': 1000,
  'gallon': 3.78541, 'quart': 0.946353, 'pint': 0.473176,
  'cup': 0.236588, 'floz': 0.0295735,
};

double _convertFactor(
  double value, String from, String to,
  Map<String, double> table, String label,
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
    case 'celsius': case 'c': celsius = value;
    case 'fahrenheit': case 'f': celsius = (value - 32) * 5 / 9;
    case 'kelvin': case 'k': celsius = value - 273.15;
    default: throw FormatException('不支持的温度单位: $from');
  }
  switch (to.toLowerCase()) {
    case 'celsius': case 'c': return celsius;
    case 'fahrenheit': case 'f': return celsius * 9 / 5 + 32;
    case 'kelvin': case 'k': return celsius + 273.15;
    default: throw FormatException('不支持的温度单位: $to');
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
  return maxFreq > 1 ? normNum(mode!) : null;
}
