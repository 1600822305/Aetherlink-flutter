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

  Future<MemoryCounts> counts() async {
    final total = await _dao.countByKind(MemoryKind.chat);
    final global = await _dao.count(const MemoryScope.chatGlobal());
    final assistants = await _dao.distinctOwnerCount(MemoryKind.chat);
    return MemoryCounts(total: total, global: global, assistants: assistants);
  }
}
