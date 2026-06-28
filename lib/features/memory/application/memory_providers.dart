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

/// Loads, edits and deletes the cross-scope 搜索全部记忆 result (chat-global plus
/// every assistant's private memories), honouring the live search [query]. New
/// memories aren't created here — the page has no scope to assign them to — so
/// it only exposes [save]/[delete], which fan out invalidations to every memory
/// list/count provider since an edited row may belong to any bucket.
@riverpod
class AllMemoriesSearchController extends _$AllMemoriesSearchController {
  String _query = '';

  String get query => _query;

  @override
  Future<List<MemoryItem>> build() {
    return ref.watch(chatMemoryStoreProvider).searchAll(query: _query);
  }

  Future<void> setQuery(String value) async {
    _query = value;
    ref.invalidateSelf();
    await future;
  }

  Future<void> save(MemoryItem item) async {
    await ref.read(chatMemoryStoreProvider).update(item);
    _refresh(item);
  }

  Future<void> delete(MemoryItem item) async {
    await ref.read(chatMemoryStoreProvider).delete(item.id);
    _refresh(item);
  }

  void _refresh(MemoryItem item) {
    ref.invalidateSelf();
    ref.invalidate(memoryCountsProvider);
    if (item.level == MemoryLevel.global) {
      ref.invalidate(globalMemoriesControllerProvider);
    } else {
      ref.invalidate(assistantMemoryOwnerCountsProvider);
      final ownerId = item.ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        ref.invalidate(assistantMemoriesControllerProvider(ownerId));
      }
    }
  }
}

/// Map of assistant id → private memory count, backing the 按助手查看 index.
@riverpod
Future<Map<String, int>> assistantMemoryOwnerCounts(Ref ref) =>
    ref.watch(chatMemoryStoreProvider).ownerCounts();

/// Loads and mutates a single assistant's private (`level=owner`) memory list,
/// honouring the live search [query]. Family-keyed by [assistantId].
@riverpod
class AssistantMemoriesController extends _$AssistantMemoriesController {
  String _query = '';

  String get query => _query;

  @override
  Future<List<MemoryItem>> build(String assistantId) {
    return ref
        .watch(chatMemoryStoreProvider)
        .list(MemoryScope.chatAssistant(assistantId), query: _query);
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
            level: MemoryLevel.owner,
            ownerId: assistantId,
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
    ref.invalidate(assistantMemoryOwnerCountsProvider);
  }
}
