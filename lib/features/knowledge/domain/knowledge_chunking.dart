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

/// P0 的简单定长切块（设计文档 §5 / §11：P0 先用定长切块，P1 再升级为结构
/// 感知切块，不阻塞骨架落地）。
///
/// 按字符窗口切分，相邻块重叠 [overlap] 个字符以避免把跨边界的句子切断。
/// 空白正文返回空列表；[overlap] 会被夹在 `[0, size)` 内以保证步进为正。
List<TextChunk> chunkText(
  String text, {
  required int size,
  required int overlap,
}) {
  if (text.isEmpty) return const [];
  final safeSize = size < 1 ? 1 : size;
  final safeOverlap = overlap < 0
      ? 0
      : (overlap >= safeSize ? safeSize - 1 : overlap);
  final step = safeSize - safeOverlap;

  final chunks = <TextChunk>[];
  var start = 0;
  var unitIndex = 0;
  while (start < text.length) {
    var end = (start + safeSize) < text.length ? start + safeSize : text.length;
    end = _snapAfterSurrogatePair(text, end);
    chunks.add(
      TextChunk(
        unitIndex: unitIndex,
        charStart: start,
        charEnd: end,
        text: text.substring(start, end),
      ),
    );
    if (end >= text.length) break;
    start = _snapAfterSurrogatePair(text, start + step);
    unitIndex++;
  }
  return chunks;
}

/// 若 [index] 落在一个 UTF-16 代理对中间（前一位是高代理），后移一位，
/// 保证切块边界不把 emoji / 增补平面字符切成两个非法半截。
int _snapAfterSurrogatePair(String text, int index) {
  if (index <= 0 || index >= text.length) return index;
  final prev = text.codeUnitAt(index - 1);
  return (prev >= 0xD800 && prev <= 0xDBFF) ? index + 1 : index;
}
