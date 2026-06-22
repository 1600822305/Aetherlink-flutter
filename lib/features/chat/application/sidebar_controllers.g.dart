// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_controllers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The selected assistant id, or `null` to mean "fall back to the first".
/// Hydrated from persisted storage on build and written through on [set] —
/// the port of the web `dexieStorage.saveSetting('currentAssistant', …)`.

@ProviderFor(CurrentAssistantId)
final currentAssistantIdProvider = CurrentAssistantIdProvider._();

/// The selected assistant id, or `null` to mean "fall back to the first".
/// Hydrated from persisted storage on build and written through on [set] —
/// the port of the web `dexieStorage.saveSetting('currentAssistant', …)`.
final class CurrentAssistantIdProvider
    extends $NotifierProvider<CurrentAssistantId, String?> {
  /// The selected assistant id, or `null` to mean "fall back to the first".
  /// Hydrated from persisted storage on build and written through on [set] —
  /// the port of the web `dexieStorage.saveSetting('currentAssistant', …)`.
  CurrentAssistantIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAssistantIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAssistantIdHash();

  @$internal
  @override
  CurrentAssistantId create() => CurrentAssistantId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentAssistantIdHash() =>
    r'e3a04e9d5a28823d0d2b4eeac3d24646b0c1328f';

/// The selected assistant id, or `null` to mean "fall back to the first".
/// Hydrated from persisted storage on build and written through on [set] —
/// the port of the web `dexieStorage.saveSetting('currentAssistant', …)`.

abstract class _$CurrentAssistantId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The selected topic id, or `null` to mean "fall back to the current
/// assistant's most recent topic". Drives [currentTopic] and the chat view.
/// Hydrated from / written through to persisted storage like
/// [CurrentAssistantId].

@ProviderFor(CurrentTopicId)
final currentTopicIdProvider = CurrentTopicIdProvider._();

/// The selected topic id, or `null` to mean "fall back to the current
/// assistant's most recent topic". Drives [currentTopic] and the chat view.
/// Hydrated from / written through to persisted storage like
/// [CurrentAssistantId].
final class CurrentTopicIdProvider
    extends $NotifierProvider<CurrentTopicId, String?> {
  /// The selected topic id, or `null` to mean "fall back to the current
  /// assistant's most recent topic". Drives [currentTopic] and the chat view.
  /// Hydrated from / written through to persisted storage like
  /// [CurrentAssistantId].
  CurrentTopicIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTopicIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTopicIdHash();

  @$internal
  @override
  CurrentTopicId create() => CurrentTopicId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentTopicIdHash() => r'515ffa84ced42de52354d5bfe33757092f05d7ff';

/// The selected topic id, or `null` to mean "fall back to the current
/// assistant's most recent topic". Drives [currentTopic] and the chat view.
/// Hydrated from / written through to persisted storage like
/// [CurrentAssistantId].

abstract class _$CurrentTopicId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The active sidebar tab index (0 助手 / 1 话题 / 2 设置). Session-only and held
/// purely in memory: it remembers the last tab while the app runs (so reopening
/// the drawer keeps the same tab), but it is **not** persisted, so a full app
/// restart resets to the default 助手 tab. We deliberately diverge from the web
/// (`settings.sidebarTabIndex`), which persisted it across restarts.

@ProviderFor(SidebarTabIndex)
final sidebarTabIndexProvider = SidebarTabIndexProvider._();

/// The active sidebar tab index (0 助手 / 1 话题 / 2 设置). Session-only and held
/// purely in memory: it remembers the last tab while the app runs (so reopening
/// the drawer keeps the same tab), but it is **not** persisted, so a full app
/// restart resets to the default 助手 tab. We deliberately diverge from the web
/// (`settings.sidebarTabIndex`), which persisted it across restarts.
final class SidebarTabIndexProvider
    extends $NotifierProvider<SidebarTabIndex, int> {
  /// The active sidebar tab index (0 助手 / 1 话题 / 2 设置). Session-only and held
  /// purely in memory: it remembers the last tab while the app runs (so reopening
  /// the drawer keeps the same tab), but it is **not** persisted, so a full app
  /// restart resets to the default 助手 tab. We deliberately diverge from the web
  /// (`settings.sidebarTabIndex`), which persisted it across restarts.
  SidebarTabIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidebarTabIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidebarTabIndexHash();

  @$internal
  @override
  SidebarTabIndex create() => SidebarTabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$sidebarTabIndexHash() => r'f769b61d3056bc9a07804b0317790405be3b2aa3';

/// The active sidebar tab index (0 助手 / 1 话题 / 2 设置). Session-only and held
/// purely in memory: it remembers the last tab while the app runs (so reopening
/// the drawer keeps the same tab), but it is **not** persisted, so a full app
/// restart resets to the default 助手 tab. We deliberately diverge from the web
/// (`settings.sidebarTabIndex`), which persisted it across restarts.

abstract class _$SidebarTabIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The persisted 未分组助手 pinyin sort order. Hydrated from / written through to
/// the key/value store so the chosen order survives reopening the drawer and a
/// full app restart.

@ProviderFor(AssistantSortOrderController)
final assistantSortOrderControllerProvider =
    AssistantSortOrderControllerProvider._();

/// The persisted 未分组助手 pinyin sort order. Hydrated from / written through to
/// the key/value store so the chosen order survives reopening the drawer and a
/// full app restart.
final class AssistantSortOrderControllerProvider
    extends
        $NotifierProvider<AssistantSortOrderController, AssistantSortOrder> {
  /// The persisted 未分组助手 pinyin sort order. Hydrated from / written through to
  /// the key/value store so the chosen order survives reopening the drawer and a
  /// full app restart.
  AssistantSortOrderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantSortOrderControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantSortOrderControllerHash();

  @$internal
  @override
  AssistantSortOrderController create() => AssistantSortOrderController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssistantSortOrder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssistantSortOrder>(value),
    );
  }
}

String _$assistantSortOrderControllerHash() =>
    r'4ff9b21f24fc3b1fb428708869ccbd788b62c4b1';

/// The persisted 未分组助手 pinyin sort order. Hydrated from / written through to
/// the key/value store so the chosen order survives reopening the drawer and a
/// full app restart.

abstract class _$AssistantSortOrderController
    extends $Notifier<AssistantSortOrder> {
  AssistantSortOrder build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AssistantSortOrder, AssistantSortOrder>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AssistantSortOrder, AssistantSortOrder>,
              AssistantSortOrder,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A monotonic tick the [ChatController] watches so topic-tab actions that
/// mutate the *current* conversation in place (清空消息) force a reload without
/// changing the selected topic id.

@ProviderFor(ChatRefresh)
final chatRefreshProvider = ChatRefreshProvider._();

/// A monotonic tick the [ChatController] watches so topic-tab actions that
/// mutate the *current* conversation in place (清空消息) force a reload without
/// changing the selected topic id.
final class ChatRefreshProvider extends $NotifierProvider<ChatRefresh, int> {
  /// A monotonic tick the [ChatController] watches so topic-tab actions that
  /// mutate the *current* conversation in place (清空消息) force a reload without
  /// changing the selected topic id.
  ChatRefreshProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRefreshProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRefreshHash();

  @$internal
  @override
  ChatRefresh create() => ChatRefresh();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$chatRefreshHash() => r'ae002d81e55cca37c192116696d66907b1461965';

/// A monotonic tick the [ChatController] watches so topic-tab actions that
/// mutate the *current* conversation in place (清空消息) force a reload without
/// changing the selected topic id.

abstract class _$ChatRefresh extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// All assistants, persisted via Drift. On a truly fresh store (no assistants
/// and no topics) it seeds the two web defaults (默认助手 + 网页分析助手), each with a
/// default topic — the port of `AssistantService.initializeDefaultAssistants()`.

@ProviderFor(Assistants)
final assistantsProvider = AssistantsProvider._();

/// All assistants, persisted via Drift. On a truly fresh store (no assistants
/// and no topics) it seeds the two web defaults (默认助手 + 网页分析助手), each with a
/// default topic — the port of `AssistantService.initializeDefaultAssistants()`.
final class AssistantsProvider
    extends $AsyncNotifierProvider<Assistants, List<Assistant>> {
  /// All assistants, persisted via Drift. On a truly fresh store (no assistants
  /// and no topics) it seeds the two web defaults (默认助手 + 网页分析助手), each with a
  /// default topic — the port of `AssistantService.initializeDefaultAssistants()`.
  AssistantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantsHash();

  @$internal
  @override
  Assistants create() => Assistants();
}

String _$assistantsHash() => r'e7c183e3b57a0ec5acc131cab4b4614abea7277a';

/// All assistants, persisted via Drift. On a truly fresh store (no assistants
/// and no topics) it seeds the two web defaults (默认助手 + 网页分析助手), each with a
/// default topic — the port of `AssistantService.initializeDefaultAssistants()`.

abstract class _$Assistants extends $AsyncNotifier<List<Assistant>> {
  FutureOr<List<Assistant>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Assistant>>, List<Assistant>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Assistant>>, List<Assistant>>,
              AsyncValue<List<Assistant>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// All topics, persisted via Drift. Depends on [Assistants] so seeding (which
/// creates the default topics) always runs first.

@ProviderFor(Topics)
final topicsProvider = TopicsProvider._();

/// All topics, persisted via Drift. Depends on [Assistants] so seeding (which
/// creates the default topics) always runs first.
final class TopicsProvider extends $AsyncNotifierProvider<Topics, List<Topic>> {
  /// All topics, persisted via Drift. Depends on [Assistants] so seeding (which
  /// creates the default topics) always runs first.
  TopicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topicsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topicsHash();

  @$internal
  @override
  Topics create() => Topics();
}

String _$topicsHash() => r'c189e68ce0e614537ce44a686d905a39742f9111';

/// All topics, persisted via Drift. Depends on [Assistants] so seeding (which
/// creates the default topics) always runs first.

abstract class _$Topics extends $AsyncNotifier<List<Topic>> {
  FutureOr<List<Topic>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Topic>>, List<Topic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Topic>>, List<Topic>>,
              AsyncValue<List<Topic>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Assistant folders and topic folders, persisted via Drift — the port of
/// `groupsSlice`. Ungrouped membership is derived from [Group.items], so each
/// item lives in at most one group within its scope.

@ProviderFor(Groups)
final groupsProvider = GroupsProvider._();

/// Assistant folders and topic folders, persisted via Drift — the port of
/// `groupsSlice`. Ungrouped membership is derived from [Group.items], so each
/// item lives in at most one group within its scope.
final class GroupsProvider extends $AsyncNotifierProvider<Groups, List<Group>> {
  /// Assistant folders and topic folders, persisted via Drift — the port of
  /// `groupsSlice`. Ungrouped membership is derived from [Group.items], so each
  /// item lives in at most one group within its scope.
  GroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupsHash();

  @$internal
  @override
  Groups create() => Groups();
}

String _$groupsHash() => r'155f44482ec02f8e98d2892233f3516f733a46d4';

/// Assistant folders and topic folders, persisted via Drift — the port of
/// `groupsSlice`. Ungrouped membership is derived from [Group.items], so each
/// item lives in at most one group within its scope.

abstract class _$Groups extends $AsyncNotifier<List<Group>> {
  FutureOr<List<Group>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Group>>, List<Group>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Group>>, List<Group>>,
              AsyncValue<List<Group>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The current assistant: the selected one, else the first (web fallback
/// `setCurrentAssistant(defaultAssistants[0])`). `null` only when none exist.

@ProviderFor(currentAssistant)
final currentAssistantProvider = CurrentAssistantProvider._();

/// The current assistant: the selected one, else the first (web fallback
/// `setCurrentAssistant(defaultAssistants[0])`). `null` only when none exist.

final class CurrentAssistantProvider
    extends $FunctionalProvider<Assistant?, Assistant?, Assistant?>
    with $Provider<Assistant?> {
  /// The current assistant: the selected one, else the first (web fallback
  /// `setCurrentAssistant(defaultAssistants[0])`). `null` only when none exist.
  CurrentAssistantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAssistantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAssistantHash();

  @$internal
  @override
  $ProviderElement<Assistant?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Assistant? create(Ref ref) {
    return currentAssistant(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Assistant? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Assistant?>(value),
    );
  }
}

String _$currentAssistantHash() => r'5d45ec9a86bcc4ea87736fd92200028bfb89a5a8';

/// The current assistant's topics, sorted pinned-first then most-recent.

@ProviderFor(currentAssistantTopics)
final currentAssistantTopicsProvider = CurrentAssistantTopicsProvider._();

/// The current assistant's topics, sorted pinned-first then most-recent.

final class CurrentAssistantTopicsProvider
    extends $FunctionalProvider<List<Topic>, List<Topic>, List<Topic>>
    with $Provider<List<Topic>> {
  /// The current assistant's topics, sorted pinned-first then most-recent.
  CurrentAssistantTopicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAssistantTopicsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAssistantTopicsHash();

  @$internal
  @override
  $ProviderElement<List<Topic>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Topic> create(Ref ref) {
    return currentAssistantTopics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Topic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Topic>>(value),
    );
  }
}

String _$currentAssistantTopicsHash() =>
    r'88d3e85a7910993e8eec59d0a71ea74fd62a3609';

/// Topic count per assistant id, for the 助手 list's "N 个话题" subtitle.

@ProviderFor(topicCountByAssistant)
final topicCountByAssistantProvider = TopicCountByAssistantProvider._();

/// Topic count per assistant id, for the 助手 list's "N 个话题" subtitle.

final class TopicCountByAssistantProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
  /// Topic count per assistant id, for the 助手 list's "N 个话题" subtitle.
  TopicCountByAssistantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topicCountByAssistantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topicCountByAssistantHash();

  @$internal
  @override
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return topicCountByAssistant(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$topicCountByAssistantHash() =>
    r'ddf4f1807171c38cdc585be7210abffb09b8fee6';

/// Assistant folders, ascending by display order.

@ProviderFor(assistantGroups)
final assistantGroupsProvider = AssistantGroupsProvider._();

/// Assistant folders, ascending by display order.

final class AssistantGroupsProvider
    extends $FunctionalProvider<List<Group>, List<Group>, List<Group>>
    with $Provider<List<Group>> {
  /// Assistant folders, ascending by display order.
  AssistantGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantGroupsHash();

  @$internal
  @override
  $ProviderElement<List<Group>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Group> create(Ref ref) {
    return assistantGroups(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Group> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Group>>(value),
    );
  }
}

String _$assistantGroupsHash() => r'84ba9deb5a6e4a7321e33b8efac8f80f3c2c4b07';

/// Assistants not in any assistant folder ("未分组助手").

@ProviderFor(ungroupedAssistants)
final ungroupedAssistantsProvider = UngroupedAssistantsProvider._();

/// Assistants not in any assistant folder ("未分组助手").

final class UngroupedAssistantsProvider
    extends
        $FunctionalProvider<List<Assistant>, List<Assistant>, List<Assistant>>
    with $Provider<List<Assistant>> {
  /// Assistants not in any assistant folder ("未分组助手").
  UngroupedAssistantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ungroupedAssistantsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ungroupedAssistantsHash();

  @$internal
  @override
  $ProviderElement<List<Assistant>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Assistant> create(Ref ref) {
    return ungroupedAssistants(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Assistant> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Assistant>>(value),
    );
  }
}

String _$ungroupedAssistantsHash() =>
    r'985a30a8bfd49cc43788b4e35d23be2b21b5561d';

/// Topic folders for [assistantId], ascending by display order.

@ProviderFor(topicGroups)
final topicGroupsProvider = TopicGroupsFamily._();

/// Topic folders for [assistantId], ascending by display order.

final class TopicGroupsProvider
    extends $FunctionalProvider<List<Group>, List<Group>, List<Group>>
    with $Provider<List<Group>> {
  /// Topic folders for [assistantId], ascending by display order.
  TopicGroupsProvider._({
    required TopicGroupsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'topicGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$topicGroupsHash();

  @override
  String toString() {
    return r'topicGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<Group>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Group> create(Ref ref) {
    final argument = this.argument as String;
    return topicGroups(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Group> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Group>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TopicGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$topicGroupsHash() => r'1ddbfa6558b6ff93fceab4ee9972f1b5ad86ab71';

/// Topic folders for [assistantId], ascending by display order.

final class TopicGroupsFamily extends $Family
    with $FunctionalFamilyOverride<List<Group>, String> {
  TopicGroupsFamily._()
    : super(
        retry: null,
        name: r'topicGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Topic folders for [assistantId], ascending by display order.

  TopicGroupsProvider call(String assistantId) =>
      TopicGroupsProvider._(argument: assistantId, from: this);

  @override
  String toString() => r'topicGroupsProvider';
}

/// The current assistant's topics not in any of its topic folders ("未分组话题").

@ProviderFor(ungroupedTopics)
final ungroupedTopicsProvider = UngroupedTopicsProvider._();

/// The current assistant's topics not in any of its topic folders ("未分组话题").

final class UngroupedTopicsProvider
    extends $FunctionalProvider<List<Topic>, List<Topic>, List<Topic>>
    with $Provider<List<Topic>> {
  /// The current assistant's topics not in any of its topic folders ("未分组话题").
  UngroupedTopicsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ungroupedTopicsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ungroupedTopicsHash();

  @$internal
  @override
  $ProviderElement<List<Topic>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Topic> create(Ref ref) {
    return ungroupedTopics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Topic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Topic>>(value),
    );
  }
}

String _$ungroupedTopicsHash() => r'1d8076cc5aac583cf55f18d33b2278b62a3e5c6f';
