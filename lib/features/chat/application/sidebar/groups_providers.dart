import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';

part 'groups_providers.g.dart';

/// Assistant folders and topic folders, persisted via Drift — the port of
/// `groupsSlice`. Ungrouped membership is derived from [Group.items], so each
/// item lives in at most one group within its scope.
@Riverpod(keepAlive: true)
class Groups extends _$Groups {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<Group>> build() => _repo.getAllGroups();

  Future<void> _reload() async {
    state = AsyncData<List<Group>>(await _repo.getAllGroups());
  }

  bool _sameScope(Group a, GroupType type, String? assistantId) =>
      a.type == type &&
      (type == GroupType.assistant || a.assistantId == assistantId);

  /// Creates a folder; `order` is the count of existing same-scope folders.
  /// Returns the new folder's id (or `null` when [name] is blank).
  Future<String?> createGroup({
    required GroupType type,
    required String name,
    String? assistantId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final groups = await _repo.getAllGroups();
    final order = groups.where((g) => _sameScope(g, type, assistantId)).length;
    final id = generateId('group');
    await _repo.saveGroup(
      Group(
        id: id,
        name: trimmed,
        type: type,
        assistantId: type == GroupType.topic ? assistantId : null,
        order: order,
      ),
    );
    await _reload();
    return id;
  }

  /// Adds [itemId] to [groupId], removing it from any other same-scope folder.
  Future<void> addItemToGroup(String groupId, String itemId) async {
    final groups = await _repo.getAllGroups();
    Group? target;
    for (final g in groups) {
      if (g.id == groupId) {
        target = g;
        break;
      }
    }
    if (target == null) return;
    for (final g in groups) {
      if (!_sameScope(g, target.type, target.assistantId)) continue;
      if (g.id == groupId) {
        if (!g.items.contains(itemId)) {
          await _repo.saveGroup(
            g.copyWith(items: <String>[...g.items, itemId]),
          );
        }
      } else if (g.items.contains(itemId)) {
        await _repo.saveGroup(
          g.copyWith(items: g.items.where((i) => i != itemId).toList()),
        );
      }
    }
    await _reload();
  }

  Future<void> removeItemFromGroup(String groupId, String itemId) async {
    final group = (await _repo.getAllGroups()).where((g) => g.id == groupId);
    if (group.isEmpty) return;
    final g = group.first;
    await _repo.saveGroup(
      g.copyWith(items: g.items.where((i) => i != itemId).toList()),
    );
    await _reload();
  }

  Future<void> toggleExpanded(String id) async {
    final groups = await _repo.getAllGroups();
    for (final g in groups) {
      if (g.id == id) {
        await _repo.saveGroup(g.copyWith(expanded: !g.expanded));
        break;
      }
    }
    await _reload();
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final groups = await _repo.getAllGroups();
    for (final g in groups) {
      if (g.id == id) {
        await _repo.saveGroup(g.copyWith(name: trimmed));
        break;
      }
    }
    await _reload();
  }

  /// Deletes [id] and re-packs the `order` of the remaining same-scope folders.
  Future<void> deleteGroup(String id) async {
    final groups = await _repo.getAllGroups();
    Group? removed;
    for (final g in groups) {
      if (g.id == id) {
        removed = g;
        break;
      }
    }
    if (removed == null) return;
    await _repo.deleteGroup(id);
    final remaining =
        groups
            .where(
              (g) =>
                  g.id != id &&
                  _sameScope(g, removed!.type, removed.assistantId),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i].order != i) {
        await _repo.saveGroup(remaining[i].copyWith(order: i));
      }
    }
    await _reload();
  }

  /// Removes [itemId] from every folder of [type] (cleanup on item deletion).
  Future<void> purgeItem(String itemId, GroupType type) async {
    final groups = await _repo.getAllGroups();
    for (final g in groups) {
      if (g.type == type && g.items.contains(itemId)) {
        await _repo.saveGroup(
          g.copyWith(items: g.items.where((i) => i != itemId).toList()),
        );
      }
    }
    await _reload();
  }
}
