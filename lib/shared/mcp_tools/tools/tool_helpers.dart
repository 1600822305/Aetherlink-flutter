import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// Shared helpers used by multiple built-in MCP tool implementations.

const JsonEncoder jsonPrettyEncoder = JsonEncoder.withIndent('  ');

String encodeJson(Object? value) => jsonPrettyEncoder.convert(value);

/// Collapses integer-valued doubles to `int` so JSON renders `5`, not `5.0`.
Object normNum(num value) {
  if (value is int) return value;
  final d = value.toDouble();
  if (d.isFinite && d == d.truncateToDouble()) return d.toInt();
  return d;
}

String numStr(num value) => normNum(value).toString();

/// Format number: integers as-is, otherwise up to 10 decimals trimmed.
String formatNumber(double n) {
  if (!n.isFinite) return n.toString();
  if (n == n.truncateToDouble()) return n.toInt().toString();
  final trimmed = double.parse(n.toStringAsFixed(10));
  if (trimmed == trimmed.truncateToDouble()) return trimmed.toInt().toString();
  return trimmed.toString();
}

int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('无效的整数: $value');
}

double asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('无效的数值: $value');
}

int asIntOr(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String errMsg(Object error, String fallback) {
  if (error is FormatException) {
    final message = error.message;
    if (message.isNotEmpty) return message;
  }
  return fallback;
}

/// Decode common HTML entities.
String decodeHtmlEntities(String text) {
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

/// Convenience constructor for error results.
McpToolResult toolError(String message) => McpToolResult(message, isError: true);
