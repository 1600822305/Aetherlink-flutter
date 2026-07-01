import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// 计算某段 chunk 文本在指定嵌入模型下的复合去重键（设计文档 §4.3）：
/// `sha256(embeddingModelKey + '|' + sha256(chunkText))`。
///
/// 带上模型键是关键——否则相同内容在不同模型（维度不同）下会被内容哈希错误复用，
/// 导致向量污染。同一 `(模型, 内容)` 恒定映射到同一 key，从而天然去重、不重复扣费。
String computeEmbeddingKey(String embeddingModelKey, String chunkText) {
  final contentHash = sha256.convert(utf8.encode(chunkText)).toString();
  return sha256
      .convert(utf8.encode('$embeddingModelKey|$contentHash'))
      .toString();
}

/// 向量 → 存储字符串（JSON 编码的 `List<double>`，见 [KbEmbeddingRows]）。
String encodeVector(List<double> vector) => jsonEncode(vector);

/// 存储字符串 → 向量。解析失败或非数值元素时返回空列表（调用方按缺失处理）。
List<double> decodeVector(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return [
    for (final value in decoded)
      if (value is num) value.toDouble(),
  ];
}

/// 余弦相似度（值域 `[-1, 1]`）。任一向量为零向量或长度不一致时返回 0。
///
/// 知识库自带一份而不复用 memory 的 `cosineSimilarity`：那个文件与 `MemoryItem`
/// 耦合，跨 feature 引入会把记忆领域拖进知识库。这里是纯函数、零依赖。
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}
