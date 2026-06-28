import 'dart:math' as math;

import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// Weights for the ACT-R-style activation score used to rank retrieval
/// candidates. Cosine [similarity] is the dominant term (its weight is
/// deliberately larger than the others combined) so activation only *reorders*
/// among comparably-relevant memories — recency, hit frequency and importance
/// act as tie-breakers, never overriding a clearly more relevant memory.
class ActivationWeights {
  const ActivationWeights({
    this.similarity = 1.0,
    this.recency = 0.25,
    this.frequency = 0.15,
    this.importance = 0.20,
  });

  /// Pure-cosine ranking: only similarity counts (the 退回纯向量 fallback).
  static const ActivationWeights pureSimilarity = ActivationWeights(
    recency: 0,
    frequency: 0,
    importance: 0,
  );

  final double similarity;
  final double recency;
  final double frequency;
  final double importance;
}

/// Daily decay constant for the recency term: `exp(-_recencyLambda * days)`.
/// ~0.023 ≈ a 30-day half-life, so recency fades slowly and gently.
const double _recencyLambda = 0.023;

/// Conservative-forgetting floor: semantic facts and high-importance memories
/// never let their recency term sink below this, so age alone can't bury a
/// stable fact. Episodic + low-importance memories decay freely toward 0.
const double _recencyFloor = 0.5;

/// Importance at/above which a memory is treated as "stable" and exempt from
/// recency decay (gets the [_recencyFloor]).
const double _stableImportance = 0.7;

/// Recency component in `[0, 1]`: exponential decay over days since the memory
/// was last recalled (falling back to creation time). Implements 保守遗忘衰减 —
/// only episodic + low-importance memories decay all the way down; semantic and
/// high-importance memories are floored at [_recencyFloor].
double recencyScore(MemoryItem item, int nowMillis) {
  final ref = item.lastAccessedAt ?? item.createdAt;
  if (ref <= 0) return _recencyFloor;
  final days = (nowMillis - ref) / 86400000.0;
  final raw = days <= 0 ? 1.0 : math.exp(-_recencyLambda * days);
  final stable =
      item.type == MemoryType.semantic || item.importance >= _stableImportance;
  return stable ? math.max(raw, _recencyFloor) : raw;
}

/// Frequency component in `[0, 1]`: log-scaled hit count so the first few
/// recalls matter most and a runaway counter can't dominate.
double frequencyScore(int accessCount) {
  if (accessCount <= 0) return 0;
  return math.min(1.0, math.log(1 + accessCount) / math.log(11));
}

/// Fraction of the remaining gap to [_importanceCap] that a single retrieval
/// hit adds to a memory's importance (命中强化 / the testing effect).
const double _hitImportanceGain = 0.04;

/// Ceiling for hit-reinforced importance: recalls strengthen a memory toward
/// this, but never to a perfect 1.0 (reserved for explicit user intent).
const double _importanceCap = 0.95;

/// Importance after one retrieval hit: nudges [importance] a [_hitImportanceGain]
/// fraction of the way toward [_importanceCap], so frequently-recalled memories
/// strengthen with diminishing returns and asymptotically approach the cap.
/// Input is clamped to `[0, 1]`; an importance already at/above the cap (e.g. a
/// user-pinned 1.0) is left untouched so a hit never weakens it.
double reinforcedImportance(double importance) {
  final imp = importance < 0 ? 0.0 : (importance > 1 ? 1.0 : importance);
  if (imp >= _importanceCap) return imp;
  return imp + _hitImportanceGain * (_importanceCap - imp);
}

/// Combines cosine [similarity] with recency, hit frequency and importance into
/// a single activation score (higher = more activated). Similarity dominates by
/// [weights]; the rest are gentle tie-breakers. Cosine is clamped to `[0, 1]`.
double memoryActivation({
  required double similarity,
  required MemoryItem item,
  required int nowMillis,
  ActivationWeights weights = const ActivationWeights(),
}) {
  final sim = similarity < 0 ? 0.0 : (similarity > 1 ? 1.0 : similarity);
  final imp = item.importance < 0
      ? 0.0
      : (item.importance > 1 ? 1.0 : item.importance);
  return weights.similarity * sim +
      weights.recency * recencyScore(item, nowMillis) +
      weights.frequency * frequencyScore(item.accessCount) +
      weights.importance * imp;
}

/// Ranks [candidates] by [memoryActivation] against [queryVector] (cosine +
/// recency/frequency/importance) and returns the top [topK] (descending). Like
/// [rankBySimilarity] but with the activation tie-breakers; candidates without
/// an embedding are skipped. [topK] is clamped to ≥ 1.
List<ScoredMemory> rankByActivation(
  List<double> queryVector,
  List<MemoryItem> candidates,
  int topK, {
  required int nowMillis,
  ActivationWeights weights = const ActivationWeights(),
}) {
  if (queryVector.isEmpty) return const <ScoredMemory>[];
  final scored = <ScoredMemory>[
    for (final item in candidates)
      if (item.embedding != null && item.embedding!.isNotEmpty)
        ScoredMemory(
          item,
          memoryActivation(
            similarity: cosineSimilarity(queryVector, item.embedding!),
            item: item,
            nowMillis: nowMillis,
            weights: weights,
          ),
        ),
  ]..sort((a, b) => b.score.compareTo(a.score));
  final limit = topK < 1 ? 1 : topK;
  return scored.length > limit ? scored.sublist(0, limit) : scored;
}

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
