// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application-layer DI seam + read view-models that back the M4.2.0 ChatPage
/// skeleton.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] and never imports `data` (Rule 1). Everything below
/// is the composition that makes those reads real — the M1 persistence stack
/// (Drift [AppDatabase] → [ChatRepositoryImpl]) wired up behind the
/// [ChatRepository] port, with no mocks. An empty database yields an empty
/// list, which the page renders as its empty state.
///
/// Sending, streaming, block rendering and topic selection are later slices
/// (M4.2.1+); this file intentionally exposes only `Future` reads.
/// The single app-wide Drift database (composition root in `core/database`).
/// Kept alive for the app's lifetime and closed when the container disposes.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Application-layer DI seam + read view-models that back the M4.2.0 ChatPage
/// skeleton.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] and never imports `data` (Rule 1). Everything below
/// is the composition that makes those reads real — the M1 persistence stack
/// (Drift [AppDatabase] → [ChatRepositoryImpl]) wired up behind the
/// [ChatRepository] port, with no mocks. An empty database yields an empty
/// list, which the page renders as its empty state.
///
/// Sending, streaming, block rendering and topic selection are later slices
/// (M4.2.1+); this file intentionally exposes only `Future` reads.
/// The single app-wide Drift database (composition root in `core/database`).
/// Kept alive for the app's lifetime and closed when the container disposes.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Application-layer DI seam + read view-models that back the M4.2.0 ChatPage
  /// skeleton.
  ///
  /// The page is a pure view: it watches [chatMessagesProvider] /
  /// [currentTopicProvider] and never imports `data` (Rule 1). Everything below
  /// is the composition that makes those reads real — the M1 persistence stack
  /// (Drift [AppDatabase] → [ChatRepositoryImpl]) wired up behind the
  /// [ChatRepository] port, with no mocks. An empty database yields an empty
  /// list, which the page renders as its empty state.
  ///
  /// Sending, streaming, block rendering and topic selection are later slices
  /// (M4.2.1+); this file intentionally exposes only `Future` reads.
  /// The single app-wide Drift database (composition root in `core/database`).
  /// Kept alive for the app's lifetime and closed when the container disposes.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'365ef3f215d780c29a21b6328f0b547a8363c6a6';

/// The chat persistence port, backed by Drift. Upper layers depend on the
/// [ChatRepository] interface; this provider is the one place the `data`
/// implementation is wired in.

@ProviderFor(chatRepository)
final chatRepositoryProvider = ChatRepositoryProvider._();

/// The chat persistence port, backed by Drift. Upper layers depend on the
/// [ChatRepository] interface; this provider is the one place the `data`
/// implementation is wired in.

final class ChatRepositoryProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  /// The chat persistence port, backed by Drift. Upper layers depend on the
  /// [ChatRepository] interface; this provider is the one place the `data`
  /// implementation is wired in.
  ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return chatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$chatRepositoryHash() => r'34392e2d116c2a4deefb88f3764971d53b1f2bd1';

/// The topic whose conversation the page shows. The skeleton has no topic
/// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
/// when the database is empty — which it is on a fresh install.

@ProviderFor(currentTopic)
final currentTopicProvider = CurrentTopicProvider._();

/// The topic whose conversation the page shows. The skeleton has no topic
/// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
/// when the database is empty — which it is on a fresh install.

final class CurrentTopicProvider
    extends $FunctionalProvider<AsyncValue<Topic?>, Topic?, FutureOr<Topic?>>
    with $FutureModifier<Topic?>, $FutureProvider<Topic?> {
  /// The topic whose conversation the page shows. The skeleton has no topic
  /// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
  /// when the database is empty — which it is on a fresh install.
  CurrentTopicProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTopicProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTopicHash();

  @$internal
  @override
  $FutureProviderElement<Topic?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Topic?> create(Ref ref) {
    return currentTopic(ref);
  }
}

String _$currentTopicHash() => r'f2aa62595ac3d2a2c84f7eaab6c9d59128687620';

/// Messages for the [currentTopic], as stored. No current topic (empty
/// database) → an empty list → the page's empty state. This is the ChatPage's
/// "About-page moment": proof the presentation → application → repository →
/// Drift pipeline is connected, even with nothing to show yet.

@ProviderFor(chatMessages)
final chatMessagesProvider = ChatMessagesProvider._();

/// Messages for the [currentTopic], as stored. No current topic (empty
/// database) → an empty list → the page's empty state. This is the ChatPage's
/// "About-page moment": proof the presentation → application → repository →
/// Drift pipeline is connected, even with nothing to show yet.

final class ChatMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Message>>,
          List<Message>,
          FutureOr<List<Message>>
        >
    with $FutureModifier<List<Message>>, $FutureProvider<List<Message>> {
  /// Messages for the [currentTopic], as stored. No current topic (empty
  /// database) → an empty list → the page's empty state. This is the ChatPage's
  /// "About-page moment": proof the presentation → application → repository →
  /// Drift pipeline is connected, even with nothing to show yet.
  ChatMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatMessagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatMessagesHash();

  @$internal
  @override
  $FutureProviderElement<List<Message>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Message>> create(Ref ref) {
    return chatMessages(ref);
  }
}

String _$chatMessagesHash() => r'd327094d9e31435c403b266eca1d7f876f180c12';
