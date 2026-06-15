// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Placeholder Riverpod controller for the chat feature.
///
/// Proves the `application` layer wiring (codegen + DI) end to end. The real
/// orchestration — calling use cases, subscribing to the streaming reply,
/// throttling tokens — lands in milestone M2 (see `docs/ARCHITECTURE.md` §4).

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

/// Placeholder Riverpod controller for the chat feature.
///
/// Proves the `application` layer wiring (codegen + DI) end to end. The real
/// orchestration — calling use cases, subscribing to the streaming reply,
/// throttling tokens — lands in milestone M2 (see `docs/ARCHITECTURE.md` §4).
final class ChatControllerProvider
    extends $NotifierProvider<ChatController, ChatState> {
  /// Placeholder Riverpod controller for the chat feature.
  ///
  /// Proves the `application` layer wiring (codegen + DI) end to end. The real
  /// orchestration — calling use cases, subscribing to the streaming reply,
  /// throttling tokens — lands in milestone M2 (see `docs/ARCHITECTURE.md` §4).
  ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @$internal
  @override
  ChatController create() => ChatController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatState>(value),
    );
  }
}

String _$chatControllerHash() => r'0a042ea00717d99a39a9cabf96b8fbf835fe1f35';

/// Placeholder Riverpod controller for the chat feature.
///
/// Proves the `application` layer wiring (codegen + DI) end to end. The real
/// orchestration — calling use cases, subscribing to the streaming reply,
/// throttling tokens — lands in milestone M2 (see `docs/ARCHITECTURE.md` §4).

abstract class _$ChatController extends $Notifier<ChatState> {
  ChatState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatState, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatState, ChatState>,
              ChatState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
