// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_bubble_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam exposing the 信息气泡管理 ([MessageBubbleSettings])
/// to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat view cannot read [MessageBubbleSettingsController] (which lives
/// in `settings/application`) directly. It instead watches this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [MessageBubbleSettings] type.
///
/// Reactively re-exposes the controller's state, so changing bubble widths,
/// hide-bubble or custom colors in 外观设置 → 信息气泡管理 re-renders the chat
/// bubbles live.

@ProviderFor(messageBubbleSettings)
final messageBubbleSettingsProvider = MessageBubbleSettingsProvider._();

/// App-level composition seam exposing the 信息气泡管理 ([MessageBubbleSettings])
/// to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat view cannot read [MessageBubbleSettingsController] (which lives
/// in `settings/application`) directly. It instead watches this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [MessageBubbleSettings] type.
///
/// Reactively re-exposes the controller's state, so changing bubble widths,
/// hide-bubble or custom colors in 外观设置 → 信息气泡管理 re-renders the chat
/// bubbles live.

final class MessageBubbleSettingsProvider
    extends
        $FunctionalProvider<
          MessageBubbleSettings,
          MessageBubbleSettings,
          MessageBubbleSettings
        >
    with $Provider<MessageBubbleSettings> {
  /// App-level composition seam exposing the 信息气泡管理 ([MessageBubbleSettings])
  /// to the `chat` feature.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`,
  /// so the chat view cannot read [MessageBubbleSettingsController] (which lives
  /// in `settings/application`) directly. It instead watches this provider in
  /// `app/` (the composition root, which may depend on any feature) plus the
  /// pure-Dart `shared/domain` [MessageBubbleSettings] type.
  ///
  /// Reactively re-exposes the controller's state, so changing bubble widths,
  /// hide-bubble or custom colors in 外观设置 → 信息气泡管理 re-renders the chat
  /// bubbles live.
  MessageBubbleSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageBubbleSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageBubbleSettingsHash();

  @$internal
  @override
  $ProviderElement<MessageBubbleSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MessageBubbleSettings create(Ref ref) {
    return messageBubbleSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageBubbleSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageBubbleSettings>(value),
    );
  }
}

String _$messageBubbleSettingsHash() =>
    r'58b98a7d27a6c22554cf845c717a2b207f8dca5c';
