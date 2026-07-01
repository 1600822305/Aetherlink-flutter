/// Reciprocal Rank Fusion（设计文档 §6 hybrid 融合）。把多路各自已排好序的 id 列表
/// 融合成一路：每个 id 的分数为 `Σ 1/(k + rank)`（rank 从 1 计），按分数降序返回。
///
/// RRF 只看排名不看原始分数，因此天然把「关键词命中比例」与「余弦相似度」这类不可比
/// 的分数统一起来。[k] 取业界常用的 60：越大越弱化靠前名次的权重、越强调多路共识。
/// 同分时按「首次出现顺序」稳定排序，保证结果确定可测。
List<String> fuseWithRrf(List<List<String>> rankings, {int k = 60}) {
  final scores = <String, double>{};
  final firstSeen = <String, int>{};
  var order = 0;
  for (final ranking in rankings) {
    for (var rank = 0; rank < ranking.length; rank++) {
      final id = ranking[rank];
      final contribution = 1.0 / (k + rank + 1);
      scores.update(
        id,
        (existing) => existing + contribution,
        ifAbsent: () => contribution,
      );
      firstSeen.putIfAbsent(id, () => order++);
    }
  }
  final ids = scores.keys.toList()
    ..sort((a, b) {
      final byScore = scores[b]!.compareTo(scores[a]!);
      if (byScore != 0) return byScore;
      return firstSeen[a]!.compareTo(firstSeen[b]!);
    });
  return ids;
}
