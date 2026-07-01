// Shared helpers for the `@aether/knowledge` built-in MCP server.
//
// JSON envelope + argument parsing, kept apart from the tool handlers so the
// dispatcher file stays small（企业级 模块化，与 file_editor_support 同款）。

import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// Thrown by the handlers below to short-circuit with a clean, model-facing
/// error message (turned into an error [McpToolResult]).
class KnowledgeToolError implements Exception {
  const KnowledgeToolError(this.message);
  final String message;
}

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

/// A successful tool result: `{ success: true, data: ... }`.
McpToolResult knowledgeOk(Object? data) =>
    McpToolResult(_prettyJson.convert({'success': true, 'data': data}));

/// A failed tool result: `{ success: false, error: ... }`, flagged as error.
McpToolResult knowledgeError(String message) => McpToolResult(
      _prettyJson.convert({'success': false, 'error': message}),
      isError: true,
    );

/// Reads a required string [key]; throws [KnowledgeToolError] when missing.
String requireKnowledgeString(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value != null && value is! String) {
    final s = value.toString().trim();
    if (s.isNotEmpty) return s;
  }
  throw KnowledgeToolError('缺少必需参数: $key');
}

/// Reads an optional string [key]; null when absent/blank. Non-strings are
/// stringified so a wrong JSON type doesn't blow up with a `CastError`.
String? optionalKnowledgeString(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value == null) return null;
  final s = value is String ? value : value.toString();
  return s.trim().isEmpty ? null : s.trim();
}

/// Reads an optional int [key] (accepts num or numeric string).
int? optionalKnowledgeInt(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Reads an optional bool [key], defaulting to [fallback].
bool optionalKnowledgeBool(
  Map<String, Object?> args,
  String key, {
  bool fallback = false,
}) {
  final value = args[key];
  if (value is bool) return value;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return fallback;
}
