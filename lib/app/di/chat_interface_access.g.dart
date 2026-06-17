// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_interface_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam exposing the 聊天界面设置 ([ChatInterfaceSettings])
/// to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat view cannot read [ChatInterfaceSettingsController] (which lives
/// in `settings/application`) directly. It instead watches this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [ChatInterfaceSettings] type.
///
/// Reactively re-exposes the controller's state, so toggling 系统提示词气泡 in
/// 外观设置 → 聊天界面设置 shows/hides the bubble on the chat page live.

@ProviderFor(chatInterfaceSettings)
final chatInterfaceSettingsProvider = ChatInterfaceSettingsProvider._();

/// App-level composition seam exposing the 聊天界面设置 ([ChatInterfaceSettings])
/// to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat view cannot read [ChatInterfaceSettingsController] (which lives
/// in `settings/application`) directly. It instead watches this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [ChatInterfaceSettings] type.
///
/// Reactively re-exposes the controller's state, so toggling 系统提示词气泡 in
/// 外观设置 → 聊天界面设置 shows/hides the bubble on the chat page live.

final class ChatInterfaceSettingsProvider
    extends
        $FunctionalProvider<
          ChatInterfaceSettings,
          ChatInterfaceSettings,
          ChatInterfaceSettings
        >
    with $Provider<ChatInterfaceSettings> {
  /// App-level composition seam exposing the 聊天界面设置 ([ChatInterfaceSettings])
  /// to the `chat` feature.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`,
  /// so the chat view cannot read [ChatInterfaceSettingsController] (which lives
  /// in `settings/application`) directly. It instead watches this provider in
  /// `app/` (the composition root, which may depend on any feature) plus the
  /// pure-Dart `shared/domain` [ChatInterfaceSettings] type.
  ///
  /// Reactively re-exposes the controller's state, so toggling 系统提示词气泡 in
  /// 外观设置 → 聊天界面设置 shows/hides the bubble on the chat page live.
  ChatInterfaceSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatInterfaceSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatInterfaceSettingsHash();

  @$internal
  @override
  $ProviderElement<ChatInterfaceSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChatInterfaceSettings create(Ref ref) {
    return chatInterfaceSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatInterfaceSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatInterfaceSettings>(value),
    );
  }
}

String _$chatInterfaceSettingsHash() =>
    r'0edd6d589e91f76d4e8b691c882eb4e9cf7fbdd2';
