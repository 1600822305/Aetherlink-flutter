import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_scope.dart';

part 'memory_providers.g.dart';

/// Counts shown on the 记忆 overview card (total / global / assistants).
@riverpod
Future<MemoryCounts> memoryCounts(Ref ref) =>
    ref.watch(chatMemoryStoreProvider).counts();

/// Loads and mutates the 全局记忆 list, honouring the live search [query].
@riverpod
class GlobalMemoriesController extends _$GlobalMemoriesController {
  String _query = '';

  String get query => _query;

  @override
  Future<List<MemoryItem>> build() {
    return ref
        .watch(chatMemoryStoreProvider)
        .list(const MemoryScope.chatGlobal(), query: _query);
  }

  Future<void> setQuery(String value) async {
    _query = value;
    ref.invalidateSelf();
    await future;
  }

  Future<void> create({
    required String content,
    required MemoryType type,
    String? category,
    double importance = 0.5,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await ref.read(chatMemoryStoreProvider).create(
          MemoryItem(
            id: '',
            content: trimmed,
            type: type,
            category: category?.trim().isEmpty ?? true ? null : category!.trim(),
            importance: importance,
          ),
        );
    _refresh();
  }

  Future<void> save(MemoryItem item) async {
    await ref.read(chatMemoryStoreProvider).update(item);
    _refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(chatMemoryStoreProvider).delete(id);
    _refresh();
  }

  void _refresh() {
    ref.invalidateSelf();
    ref.invalidate(memoryCountsProvider);
  }
}
