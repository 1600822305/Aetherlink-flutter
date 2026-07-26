/// 工作台「文件」tab 的数据推导：从任务事件流里找出智能体写入的
/// 文件（write/edit 工具），含「创建中」实况状态与流式参数里的正文
/// 提取。纯函数，便于单测。
library;

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 文件条目状态。
enum AgentFileState { creating, done, failed }

/// 智能体产出的一个文件（同一路径去重，保留最新事件的状态）。
class AgentFileEntry {
  const AgentFileEntry({
    required this.path,
    required this.state,
    required this.at,
    required this.seq,
    this.streamingContent,
  });

  final String path;
  final AgentFileState state;
  final DateTime at;

  /// 该文件最新一次写入事件的 seq（内容 provider 的失效键）。
  final int seq;

  /// 创建中时从流式参数提取的正文（可能不完整）；其余状态为 null。
  final String? streamingContent;

  String get name => path.split('/').last;

  String? get dir =>
      path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : null;

  /// 文件扩展名（小写，不含点）；无扩展名为空串。
  String get ext {
    final n = name;
    final dot = n.lastIndexOf('.');
    return dot <= 0 ? '' : n.substring(dot + 1).toLowerCase();
  }

  bool get isMarkdown => ext == 'md' || ext == 'markdown';
}

bool _isWriteTool(String toolName) =>
    toolName == 'write' || toolName == 'edit';

/// 从（可能不完整的）工具参数 JSON 里提取 `path` 字段。
String? filePathOfArgs(String? argsText) {
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
String? fileContentOfArgs(String? argsText) {
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

/// 从任务事件流推导文件列表：同一路径按最新事件去重，最新的排最前。
List<AgentFileEntry> deriveAgentFiles(List<AgentEvent> events) =>
    AgentFilesFold().fold(events);

/// 增量版推导：事件流基本 append-only，只有未完结的写入工具事件
/// 会原地变更（running/waitingApproval → success/failure）。已完结的
/// 前缀只折叠一次进 `_prefixByPath`，每次 delta 只从「第一个未完结
/// 写入事件」处重扫到末尾，把每帧 O(全部事件) 降到 O(尾部未完结段)。
/// 无变化时返回同一个列表实例，便于上层用 identical 短路重建。
class AgentFilesFold {
  final _prefixByPath = <String, AgentFileEntry>{};

  /// `[0, _prefixCount)` 已折叠进 `_prefixByPath`，不再重扫。
  var _prefixCount = 0;

  /// 上一次结果是否含尾部未完结段的叠加（尾部消失时需重算）。
  var _hadPendingTail = false;
  List<AgentEvent>? _lastEvents;
  List<AgentFileEntry> _result = const [];

  static bool _isPendingWrite(AgentEvent event) =>
      event is ToolCallEvent &&
      _isWriteTool(event.toolName) &&
      (event.state == AgentToolCallState.running ||
          event.state == AgentToolCallState.waitingApproval);

  /// 把单个事件折叠进 map；返回是否真的改写了 map。
  static bool _foldEvent(Map<String, AgentFileEntry> byPath, AgentEvent event) {
    if (event is! ToolCallEvent) return false;
    if (!_isWriteTool(event.toolName)) return false;
    final args = event.argsDetail;
    final path = filePathOfArgs(args) ?? _pathOfSummary(event.argSummary);
    if (path == null) return false;
    final state = switch (event.state) {
      AgentToolCallState.running ||
      AgentToolCallState.waitingApproval =>
        AgentFileState.creating,
      AgentToolCallState.success => AgentFileState.done,
      _ => AgentFileState.failed,
    };
    final existing = byPath[path];
    if (existing != null && existing.seq > event.seq) return false;
    byPath[path] = AgentFileEntry(
      path: path,
      state: state,
      at: event.at,
      seq: event.seq,
      streamingContent:
          state == AgentFileState.creating && event.toolName == 'write'
              ? fileContentOfArgs(args)
              : null,
    );
    return true;
  }

  List<AgentFileEntry> fold(List<AgentEvent> events) {
    if (identical(events, _lastEvents)) return _result;
    _lastEvents = events;
    var changed = false;
    if (events.length < _prefixCount) {
      // 事件被删减（清空/回滚）：无法增量，整体重扫。
      changed = _prefixByPath.isNotEmpty;
      _prefixByPath.clear();
      _prefixCount = 0;
    }
    // 把已完结的事件继续折叠进前缀，遇到第一个未完结写入事件停下。
    while (_prefixCount < events.length &&
        !_isPendingWrite(events[_prefixCount])) {
      changed = _foldEvent(_prefixByPath, events[_prefixCount]) || changed;
      _prefixCount++;
    }
    if (_prefixCount == events.length) {
      if (changed || _hadPendingTail) _result = _sorted(_prefixByPath);
      _hadPendingTail = false;
      return _result;
    }
    // 尾部含未完结写入事件：在前缀快照上重放尾部（流式正文每帧在变）。
    final byPath = Map.of(_prefixByPath);
    for (var i = _prefixCount; i < events.length; i++) {
      _foldEvent(byPath, events[i]);
    }
    _hadPendingTail = true;
    _result = _sorted(byPath);
    return _result;
  }

  static List<AgentFileEntry> _sorted(Map<String, AgentFileEntry> byPath) =>
      byPath.values.toList()..sort((a, b) => b.seq.compareTo(a.seq));
}

/// argSummary 通常是路径尾段或完整相对路径；仅当它像单个路径时可用。
String? _pathOfSummary(String summary) {
  final s = summary.trim();
  if (s.isEmpty || s.contains(' ')) return null;
  return s;
}
