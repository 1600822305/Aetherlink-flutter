import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// Encodes [vector] as the little-endian float32 BLOB that sqlite-vec expects
/// for a `FLOAT[n]` column. Pure (no native dependency) so it stays unit-testable
/// independently of whether the sqlite-vec extension is actually loadable.
/// Mobile/desktop targets are little-endian, matching `Float32List`'s host
/// layout.
Uint8List float32Blob(List<double> vector) =>
    Float32List.fromList(vector).buffer.asUint8List();

/// Cosine similarity of two equal-length vectors, in `[-1, 1]`. Returns 0 when
/// either vector is empty, length-mismatched, or has zero magnitude (so a
/// degenerate embedding never wins a ranking).
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

/// A memory paired with its cosine score against the current query.
class ScoredMemory {
  const ScoredMemory(this.item, this.score);

  final MemoryItem item;
  final double score;
}

/// Ranks [candidates] by cosine similarity to [queryVector] and returns the top
/// [topK] (descending score). Candidates without an embedding are skipped — the
/// caller is responsible for having populated/refreshed vectors beforehand.
/// [topK] is clamped to ≥ 1.
List<ScoredMemory> rankBySimilarity(
  List<double> queryVector,
  List<MemoryItem> candidates,
  int topK,
) {
  if (queryVector.isEmpty) return const <ScoredMemory>[];
  final scored = <ScoredMemory>[
    for (final item in candidates)
      if (item.embedding != null && item.embedding!.isNotEmpty)
        ScoredMemory(item, cosineSimilarity(queryVector, item.embedding!)),
  ]..sort((a, b) => b.score.compareTo(a.score));
  final limit = topK < 1 ? 1 : topK;
  return scored.length > limit ? scored.sublist(0, limit) : scored;
}
