import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

part 'sidebar_selection_providers.g.dart';

/// Storage keys for the persisted sidebar selection / tab (port of the web
/// `dexieStorage` setting keys).
const String kCurrentAssistantSettingKey = 'currentAssistant';
const String kCurrentTopicSettingKey = 'currentTopic';
const String kAssistantSortOrderSettingKey = 'assistantSortOrder';
const String kSidebarTabIndexSettingKey = 'sidebarTabIndex';

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
/// assistant's most recent topic". Drives `currentTopic` and the chat view.
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

/// The active sidebar tab index (0 助手 / 1 话题 / 2 设置). Persisted like the web
/// (`settings.sidebarTabIndex`): hydrated from the key/value store on build and
/// written through on [set], so the tab survives both reopening the drawer and
/// a full app restart.
@Riverpod(keepAlive: true)
class SidebarTabIndex extends _$SidebarTabIndex {
  bool _touched = false;

  @override
  int build() {
    _hydrate();
    return 0;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kSidebarTabIndexSettingKey);
    final index = int.tryParse(stored ?? '');
    if (!_touched && index != null && index >= 0 && index <= 3) {
      state = index;
    }
  }

  void set(int index) {
    // 0=助手 1=话题 [2=笔记] last=设置; the 笔记 Tab is optional so the max
    // valid index is 3 when it is enabled.
    if (index < 0 || index > 3) return;
    _touched = true;
    state = index;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kSidebarTabIndexSettingKey, '$index');
  }
}

/// The 未分组助手 list ordering: [none] keeps the persisted insertion order,
/// while [asc] / [desc] sort by pinyin — the port of the web's
/// 按拼音升序排列 / 按拼音降序排列 (`handleSortByPinyinAsc` / `…Desc`).
enum AssistantSortOrder {
  none('none'),
  asc('asc'),
  desc('desc');

  const AssistantSortOrder(this.id);
  final String id;

  static AssistantSortOrder fromId(String? id) {
    for (final order in values) {
      if (order.id == id) return order;
    }
    return none;
  }
}

/// The persisted 未分组助手 pinyin sort order. Hydrated from / written through to
/// the key/value store so the chosen order survives reopening the drawer and a
/// full app restart.
@Riverpod(keepAlive: true)
class AssistantSortOrderController extends _$AssistantSortOrderController {
  @override
  AssistantSortOrder build() {
    _hydrate();
    return AssistantSortOrder.none;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(chatRepositoryProvider)
        .getSetting(kAssistantSortOrderSettingKey);
    if (stored != null && stored.isNotEmpty) {
      state = AssistantSortOrder.fromId(stored);
    }
  }

  void set(AssistantSortOrder order) {
    state = order;
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kAssistantSortOrderSettingKey, order.id);
  }
}

/// A monotonic tick the `ChatController` watches so topic-tab actions that
/// mutate the *current* conversation in place (清空消息) force a reload without
/// changing the selected topic id.
@Riverpod(keepAlive: true)
class ChatRefresh extends _$ChatRefresh {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
