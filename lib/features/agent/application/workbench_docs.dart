/// 工作台「文档」tab 的数据推导：从任务事件流里找出智能体写入的
/// Markdown 文档（write/edit 工具、路径以 .md/.markdown 结尾），
/// 含「创建中」实况状态与流式参数里的正文提取。纯函数，便于单测。
library;

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 文档条目状态。
enum AgentDocState { creating, done, failed }

/// 智能体产出的一份文档（同一路径去重，保留最新事件的状态）。
class AgentDocEntry {
  const AgentDocEntry({
    required this.path,
    required this.state,
    required this.at,
    required this.seq,
    this.streamingContent,
  });

  final String path;
  final AgentDocState state;
  final DateTime at;

  /// 该文档最新一次写入事件的 seq（内容 provider 的失效键）。
  final int seq;

  /// 创建中时从流式参数提取的正文（可能不完整）；其余状态为 null。
  final String? streamingContent;

  String get name => path.split('/').last;

  String? get dir =>
      path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : null;
}

bool _isDocPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.md') || lower.endsWith('.markdown');
}

bool _isDocWriteTool(String toolName) =>
    toolName == 'write' || toolName == 'edit';

/// 从（可能不完整的）工具参数 JSON 里提取 `path` 字段。
String? docPathOfArgs(String? argsText) {
  if (argsText == null || argsText.isEmpty) return null;
  try {
    final decoded = jsonDecode(argsText);
    if (decoded is Map<String, dynamic>) {
      final path = decoded['path'];
      if (path is String && path.isNotEmpty) return path;
    }
    return null;
  } catch (_) {
    // 流式参数还没闭合：正则兜底取已流出的 path 值。
    final m = RegExp(r'"path"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(argsText);
    if (m == null) return null;
    final path = _unescapeJsonString(m.group(1)!);
    return path.isEmpty ? null : path;
  }
}

/// 从（可能不完整的）write 参数 JSON 里提取 `content` 正文，用于
/// 创建中的实况预览。取到多少渲染多少；提不出返回 null。
String? docContentOfArgs(String? argsText) {
  if (argsText == null || argsText.isEmpty) return null;
  try {
    final decoded = jsonDecode(argsText);
    if (decoded is Map<String, dynamic>) {
      final content = decoded['content'];
      if (content is String) return content;
    }
    return null;
  } catch (_) {
    // 未闭合：取 "content":" 之后已流出的部分（到结尾或未转义引号）。
    final start = RegExp(r'"content"\s*:\s*"').firstMatch(argsText);
    if (start == null) return null;
    final rest = argsText.substring(start.end);
    final end = RegExp(r'(?<!\\)(?:\\\\)*"').firstMatch(rest);
    final raw = end == null ? rest : rest.substring(0, end.end - 1);
    return _unescapeJsonString(raw);
  }
}

String _unescapeJsonString(String raw) {
  final sb = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c != r'\' || i + 1 >= raw.length) {
      sb.write(c);
      continue;
    }
    i++;
    switch (raw[i]) {
      case 'n':
        sb.write('\n');
      case 't':
        sb.write('\t');
      case 'r':
        sb.write('\r');
      case 'u':
        if (i + 4 < raw.length) {
          final code = int.tryParse(raw.substring(i + 1, i + 5), radix: 16);
          if (code != null) {
            sb.writeCharCode(code);
            i += 4;
          }
        }
      default:
        sb.write(raw[i]);
    }
  }
  return sb.toString();
}

/// 从任务事件流推导文档列表：同一路径按最新事件去重，最新的排最前。
List<AgentDocEntry> deriveAgentDocs(List<AgentEvent> events) {
  final byPath = <String, AgentDocEntry>{};
  for (final event in events) {
    if (event is! ToolCallEvent) continue;
    if (!_isDocWriteTool(event.toolName)) continue;
    final args = event.argsDetail;
    final path = docPathOfArgs(args) ?? _pathOfSummary(event.argSummary);
    if (path == null || !_isDocPath(path)) continue;
    final state = switch (event.state) {
      AgentToolCallState.running ||
      AgentToolCallState.waitingApproval =>
        AgentDocState.creating,
      AgentToolCallState.success => AgentDocState.done,
      _ => AgentDocState.failed,
    };
    final existing = byPath[path];
    if (existing != null && existing.seq > event.seq) continue;
    byPath[path] = AgentDocEntry(
      path: path,
      state: state,
      at: event.at,
      seq: event.seq,
      streamingContent: state == AgentDocState.creating && event.toolName == 'write'
          ? docContentOfArgs(args)
          : null,
    );
  }
  return byPath.values.toList()..sort((a, b) => b.seq.compareTo(a.seq));
}

/// argSummary 通常是路径尾段或完整相对路径；仅当它本身像 .md 路径时可用。
String? _pathOfSummary(String summary) {
  final s = summary.trim();
  if (s.isEmpty || s.contains(' ')) return null;
  return _isDocPath(s) ? s : null;
}
