import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_vector.dart';

const int _day = 86400000;

MemoryItem _item({
  String id = 'm',
  MemoryType type = MemoryType.episodic,
  double importance = 0.5,
  int accessCount = 0,
  int? lastAccessedAt,
  int createdAt = 0,
  List<double>? embedding,
}) => MemoryItem(
  id: id,
  content: id,
  type: type,
  importance: importance,
  accessCount: accessCount,
  lastAccessedAt: lastAccessedAt,
  createdAt: createdAt,
  embedding: embedding,
);

void main() {
  group('recencyScore', () {
    test('fresh access scores ~1, old episodic decays well below floor', () {
      final now = 400 * _day;
      final fresh = recencyScore(_item(lastAccessedAt: now), now);
      final old = recencyScore(
        _item(lastAccessedAt: _day, createdAt: _day),
        now,
      );
      expect(fresh, closeTo(1.0, 1e-9));
      expect(old, lessThan(0.1));
    });

    test('semantic + high-importance memories are floored against age', () {
      final now = 400 * _day;
      final oldSemantic = recencyScore(
        _item(type: MemoryType.semantic, lastAccessedAt: 0),
        now,
      );
      final oldImportant = recencyScore(
        _item(importance: 0.9, lastAccessedAt: 0),
        now,
      );
      // 保守遗忘衰减: stable memories never sink below the 0.5 floor.
      expect(oldSemantic, greaterThanOrEqualTo(0.5));
      expect(oldImportant, greaterThanOrEqualTo(0.5));
    });
  });

  group('frequencyScore', () {
    test('monotonic, zero at no hits, saturates at 1', () {
      expect(frequencyScore(0), 0);
      expect(frequencyScore(1), greaterThan(0));
      expect(frequencyScore(5), greaterThan(frequencyScore(1)));
      expect(frequencyScore(1000), lessThanOrEqualTo(1.0));
    });
  });

  group('memoryActivation', () {
    test('similarity dominates: higher cosine wins despite weaker recency', () {
      final now = 100 * _day;
      final relevantOld = memoryActivation(
        similarity: 0.9,
        item: _item(lastAccessedAt: 0),
        nowMillis: now,
      );
      final irrelevantFresh = memoryActivation(
        similarity: 0.2,
        item: _item(lastAccessedAt: now, accessCount: 50, importance: 1),
        nowMillis: now,
      );
      expect(relevantOld, greaterThan(irrelevantFresh));
    });

    test('among similar relevance, recency/frequency break the tie', () {
      final now = 100 * _day;
      final stale = memoryActivation(
        similarity: 0.8,
        item: _item(id: 'stale', lastAccessedAt: 0, accessCount: 0),
        nowMillis: now,
      );
      final hot = memoryActivation(
        similarity: 0.8,
        item: _item(id: 'hot', lastAccessedAt: now, accessCount: 8),
        nowMillis: now,
      );
      expect(hot, greaterThan(stale));
    });
  });

  group('rankByActivation', () {
    test('reorders comparably-relevant memories by activation', () {
      final now = 100 * _day;
      final query = [1.0, 0.0];
      final stale = _item(
        id: 'stale',
        embedding: [0.9, 0.1],
        lastAccessedAt: 0,
      );
      final hot = _item(
        id: 'hot',
        embedding: [0.9, 0.1],
        lastAccessedAt: now,
        accessCount: 5,
      );
      final ranked = rankByActivation(query, [stale, hot], 2, nowMillis: now);
      expect(ranked.first.item.id, 'hot');
    });

    test('skips memories without an embedding', () {
      final ranked = rankByActivation(
        [1.0, 0.0],
        [_item(id: 'novec')],
        5,
        nowMillis: 0,
      );
      expect(ranked, isEmpty);
    });
  });

  group('reinforcedImportance', () {
    test('a hit raises importance with diminishing returns toward the cap', () {
      const start = 0.5;
      final once = reinforcedImportance(start);
      final twice = reinforcedImportance(once);
      // Each hit increases importance...
      expect(once, greaterThan(start));
      expect(twice, greaterThan(once));
      // ...but by a shrinking amount as it approaches the cap.
      expect(twice - once, lessThan(once - start));
      // ...and never exceeds the cap (0.95).
      expect(twice, lessThan(0.95));
    });

    test('never lowers an already-capped / pinned importance', () {
      expect(reinforcedImportance(0.95), 0.95);
      expect(reinforcedImportance(1.0), 1.0);
    });

    test('clamps out-of-range input before reinforcing', () {
      expect(reinforcedImportance(-1), greaterThanOrEqualTo(0.0));
      expect(reinforcedImportance(2), 1.0);
    });

    test('repeated hits converge to but stay under the cap', () {
      var imp = 0.0;
      for (var i = 0; i < 200; i++) {
        imp = reinforcedImportance(imp);
      }
      expect(imp, lessThan(0.95));
      expect(imp, greaterThan(0.94));
    });
  });
}
