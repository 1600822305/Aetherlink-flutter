import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';

/// 一段切块的位置与内容。保持设计文档 §4.3 的不变式
/// `content.text.substring(charStart, charEnd) == text`——chunk 是正文的切片
/// 派生，不重复存整篇正文。
class TextChunk {
  const TextChunk({
    required this.unitIndex,
    required this.charStart,
    required this.charEnd,
    required this.text,
  });

  final int unitIndex;
  final int charStart;
  final int charEnd;
  final String text;
}

/// 结构感知切块（设计文档 §5 P1）：按「段落 → 行 → 句子 → 定长硬切」逐级
/// 递归回退寻找切点，把结构单元贪心合并到不超过 [size]，避免定长硬切把
/// 句子/段落腰斩拉低召回质量。
///
/// - 相邻块通过把起点向前回扩 [overlap] 个字符提供上下文重叠（切点本身
///   连续，不变式仍然成立），单块长度上界为 [size]。
/// - 纯空白的块会被丢弃；[overlap] 被夹在 `[0, size)` 内以保证步进为正。
/// - 切点与回扩点都不会落在 UTF-16 代理对中间。
///
/// [strategy] 为 [KnowledgeChunkStrategy.delimiter] 时，把 [separator]（转义
/// 形式，如 `\n\n`）作为最高优先级切分符，单元仍超长时回退结构感知级别。
List<TextChunk> chunkText(
  String text, {
  required int size,
  required int overlap,
  KnowledgeChunkStrategy strategy = KnowledgeChunkStrategy.structured,
  String separator = '',
}) {
  if (text.isEmpty) return const [];
  final safeSize = size < 1 ? 1 : size;
  final safeOverlap = overlap < 0
      ? 0
      : (overlap >= safeSize ? safeSize - 1 : overlap);
  // 切点按「目标净长度」计算，回扩 overlap 后总长仍 ≤ size（与旧定长切块
  // 「窗口 size、步进 size-overlap」的语义对齐）。
  final target = safeSize - safeOverlap;

  final levels = _separatorLevels(strategy, separator);
  final cuts = <int>[];
  _cutRecursive(text, 0, text.length, target, 0, levels, cuts);

  final chunks = <TextChunk>[];
  var prev = 0;
  var unitIndex = 0;
  for (final cut in cuts) {
    final end = cut;
    var start = prev - safeOverlap;
    if (start < 0) start = 0;
    start = _snapAfterSurrogatePair(text, start);
    final slice = text.substring(start, end);
    prev = end;
    if (slice.trim().isEmpty) continue;
    chunks.add(
      TextChunk(
        unitIndex: unitIndex,
        charStart: start,
        charEnd: end,
        text: slice,
      ),
    );
    unitIndex++;
  }
  return chunks;
}

/// 递归回退的分隔级别：段落边界 → 行边界 → 句子边界。
/// 每个正则匹配「结构单元的结尾（含分隔符本身）」，切点取匹配结束位置，
/// 保证切片拼接可还原原文。
final List<RegExp> _kStructuredLevels = [
  RegExp(r'\n{2,}'), // 段落：连续空行
  RegExp(r'\n'), // 行
  // 句子：CJK 句末标点直接断；ASCII 句末标点要求后跟空白或文末，
  // 避免把 "3.14"、"v1.2" 这类小数/版本号误当句界。
  RegExp(r'[。！？；][」』”’\)）\]】]*\s*|[.!?;]["' "'" r'\)\]]*(?:\s+|$)'),
];

const Map<String, String> _kSeparatorEscapes = {
  'n': '\n',
  't': '\t',
  'r': '\r',
  r'\': r'\',
};

/// 把用户输入的转义形式分隔符（如 `\n\n`、`\t`）解成字面字符。
String unescapeChunkSeparator(String raw) {
  return raw.replaceAllMapped(
    RegExp(r'\\([ntr\\])'),
    (m) => _kSeparatorEscapes[m.group(1)]!,
  );
}

/// 本次切块的分隔级别链：delimiter 策略把用户分隔符插到最高优先级，
/// 切不动时仍能逐级回退；structured / 空分隔符保持原链。
List<RegExp> _separatorLevels(KnowledgeChunkStrategy strategy, String raw) {
  if (strategy != KnowledgeChunkStrategy.delimiter) return _kStructuredLevels;
  final literal = unescapeChunkSeparator(raw);
  if (literal.isEmpty) return _kStructuredLevels;
  return [RegExp(RegExp.escape(literal)), ..._kStructuredLevels];
}

/// 把 `[start, end)` 切成若干净长度 ≤ [target] 的片段，切点依次追加进
/// [cuts]（每个切点是片段的结束偏移，彼此连续覆盖整个区间）。
///
/// [level] 是当前尝试的分隔级别；本级切不动（单元仍超长）时对该单元递归
/// 下一级，最后一级退化为定长硬切。
void _cutRecursive(
  String text,
  int start,
  int end,
  int target,
  int level,
  List<RegExp> levels,
  List<int> cuts,
) {
  if (end - start <= target) {
    cuts.add(end);
    return;
  }
  if (level >= levels.length) {
    // 定长硬切兜底。
    var pos = start;
    while (pos < end) {
      var next = pos + target < end ? pos + target : end;
      next = _snapAfterSurrogatePair(text, next);
      cuts.add(next);
      pos = next;
    }
    return;
  }

  // 本级把区间切成结构单元（单元末尾含分隔符），再贪心合并到 ≤ target。
  final unitEnds = <int>[];
  for (final m in levels[level].allMatches(
    text.substring(start, end),
  )) {
    final unitEnd = start + m.end;
    if (unitEnd < end) unitEnds.add(unitEnd);
  }
  unitEnds.add(end);

  if (unitEnds.length == 1) {
    // 本级切不动，整段下沉到下一级。
    _cutRecursive(text, start, end, target, level + 1, levels, cuts);
    return;
  }

  var groupStart = start;
  var unitStart = start;
  for (final unitEnd in unitEnds) {
    if (unitEnd - groupStart <= target) {
      unitStart = unitEnd;
      continue;
    }
    // 加入当前单元会超长：先落下已累计的组（若有），再处理当前单元。
    if (unitStart > groupStart) {
      cuts.add(unitStart);
      groupStart = unitStart;
    }
    if (unitEnd - groupStart > target) {
      // 单个单元本身超长 → 递归下一级。
      _cutRecursive(text, groupStart, unitEnd, target, level + 1, levels, cuts);
      groupStart = unitEnd;
    }
    unitStart = unitEnd;
  }
  if (groupStart < end) cuts.add(end);
}

/// 若 [index] 落在一个 UTF-16 代理对中间（前一位是高代理），后移一位，
/// 保证切块边界不把 emoji / 增补平面字符切成两个非法半截。
int _snapAfterSurrogatePair(String text, int index) {
  if (index <= 0 || index >= text.length) return index;
  final prev = text.codeUnitAt(index - 1);
  return (prev >= 0xD800 && prev <= 0xDBFF) ? index + 1 : index;
}
