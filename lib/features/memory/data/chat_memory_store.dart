import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memory_dao.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_scope.dart';

/// Counts surfaced on the 记忆 overview card.
class MemoryCounts {
  const MemoryCounts({
    required this.total,
    required this.global,
    required this.assistants,
  });

  final int total;
  final int global;
  final int assistants;
}

/// Application-facing store for普通聊天 memories, wrapping [MemoryDao] with
/// scope-aware operations and id/timestamp bookkeeping. Agent memories share
/// the same table but are reached through a future `AgentMemoryStore`; this
/// store only ever touches [MemoryKind.chat] buckets.
class ChatMemoryStore {
  ChatMemoryStore(this._dao);

  final MemoryDao _dao;

  Future<List<MemoryItem>> list(MemoryScope scope, {String? query}) =>
      _dao.list(scope, query: query);

  /// All chat memories (global + every assistant's private rows), newest first,
  /// optionally filtered by [query]. Backs the 搜索全部记忆 page.
  Future<List<MemoryItem>> searchAll({String? query}) =>
      _dao.searchAll(MemoryKind.chat, query: query);

  /// Creates a new memory, minting an id and create/update timestamps. The
  /// passed [item]'s scope fields (kind/level/ownerId) are preserved.
  Future<MemoryItem> create(MemoryItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final created = item.copyWith(
      id: generateId('mem'),
      createdAt: now,
      updatedAt: now,
    );
    await _dao.upsert(created);
    return created;
  }

  /// Persists edits to an existing memory, bumping `updatedAt`.
  Future<MemoryItem> update(MemoryItem item) async {
    final updated = item.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.upsert(updated);
    return updated;
  }

  Future<void> delete(String id) => _dao.softDelete(id);

  /// Persists a recomputed [item.embedding] / [item.embeddingModelId] in place
  /// without touching `updatedAt` (so caching a vector never reorders the
  /// newest-first lists). Used by semantic retrieval's lazy embedding backfill.
  Future<void> persistEmbedding(MemoryItem item) => _dao.upsert(item);

  /// Records a retrieval hit on each of [items]: bumps `accessCount` and stamps
  /// `lastAccessedAt` with now, leaving `updatedAt` untouched so logging a hit
  /// never reorders the newest-first lists. Backs the 命中日志 / eval surface.
  Future<void> recordHits(Iterable<MemoryItem> items) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in items) {
      await _dao.upsert(
        item.copyWith(
          accessCount: item.accessCount + 1,
          lastAccessedAt: now,
        ),
      );
    }
  }

  Future<MemoryCounts> counts() async {
    final total = await _dao.countByKind(MemoryKind.chat);
    final global = await _dao.count(const MemoryScope.chatGlobal());
    final assistants = await _dao.distinctOwnerCount(MemoryKind.chat);
    return MemoryCounts(total: total, global: global, assistants: assistants);
  }

  /// Map of assistant id → number of private chat memories it owns (used by the
  /// 按助手查看 index).
  Future<Map<String, int>> ownerCounts() => _dao.ownerCounts(MemoryKind.chat);
}
