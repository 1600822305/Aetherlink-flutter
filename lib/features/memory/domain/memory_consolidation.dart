import 'dart:convert';

/// One semantic fact the consolidation (Dream) pass proposes, distilled from a
/// cluster of episodic events. Produced by [parseMemoryConsolidationResponse]
/// from the auxiliary model's JSON reply and applied by the composition seam.
///
/// When [updatesIndex] is non-null it points into the existing-semantic list
/// the model was shown, meaning this fact re-consolidates (UPDATEs) that fact
/// in place rather than adding a new one (the 再巩固 path). [importance] is
/// clamped to 0..1.
class MemoryConsolidationOp {
  const MemoryConsolidationOp({
    required this.content,
    required this.importance,
    this.updatesIndex,
  });

  final String content;
  final double importance;
  final int? updatesIndex;
}

/// Builds the consolidation prompt: given a numbered list of recent [episodics]
/// (raw events) and the bucket's [existingSemantic] facts (also numbered), asks
/// the auxiliary model to distil stable semantic facts. The model may add a new
/// fact, or refine an existing one via an `updates` index when an episodic
/// cluster contradicts/extends it (再巩固).
String buildMemoryConsolidationPrompt({
  required List<String> episodics,
  required List<String> existingSemantic,
}) {
  final eps = [
    for (var i = 0; i < episodics.length; i++) '[$i] ${episodics[i]}',
  ].join('\n');
  final sem = existingSemantic.isEmpty
      ? '（暂无）'
      : [
          for (var i = 0; i < existingSemantic.length; i++)
            '[$i] ${existingSemantic[i]}',
        ].join('\n');
  return '你是一个长期记忆「巩固」助手。下面是一批零散的「情景记忆」（具体事件）和'
      '已有的「语义记忆」（稳定事实/偏好）。请把情景记忆中反复出现、稳定、对未来'
      '对话有长期价值的信息，提炼成简洁的第三人称语义事实。\n\n'
      '要求：\n'
      '1. 只输出稳定、可长期复用的事实/偏好；忽略一次性、临时的事件。\n'
      '2. 多条相似的情景应合并成一条概括的语义事实。\n'
      '3. 若某条提炼结果与某条已有语义记忆是同一主题（需修正/补充/更新），在该'
      '元素里用 "updates" 指向那条已有语义记忆的编号，表示更新它；否则省略 '
      '"updates" 表示新增。\n'
      '4. 不要重复输出与已有语义记忆完全相同的内容。\n'
      '5. 没有可提炼的内容时返回空数组 []。\n'
      '6. 严格只输出 JSON 数组本身，不要包含任何解释、前后缀或 markdown 代码块。\n\n'
      '每个元素格式：\n'
      '{"content": "语义事实", "importance": 0.0, "updates": 整数(可省略)}\n\n'
      '情景记忆：\n<episodic>\n$eps\n</episodic>\n\n'
      '已有语义记忆：\n<semantic>\n$sem\n</semantic>';
}

/// Parses the auxiliary model's consolidation reply into ops. Tolerant of
/// markdown fences and surrounding prose (isolates the outermost JSON array).
/// Malformed entries are skipped; an `updates` index outside `0..semanticCount`
/// is treated as an add (null). A malformed reply yields an empty list.
List<MemoryConsolidationOp> parseMemoryConsolidationResponse(
  String raw, {
  required int semanticCount,
}) {
  final array = _extractJsonArray(raw);
  if (array == null) return const [];
  late final dynamic decoded;
  try {
    decoded = jsonDecode(array);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];

  final result = <MemoryConsolidationOp>[];
  for (final entry in decoded) {
    if (entry is! Map) continue;
    final content = (entry['content'] as Object?)?.toString().trim() ?? '';
    if (content.isEmpty) continue;
    result.add(
      MemoryConsolidationOp(
        content: content,
        importance: _toImportance(entry['importance']),
        updatesIndex: _toIndex(entry['updates'], semanticCount),
      ),
    );
  }
  return result;
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

/// A valid `updates` index in `[0, count)`, else null (treated as an add).
int? _toIndex(Object? value, int count) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 0 || parsed >= count) return null;
  return parsed;
}
