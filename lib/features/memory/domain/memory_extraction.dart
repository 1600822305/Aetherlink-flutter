import 'dart:convert';

import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// A single fact the auto-extract (autoAnalyze) pass proposes writing to the
/// store. Produced by [parseMemoryExtractionResponse] from the auxiliary
/// model's JSON reply and consumed by the composition seam that persists it.
class MemoryExtractionCandidate {
  const MemoryExtractionCandidate({
    required this.content,
    required this.level,
    required this.type,
    required this.importance,
  });

  final String content;
  final MemoryLevel level;
  final MemoryType type;
  final double importance;
}

/// Builds the extraction prompt sent to the auxiliary model after a turn.
///
/// [allowGlobal] / [allowPrivate] mirror the two 自动写入 toggles: when only one
/// is on the model is told to emit just that scope (a post-parse filter still
/// enforces it). [conversation] is the recent transcript (用户:/AI: lines).
String buildMemoryExtractionPrompt({
  required String conversation,
  required bool allowGlobal,
  required bool allowPrivate,
}) {
  final String scopeRule;
  if (allowGlobal && allowPrivate) {
    scopeRule =
        '- scope："global" 表示通用偏好（对所有助手都适用），"private" 表示仅与当前助手相关。';
  } else if (allowGlobal) {
    scopeRule = '- scope：本次只提取通用偏好，全部使用 "global"。';
  } else {
    scopeRule = '- scope：本次只提取与当前助手相关的信息，全部使用 "private"。';
  }
  return '你是一个对话记忆提取助手。请从下面的对话中，提取出值得长期记住的、'
      '关于「用户」的稳定事实或偏好（如身份、喜好、习惯、长期目标、重要背景、约束）。\n\n'
      '要求：\n'
      '1. 只提取明确、稳定、对未来对话有帮助的信息；忽略临时的、一次性的、与用户无关的闲聊。\n'
      '2. 不要提取 AI 自己的发言，只关注用户透露的关于其自身的信息。\n'
      '3. 每条记忆简洁（一句话），用第三人称陈述，例如「用户是素食者」。\n'
      '4. 如果没有值得记住的信息，返回空数组 []。\n'
      '5. 严格输出 JSON 数组本身，不要包含任何解释、前后缀或 markdown 代码块。\n\n'
      '每个元素格式：\n'
      '{"content": "记忆内容", "scope": "global|private", '
      '"type": "semantic|episodic", "importance": 0.0}\n\n'
      '字段说明：\n'
      '$scopeRule\n'
      '- type："semantic" 表示稳定的事实/偏好，"episodic" 表示具体的带时间的事件。\n'
      '- importance：该信息的重要程度，0~1 之间的小数。\n\n'
      '对话：\n'
      '<conversation>\n$conversation\n</conversation>';
}

/// Parses the auxiliary model's reply into extraction candidates. Tolerant of
/// markdown code fences and leading/trailing prose: it isolates the outermost
/// JSON array before decoding. Malformed entries are skipped; a malformed reply
/// yields an empty list rather than throwing.
List<MemoryExtractionCandidate> parseMemoryExtractionResponse(String raw) {
  final array = _extractJsonArray(raw);
  if (array == null) return const [];
  late final dynamic decoded;
  try {
    decoded = jsonDecode(array);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];

  final result = <MemoryExtractionCandidate>[];
  for (final entry in decoded) {
    if (entry is! Map) continue;
    final content = (entry['content'] as Object?)?.toString().trim() ?? '';
    if (content.isEmpty) continue;
    final scope = (entry['scope'] as Object?)?.toString().toLowerCase();
    final level =
        scope == 'private' ? MemoryLevel.owner : MemoryLevel.global;
    final typeRaw = (entry['type'] as Object?)?.toString().toLowerCase();
    final type =
        typeRaw == 'episodic' ? MemoryType.episodic : MemoryType.semantic;
    final importance = _toImportance(entry['importance']);
    result.add(
      MemoryExtractionCandidate(
        content: content,
        level: level,
        type: type,
        importance: importance,
      ),
    );
  }
  return result;
}

/// Shortest user turn worth keeping as a 情景 (episodic) fast-write; below this
/// it is almost certainly a greeting/acknowledgement, not an event.
const int _minEpisodicChars = 6;

/// Longest stored 情景 content; longer turns are truncated with an ellipsis so a
/// single verbose message can't bloat the store.
const int _maxEpisodicChars = 200;

/// Cheap (no-LLM) 情景快写 heuristic: turns the user's [userText] into the raw
/// episodic content to store, or null when it isn't worth recording. Collapses
/// whitespace, drops too-short turns and bare questions (events, not queries),
/// and truncates very long turns. Pure, so it is trivially unit-tested; the
/// model-driven 深加工 (semantic extraction) still runs separately.
String? fastEpisodicContent(String userText) {
  final normalized = userText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length < _minEpisodicChars) return null;
  // A turn that is purely a question is a query, not a recordable event.
  if (normalized.endsWith('?') || normalized.endsWith('？')) return null;
  if (normalized.length <= _maxEpisodicChars) return normalized;
  return '${normalized.substring(0, _maxEpisodicChars).trimRight()}…';
}

/// Isolates the outermost `[...]` from [raw], or null when none is present.
String? _extractJsonArray(String raw) {
  final start = raw.indexOf('[');
  final end = raw.lastIndexOf(']');
  if (start == -1 || end == -1 || end <= start) return null;
  return raw.substring(start, end + 1);
}

double _toImportance(Object? value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null) return 0.5;
  if (parsed < 0) return 0;
  if (parsed > 1) return 1;
  return parsed;
}
