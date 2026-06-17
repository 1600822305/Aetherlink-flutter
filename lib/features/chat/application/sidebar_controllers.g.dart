// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_controllers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application layer backing the chat sidebar's 助手 / 话题 tabs (functional port
/// of the web `TopicManagement` `AssistantTab` / `TopicTab` + their Redux slices
/// `assistantsSlice` / `groupsSlice` / `newMessagesSlice`).
///
/// Three persistent source-of-truth notifiers ([Assistants], [Topics], [Groups],
/// all Drift-backed via [ChatRepository]) plus two in-memory selection notifiers
/// ([CurrentAssistantId], [CurrentTopicId]). The web persists the current
/// selection (`dexieStorage.saveSetting('currentAssistant', …)`); Flutter keeps
/// it in `keepAlive` memory for now (mirrors [FontSizeController]), with the
/// derived [currentAssistant] falling back to the first assistant — matching the
/// web `setCurrentAssistant(defaultAssistants[0])`. Group membership maps are
/// **derived** from [Group.items] (the web persists them separately).
// ── Selection (in-memory, keepAlive) ────────────────────────────────────────
/// The selected assistant id, or `null` to mean "fall back to the first".
/// In-memory like [FontSizeController]; the web persisted this in IndexedDB.

@ProviderFor(CurrentAssistantId)
final currentAssistantIdProvider = CurrentAssistantIdProvider._();

/// Application layer backing the chat sidebar's 助手 / 话题 tabs (functional port
/// of the web `TopicManagement` `AssistantTab` / `TopicTab` + their Redux slices
/// `assistantsSlice` / `groupsSlice` / `newMessagesSlice`).
///
/// Three persistent source-of-truth notifiers ([Assistants], [Topics], [Groups],
/// all Drift-backed via [ChatRepository]) plus two in-memory selection notifiers
/// ([CurrentAssistantId], [CurrentTopicId]). The web persists the current
/// selection (`dexieStorage.saveSetting('currentAssistant', …)`); Flutter keeps
/// it in `keepAlive` memory for now (mirrors [FontSizeController]), with the
/// derived [currentAssistant] falling back to the first assistant — matching the
/// web `setCurrentAssistant(defaultAssistants[0])`. Group membership maps are
/// **derived** from [Group.items] (the web persists them separately).
// ── Selection (in-memory, keepAlive) ────────────────────────────────────────
/// The selected assistant id, or `null` to mean "fall back to the first".
/// In-memory like [FontSizeController]; the web persisted this in IndexedDB.
final class CurrentAssistantIdProvider
    extends $NotifierProvider<CurrentAssistantId, String?> {
  /// Application layer backing the chat sidebar's 助手 / 话题 tabs (functional port
  /// of the web `TopicManagement` `AssistantTab` / `TopicTab` + their Redux slices
  /// `assistantsSlice` / `groupsSlice` / `newMessagesSlice`).
  ///
  /// Three persistent source-of-truth notifiers ([Assistants], [Topics], [Groups],
  /// all Drift-backed via [ChatRepository]) plus two in-memory selection notifiers
  /// ([CurrentAssistantId], [CurrentTopicId]). The web persists the current
  /// selection (`dexieStorage.saveSetting('currentAssistant', …)`); Flutter keeps
  /// it in `keepAlive` memory for now (mirrors [FontSizeController]), with the
  /// derived [currentAssistant] falling back to the first assistant — matching the
  /// web `setCurrentAssistant(defaultAssistants[0])`. Group membership maps are
  /// **derived** from [Group.items] (the web persists them separately).
  // ── Selection (in-memory, keepAlive) ────────────────────────────────────────
  /// The selected assistant id, or `null` to mean "fall back to the first".
  /// In-memory like [FontSizeController]; the web persisted this in IndexedDB.
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
    r'1b53affd18b2ed02131ad4ee9fa788e4a84bd237';

/// Application layer backing the chat sidebar's 助手 / 话题 tabs (functional port
/// of the web `TopicManagement` `AssistantTab` / `TopicTab` + their Redux slices
/// `assistantsSlice` / `groupsSlice` / `newMessagesSlice`).
///
/// Three persistent source-of-truth notifiers ([Assistants], [Topics], [Groups],
/// all Drift-backed via [ChatRepository]) plus two in-memory selection notifiers
/// ([CurrentAssistantId], [CurrentTopicId]). The web persists the current
/// selection (`dexieStorage.saveSetting('currentAssistant', …)`); Flutter keeps
/// it in `keepAlive` memory for now (mirrors [FontSizeController]), with the
/// derived [currentAssistant] falling back to the first assistant — matching the
/// web `setCurrentAssistant(defaultAssistants[0])`. Group membership maps are
/// **derived** from [Group.items] (the web persists them separately).
// ── Selection (in-memory, keepAlive) ────────────────────────────────────────
/// The selected assistant id, or `null` to mean "fall back to the first".
/// In-memory like [FontSizeController]; the web persisted this in IndexedDB.

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

@ProviderFor(CurrentTopicId)
final currentTopicIdProvider = CurrentTopicIdProvider._();

/// The selected topic id, or `null` to mean "fall back to the current
/// assistant's most recent topic". Drives [currentTopic] and the chat view.
final class CurrentTopicIdProvider
    extends $NotifierProvider<CurrentTopicId, String?> {
  /// The selected topic id, or `null` to mean "fall back to the current
  /// assistant's most recent topic". Drives [currentTopic] and the chat view.
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

String _$currentTopicIdHash() => r'd4abe32dd6f1689c0a2b07636144f62b9ae973f7';

/// The selected topic id, or `null` to mean "fall back to the current
/// assistant's most recent topic". Drives [currentTopic] and the chat view.

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

String _$assistantsHash() => r'260cab87a774003f1ea47af12d94ae3573056dae';

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

String _$topicsHash() => r'8222748f3f4462209654debe69cd53b0de0a0791';

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

String _$groupsHash() => r'52b35b8075df0f67e6b0b69efef79fb1e4cd988c';

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

String _$currentAssistantHash() => r'5cfa7c4d57069f2d7686fd81977eeb37409e0915';

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
    r'7b7b6ebe6e90fda7a1a3ff52214310f3468b6dac';

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
    r'135237358bbb3aa931c4ade81e4f525f4f83505d';

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

String _$assistantGroupsHash() => r'840e3dae7baf5c20c58e7f056db356f78e001beb';

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
    r'ec867c6aca3f64b12d9f4bb26c7dfb345f0046c6';

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

String _$topicGroupsHash() => r'2c9af6d46e5583f0515c3e8135b7d7a267ff5ac6';

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
