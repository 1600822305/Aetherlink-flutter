// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application-layer DI seam + read view-models that back the ChatPage.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] / [messageBlocksProvider] and never imports `data`
/// (Rule 1). Everything below is the composition that makes those reads real —
/// the M1 persistence stack (Drift [AppDatabase] → [ChatRepositoryImpl]) wired
/// up behind the [ChatRepository] port, with no mocks. An empty database yields
/// an empty list, which the page renders as its empty state.
///
/// M4.2.1 renders stored `main_text` blocks as bubbles, so this file gains a
/// per-message block read ([messageBlocks]) and a debug-only seed
/// ([debugChatSeed]) so the bubbles are visible before sending/streaming land.
/// Sending, streaming, the other 14 block variants and markdown are later
/// slices; this file intentionally exposes only `Future` reads.
/// The single app-wide Drift database (composition root in `core/database`).
/// Kept alive for the app's lifetime and closed when the container disposes.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Application-layer DI seam + read view-models that back the ChatPage.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] / [messageBlocksProvider] and never imports `data`
/// (Rule 1). Everything below is the composition that makes those reads real —
/// the M1 persistence stack (Drift [AppDatabase] → [ChatRepositoryImpl]) wired
/// up behind the [ChatRepository] port, with no mocks. An empty database yields
/// an empty list, which the page renders as its empty state.
///
/// M4.2.1 renders stored `main_text` blocks as bubbles, so this file gains a
/// per-message block read ([messageBlocks]) and a debug-only seed
/// ([debugChatSeed]) so the bubbles are visible before sending/streaming land.
/// Sending, streaming, the other 14 block variants and markdown are later
/// slices; this file intentionally exposes only `Future` reads.
/// The single app-wide Drift database (composition root in `core/database`).
/// Kept alive for the app's lifetime and closed when the container disposes.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Application-layer DI seam + read view-models that back the ChatPage.
  ///
  /// The page is a pure view: it watches [chatMessagesProvider] /
  /// [currentTopicProvider] / [messageBlocksProvider] and never imports `data`
  /// (Rule 1). Everything below is the composition that makes those reads real —
  /// the M1 persistence stack (Drift [AppDatabase] → [ChatRepositoryImpl]) wired
  /// up behind the [ChatRepository] port, with no mocks. An empty database yields
  /// an empty list, which the page renders as its empty state.
  ///
  /// M4.2.1 renders stored `main_text` blocks as bubbles, so this file gains a
  /// per-message block read ([messageBlocks]) and a debug-only seed
  /// ([debugChatSeed]) so the bubbles are visible before sending/streaming land.
  /// Sending, streaming, the other 14 block variants and markdown are later
  /// slices; this file intentionally exposes only `Future` reads.
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

/// The LLM gateway factory port, backed by the protocol-selecting
/// `LlmProviderFactory` (M2 `data`) with a runtime `dio`. The [ChatController]
/// depends only on the [LlmGatewayFactory] interface; tests override this with
/// a fake factory (and a fake gateway) so the closed loop runs without a
/// network or a real key.

@ProviderFor(llmGatewayFactory)
final llmGatewayFactoryProvider = LlmGatewayFactoryProvider._();

/// The LLM gateway factory port, backed by the protocol-selecting
/// `LlmProviderFactory` (M2 `data`) with a runtime `dio`. The [ChatController]
/// depends only on the [LlmGatewayFactory] interface; tests override this with
/// a fake factory (and a fake gateway) so the closed loop runs without a
/// network or a real key.

final class LlmGatewayFactoryProvider
    extends
        $FunctionalProvider<
          LlmGatewayFactory,
          LlmGatewayFactory,
          LlmGatewayFactory
        >
    with $Provider<LlmGatewayFactory> {
  /// The LLM gateway factory port, backed by the protocol-selecting
  /// `LlmProviderFactory` (M2 `data`) with a runtime `dio`. The [ChatController]
  /// depends only on the [LlmGatewayFactory] interface; tests override this with
  /// a fake factory (and a fake gateway) so the closed loop runs without a
  /// network or a real key.
  LlmGatewayFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmGatewayFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmGatewayFactoryHash();

  @$internal
  @override
  $ProviderElement<LlmGatewayFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LlmGatewayFactory create(Ref ref) {
    return llmGatewayFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmGatewayFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmGatewayFactory>(value),
    );
  }
}

String _$llmGatewayFactoryHash() => r'68cc9fbd6419097c4c41772c43542368e4c310c2';

/// Debug-only seed so message rendering is visible before send/streaming exist
/// (M4.2.2+). In release builds ([kDebugMode] false) this is a no-op, so the
/// read pipeline behaves exactly as before. It is idempotent — it writes
/// nothing once any topic exists — and it goes through the real
/// [ChatRepository] (no fabricated widget-level bubbles): a topic, a user
/// message + `main_text` block, and an assistant message + `main_text` block,
/// which then flow back out through [getMessageBlocksByMessageId] like any
/// real conversation.

@ProviderFor(debugChatSeed)
final debugChatSeedProvider = DebugChatSeedProvider._();

/// Debug-only seed so message rendering is visible before send/streaming exist
/// (M4.2.2+). In release builds ([kDebugMode] false) this is a no-op, so the
/// read pipeline behaves exactly as before. It is idempotent — it writes
/// nothing once any topic exists — and it goes through the real
/// [ChatRepository] (no fabricated widget-level bubbles): a topic, a user
/// message + `main_text` block, and an assistant message + `main_text` block,
/// which then flow back out through [getMessageBlocksByMessageId] like any
/// real conversation.

final class DebugChatSeedProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Debug-only seed so message rendering is visible before send/streaming exist
  /// (M4.2.2+). In release builds ([kDebugMode] false) this is a no-op, so the
  /// read pipeline behaves exactly as before. It is idempotent — it writes
  /// nothing once any topic exists — and it goes through the real
  /// [ChatRepository] (no fabricated widget-level bubbles): a topic, a user
  /// message + `main_text` block, and an assistant message + `main_text` block,
  /// which then flow back out through [getMessageBlocksByMessageId] like any
  /// real conversation.
  DebugChatSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'debugChatSeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$debugChatSeedHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return debugChatSeed(ref);
  }
}

String _$debugChatSeedHash() => r'84e8af54f21c912ea3a3c54e185c2683a4e7a277';

/// The topic whose conversation the page shows. The skeleton has no topic
/// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
/// when the database is empty — which it is on a fresh install. The debug seed
/// runs first so a conversation exists to render in debug builds.

@ProviderFor(currentTopic)
final currentTopicProvider = CurrentTopicProvider._();

/// The topic whose conversation the page shows. The skeleton has no topic
/// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
/// when the database is empty — which it is on a fresh install. The debug seed
/// runs first so a conversation exists to render in debug builds.

final class CurrentTopicProvider
    extends $FunctionalProvider<AsyncValue<Topic?>, Topic?, FutureOr<Topic?>>
    with $FutureModifier<Topic?>, $FutureProvider<Topic?> {
  /// The topic whose conversation the page shows. The skeleton has no topic
  /// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
  /// when the database is empty — which it is on a fresh install. The debug seed
  /// runs first so a conversation exists to render in debug builds.
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

String _$currentTopicHash() => r'c32b9672c82e0f9ddc34d454d0bf276d2aa2aa50';

/// Messages for the [currentTopic], as stored. No current topic (empty
/// database) → an empty list → the page's empty state. This is the ChatPage's
/// "About-page moment": proof the presentation → application → repository →
/// Drift pipeline is connected.

@ProviderFor(chatMessages)
final chatMessagesProvider = ChatMessagesProvider._();

/// Messages for the [currentTopic], as stored. No current topic (empty
/// database) → an empty list → the page's empty state. This is the ChatPage's
/// "About-page moment": proof the presentation → application → repository →
/// Drift pipeline is connected.

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
  /// Drift pipeline is connected.
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

/// The blocks for a single message, in stored order, read through the real
/// [ChatRepository.getMessageBlocksByMessageId]. M4.2.1 renders only the
/// `main_text` blocks among them; the other variants are later slices.

@ProviderFor(messageBlocks)
final messageBlocksProvider = MessageBlocksFamily._();

/// The blocks for a single message, in stored order, read through the real
/// [ChatRepository.getMessageBlocksByMessageId]. M4.2.1 renders only the
/// `main_text` blocks among them; the other variants are later slices.

final class MessageBlocksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MessageBlock>>,
          List<MessageBlock>,
          FutureOr<List<MessageBlock>>
        >
    with
        $FutureModifier<List<MessageBlock>>,
        $FutureProvider<List<MessageBlock>> {
  /// The blocks for a single message, in stored order, read through the real
  /// [ChatRepository.getMessageBlocksByMessageId]. M4.2.1 renders only the
  /// `main_text` blocks among them; the other variants are later slices.
  MessageBlocksProvider._({
    required MessageBlocksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'messageBlocksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$messageBlocksHash();

  @override
  String toString() {
    return r'messageBlocksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MessageBlock>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MessageBlock>> create(Ref ref) {
    final argument = this.argument as String;
    return messageBlocks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MessageBlocksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$messageBlocksHash() => r'b20bbf7be5bd9a9206e46e7664779a306a59c21a';

/// The blocks for a single message, in stored order, read through the real
/// [ChatRepository.getMessageBlocksByMessageId]. M4.2.1 renders only the
/// `main_text` blocks among them; the other variants are later slices.

final class MessageBlocksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MessageBlock>>, String> {
  MessageBlocksFamily._()
    : super(
        retry: null,
        name: r'messageBlocksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The blocks for a single message, in stored order, read through the real
  /// [ChatRepository.getMessageBlocksByMessageId]. M4.2.1 renders only the
  /// `main_text` blocks among them; the other variants are later slices.

  MessageBlocksProvider call(String messageId) =>
      MessageBlocksProvider._(argument: messageId, from: this);

  @override
  String toString() => r'messageBlocksProvider';
}
