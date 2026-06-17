import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/assistant_presets.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'sidebar_controllers.g.dart';

/// Application layer backing the chat sidebar's 助手 / 话题 tabs (functional port
/// of the web `TopicManagement` `AssistantTab` / `TopicTab` + their Redux slices
/// `assistantsSlice` / `groupsSlice` / `newMessagesSlice`).
///
/// Three persistent source-of-truth notifiers ([Assistants], [Topics], [Groups],
/// all Drift-backed via [ChatRepository]) plus two `keepAlive` selection
/// notifiers ([CurrentAssistantId], [CurrentTopicId]) and the sidebar tab index
/// ([SidebarTabIndex]). Like the web (`dexieStorage.saveSetting('currentAssistant',
/// …)` / `setSidebarTabIndex`), these are persisted via [ChatRepository]'s
/// key/value settings: each notifier hydrates from storage on first build and
/// writes through on every change, so the selection and active tab survive both
/// reopening the drawer and a full app restart. The derived [currentAssistant]
/// still falls back to the first assistant when nothing is selected — matching
/// the web `setCurrentAssistant(defaultAssistants[0])`. Group membership maps
/// are **derived** from [Group.items] (the web persists them separately).

/// Storage keys for the persisted sidebar selection / tab (port of the web
/// `dexieStorage` setting keys).
const String kCurrentAssistantSettingKey = 'currentAssistant';
const String kCurrentTopicSettingKey = 'currentTopic';
const String kSidebarTabIndexSettingKey = 'sidebarTabIndex';

// ── Selection (keepAlive, persisted) ─────────────────────────────────────────

/// The selected assistant id, or `null` to mean "fall back to the first".
/// Hydrated from persisted storage on build and written through on [set] —
/// the port of the web `dexieStorage.saveSetting('currentAssistant', …)`.
@Riverpod(keepAlive: true)
class CurrentAssistantId extends _$CurrentAssistantId {
  @override
  String? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kCurrentAssistantSettingKey);
    if (stored != null && stored.isNotEmpty) state = stored;
  }

  void set(String? id) {
    state = id;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kCurrentAssistantSettingKey, id ?? '');
  }
}

/// The selected topic id, or `null` to mean "fall back to the current
/// assistant's most recent topic". Drives [currentTopic] and the chat view.
/// Hydrated from / written through to persisted storage like
/// [CurrentAssistantId].
@Riverpod(keepAlive: true)
class CurrentTopicId extends _$CurrentTopicId {
  @override
  String? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kCurrentTopicSettingKey);
    if (stored != null && stored.isNotEmpty) state = stored;
  }

  void set(String? id) {
    state = id;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kCurrentTopicSettingKey, id ?? '');
  }
}

/// The active sidebar tab index (0 助手 / 1 话题 / 2 设置). Hydrated from / written
/// through to persisted storage so the last tab is restored on reopening the
/// drawer and on app restart — the port of the web `settings.sidebarTabIndex`
/// (`setSidebarTabIndex`).
@Riverpod(keepAlive: true)
class SidebarTabIndex extends _$SidebarTabIndex {
  @override
  int build() {
    _hydrate();
    return 0;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kSidebarTabIndexSettingKey);
    final parsed = int.tryParse(stored ?? '');
    if (parsed != null && parsed >= 0 && parsed <= 2) state = parsed;
  }

  void set(int index) {
    if (index < 0 || index > 2) return;
    state = index;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kSidebarTabIndexSettingKey, '$index');
  }
}

/// A monotonic tick the [ChatController] watches so topic-tab actions that
/// mutate the *current* conversation in place (清空消息) force a reload without
/// changing the selected topic id.
@Riverpod(keepAlive: true)
class ChatRefresh extends _$ChatRefresh {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

// ── Assistants ──────────────────────────────────────────────────────────────

/// All assistants, persisted via Drift. On a truly fresh store (no assistants
/// and no topics) it seeds the two web defaults (默认助手 + 网页分析助手), each with a
/// default topic — the port of `AssistantService.initializeDefaultAssistants()`.
@Riverpod(keepAlive: true)
class Assistants extends _$Assistants {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<Assistant>> build() async {
    final existing = await _repo.getAllAssistants();
    if (existing.isNotEmpty) return existing;
    // Only seed a pristine store; never seed over pre-existing topics.
    final topics = await _repo.getAllTopics();
    if (topics.isNotEmpty) return existing;
    return _seed();
  }

  Future<List<Assistant>> _seed() async {
    final now = DateTime.now();
    final defaultId = generateId('assistant');
    final webId = generateId('assistant');
    final defaultTopicId = generateId('topic');
    final webTopicId = generateId('topic');

    final defaultAssistant = Assistant(
      id: defaultId,
      name: '默认助手',
      description: '通用型AI助手，可以回答各种问题',
      systemPrompt: kDefaultAssistantPrompt,
      isSystem: true,
      type: 'assistant',
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[defaultTopicId],
    );
    final webAssistant = Assistant(
      id: webId,
      name: '网页分析助手',
      description: '帮助分析各种网页内容',
      systemPrompt: kWebAnalysisPrompt,
      isSystem: true,
      type: 'assistant',
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[webTopicId],
    );

    await _repo.saveAssistant(defaultAssistant);
    await _repo.saveAssistant(webAssistant);
    await _repo.saveTopic(
      newDefaultTopic(id: defaultTopicId, assistantId: defaultId, now: now),
    );
    await _repo.saveTopic(
      newDefaultTopic(id: webTopicId, assistantId: webId, now: now),
    );

    return <Assistant>[defaultAssistant, webAssistant];
  }

  Future<void> _reload() async {
    state = AsyncData<List<Assistant>>(await _repo.getAllAssistants());
  }

  /// Adds a picker [preset] as a new user assistant (fresh id, `isSystem:false`)
  /// with a default topic, then selects it — the port of `onAddAssistant`.
  Future<void> addPreset(Assistant preset) async {
    final now = DateTime.now();
    final id = generateId('assistant');
    final topicId = generateId('topic');
    final assistant = preset.copyWith(
      id: id,
      isSystem: false,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[topicId],
    );
    await _repo.saveAssistant(assistant);
    await _repo.saveTopic(
      newDefaultTopic(id: topicId, assistantId: id, now: now),
    );
    await _reload();
    ref.read(currentAssistantIdProvider.notifier).set(id);
    ref.read(currentTopicIdProvider.notifier).set(topicId);
  }

  /// Duplicates [source] as "名称 (复制)" with its own default topic.
  Future<void> copy(Assistant source) async {
    final now = DateTime.now();
    final id = generateId('assistant');
    final topicId = generateId('topic');
    final assistant = source.copyWith(
      id: id,
      name: '${source.name} (复制)',
      isSystem: false,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
      topicIds: <String>[topicId],
    );
    await _repo.saveAssistant(assistant);
    await _repo.saveTopic(
      newDefaultTopic(id: topicId, assistantId: id, now: now),
    );
    await _reload();
  }

  /// Deletes [id] and its topics; if it was current, selects the next remaining
  /// assistant (or `null` when none remain) — the port of `handleDeleteAssistant`.
  Future<void> delete(String id) async {
    final all = await _repo.getAllAssistants();
    final topics = await _repo.getAllTopics();
    for (final topic in topics) {
      if (topic.assistantId == id) {
        await _repo.deleteTopic(topic.id);
      }
    }
    await _repo.deleteAssistant(id);
    await ref.read(groupsProvider.notifier).purgeItem(id, GroupType.assistant);
    await _reload();

    final currentId = ref.read(currentAssistantIdProvider);
    final effectiveCurrent = currentId ?? (all.isEmpty ? null : all.first.id);
    if (effectiveCurrent == id) {
      final remaining = all.where((a) => a.id != id).toList();
      ref
          .read(currentAssistantIdProvider.notifier)
          .set(remaining.isEmpty ? null : remaining.first.id);
      ref.read(currentTopicIdProvider.notifier).set(null);
    }
  }

  /// Removes every topic of [assistantId] — the port of 清空话题.
  Future<void> clearTopics(String assistantId) async {
    final topics = await _repo.getAllTopics();
    for (final topic in topics) {
      if (topic.assistantId == assistantId) {
        await _repo.deleteTopic(topic.id);
      }
    }
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant != null) {
      await _repo.saveAssistant(assistant.copyWith(topicIds: const <String>[]));
    }
    // Resolve "current" via [currentAssistantIdProvider], NOT the derived
    // [currentAssistant] — the latter watches [assistantsProvider], so reading
    // it from this notifier throws a CircularDependencyError that aborts the
    // method before [_reload], leaving the UI stale (the 清空话题 lag bug).
    final selectedId = ref.read(currentAssistantIdProvider);
    await _reload();
    // [Topics] watches [assistantsProvider], so [_reload] above rebuilds it,
    // which refreshes the 话题数 / 话题列表 views.
    final all = state.asData?.value ?? const <Assistant>[];
    final effectiveCurrentId =
        selectedId ?? (all.isEmpty ? null : all.first.id);
    if (effectiveCurrentId == assistantId) {
      ref.read(currentTopicIdProvider.notifier).set(null);
    }
  }
}

// ── Topics ──────────────────────────────────────────────────────────────────

/// All topics, persisted via Drift. Depends on [Assistants] so seeding (which
/// creates the default topics) always runs first.
@Riverpod(keepAlive: true)
class Topics extends _$Topics {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<Topic>> build() async {
    await ref.watch(assistantsProvider.future);
    return _repo.getAllTopics();
  }

  Future<void> _reload() async {
    state = AsyncData<List<Topic>>(await _repo.getAllTopics());
  }

  List<Topic> _topicsOf(String assistantId, List<Topic> all) {
    final mine = all.where((t) => t.assistantId == assistantId).toList();
    mine.sort(compareTopicsByRecency);
    return mine;
  }

  /// Creates a fresh "新的对话" for [assistantId] and selects it — the port of
  /// `handleCreateTopic` (which unshifts; our views sort by recency so the new
  /// topic naturally surfaces at the top).
  Future<Topic> create(String assistantId) async {
    final now = DateTime.now();
    final topic = newDefaultTopic(
      id: generateId('topic'),
      assistantId: assistantId,
      now: now,
    );
    await _repo.saveTopic(topic);
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant != null) {
      await _repo.saveAssistant(
        assistant.copyWith(topicIds: <String>[topic.id, ...assistant.topicIds]),
      );
    }
    await _reload();
    ref.read(currentTopicIdProvider.notifier).set(topic.id);
    return topic;
  }

  /// Selects [assistantId]'s most recent topic, creating one if it has none.
  Future<void> selectFirstOrCreate(String assistantId) async {
    final mine = _topicsOf(assistantId, await _repo.getAllTopics());
    if (mine.isNotEmpty) {
      ref.read(currentTopicIdProvider.notifier).set(mine.first.id);
    } else {
      await create(assistantId);
    }
  }

  /// Deletes [id]; if it was the current topic, selects the adjacent sibling
  /// (next, else previous, else none) — the port of `handleDeleteTopic`.
  Future<void> delete(String id) async {
    final all = await _repo.getAllTopics();
    Topic? target;
    for (final t in all) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    final wasCurrent = ref.read(currentTopicIdProvider) == id;
    await _repo.deleteTopic(id);
    await ref.read(groupsProvider.notifier).purgeItem(id, GroupType.topic);

    if (wasCurrent && target != null) {
      final siblings = _topicsOf(target.assistantId, all);
      final idx = siblings.indexWhere((t) => t.id == id);
      String? next;
      if (siblings.length > 1 && idx != -1) {
        next = idx < siblings.length - 1
            ? siblings[idx + 1].id
            : siblings[idx - 1].id;
      }
      ref.read(currentTopicIdProvider.notifier).set(next);
    }
    await _reload();
  }

  /// Toggles 固定/取消固定; pinned topics sort first.
  Future<void> togglePin(String id) async {
    final topic = await _repo.getTopic(id);
    if (topic == null) return;
    await _repo.saveTopic(
      topic.copyWith(pinned: !topic.pinned, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  /// Renames [id] (编辑话题, name only — Flutter's [Topic] has no `prompt`).
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final topic = await _repo.getTopic(id);
    if (topic == null) return;
    await _repo.saveTopic(
      topic.copyWith(
        name: trimmed,
        isNameManuallyEdited: true,
        updatedAt: DateTime.now(),
      ),
    );
    await _reload();
  }

  /// Clears every message of [id] (清空消息). Flutter has no `clearTopicContent`
  /// repo method, so it deletes the messages (each cascades its blocks).
  Future<void> clearMessages(String id) async {
    final messages = await _repo.getMessagesByTopicId(id);
    for (final message in messages) {
      await _repo.deleteMessage(message.id);
    }
    final topic = await _repo.getTopic(id);
    if (topic != null) {
      await _repo.saveTopic(
        topic.copyWith(
          messageIds: const <String>[],
          lastMessagePreview: null,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _reload();
    if (ref.read(currentTopicIdProvider) == id) {
      ref.read(chatRefreshProvider.notifier).bump();
    }
  }

  /// Moves [topicId] to [targetAssistantId] (移动到…). If it was current, the
  /// selection falls back to the current assistant's recent topic.
  Future<void> move(String topicId, String targetAssistantId) async {
    final topic = await _repo.getTopic(topicId);
    if (topic == null || topic.assistantId == targetAssistantId) return;
    final source = await _repo.getAssistant(topic.assistantId);
    if (source != null) {
      await _repo.saveAssistant(
        source.copyWith(
          topicIds: source.topicIds.where((t) => t != topicId).toList(),
        ),
      );
    }
    await _repo.saveTopic(
      topic.copyWith(assistantId: targetAssistantId, updatedAt: DateTime.now()),
    );
    final target = await _repo.getAssistant(targetAssistantId);
    if (target != null && !target.topicIds.contains(topicId)) {
      await _repo.saveAssistant(
        target.copyWith(topicIds: <String>[topicId, ...target.topicIds]),
      );
    }
    if (ref.read(currentTopicIdProvider) == topicId) {
      ref.read(currentTopicIdProvider.notifier).set(null);
    }
    await _reload();
  }
}

// ── Groups ──────────────────────────────────────────────────────────────────

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

// ── Derived read views ───────────────────────────────────────────────────────

/// The current assistant: the selected one, else the first (web fallback
/// `setCurrentAssistant(defaultAssistants[0])`). `null` only when none exist.
@riverpod
Assistant? currentAssistant(Ref ref) {
  final list =
      ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[];
  if (list.isEmpty) return null;
  final id = ref.watch(currentAssistantIdProvider);
  if (id != null) {
    for (final a in list) {
      if (a.id == id) return a;
    }
  }
  return list.first;
}

/// The current assistant's topics, sorted pinned-first then most-recent.
@riverpod
List<Topic> currentAssistantTopics(Ref ref) {
  final assistant = ref.watch(currentAssistantProvider);
  if (assistant == null) return const <Topic>[];
  final topics = ref.watch(topicsProvider).asData?.value ?? const <Topic>[];
  final mine = topics.where((t) => t.assistantId == assistant.id).toList();
  mine.sort(compareTopicsByRecency);
  return mine;
}

/// Topic count per assistant id, for the 助手 list's "N 个话题" subtitle.
@riverpod
Map<String, int> topicCountByAssistant(Ref ref) {
  final topics = ref.watch(topicsProvider).asData?.value ?? const <Topic>[];
  final counts = <String, int>{};
  for (final t in topics) {
    counts[t.assistantId] = (counts[t.assistantId] ?? 0) + 1;
  }
  return counts;
}

/// Assistant folders, ascending by display order.
@riverpod
List<Group> assistantGroups(Ref ref) {
  final groups = ref.watch(groupsProvider).asData?.value ?? const <Group>[];
  final list = groups.where((g) => g.type == GroupType.assistant).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return list;
}

/// Assistants not in any assistant folder ("未分组助手").
@riverpod
List<Assistant> ungroupedAssistants(Ref ref) {
  final assistants =
      ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[];
  final grouped = <String>{
    for (final g in ref.watch(assistantGroupsProvider)) ...g.items,
  };
  return assistants.where((a) => !grouped.contains(a.id)).toList();
}

/// Topic folders for [assistantId], ascending by display order.
@riverpod
List<Group> topicGroups(Ref ref, String assistantId) {
  final groups = ref.watch(groupsProvider).asData?.value ?? const <Group>[];
  final list =
      groups
          .where(
            (g) => g.type == GroupType.topic && g.assistantId == assistantId,
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  return list;
}

/// The current assistant's topics not in any of its topic folders ("未分组话题").
@riverpod
List<Topic> ungroupedTopics(Ref ref) {
  final assistant = ref.watch(currentAssistantProvider);
  if (assistant == null) return const <Topic>[];
  final grouped = <String>{
    for (final g in ref.watch(topicGroupsProvider(assistant.id))) ...g.items,
  };
  return ref
      .watch(currentAssistantTopicsProvider)
      .where((t) => !grouped.contains(t.id))
      .toList();
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// A blank topic seeded like the web `getDefaultTopic`: name "新的对话",
/// `lastMessageTime` = now (ISO), no messages.
Topic newDefaultTopic({
  required String id,
  required String assistantId,
  required DateTime now,
}) => Topic(
  id: id,
  assistantId: assistantId,
  name: '新的对话',
  createdAt: now,
  updatedAt: now,
  lastMessageTime: now.toIso8601String(),
);

/// Sort comparator matching the web `sortedTopics`: pinned first, then by
/// `lastMessageTime || updatedAt || createdAt` descending.
int compareTopicsByRecency(Topic a, Topic b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  return _topicMillis(b).compareTo(_topicMillis(a));
}

int _topicMillis(Topic t) {
  final last = t.lastMessageTime;
  if (last != null) {
    final parsed = DateTime.tryParse(last);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return t.updatedAt.millisecondsSinceEpoch;
}
