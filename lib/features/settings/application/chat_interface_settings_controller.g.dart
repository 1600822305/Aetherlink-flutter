// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_interface_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the 聊天界面设置 configuration (the original `settings.multiModelDisplayStyle`
/// / `showToolDetails` / `showCitationDetails` / `showSystemPromptBubble` /
/// `chatBackground`), so the appearance sub-page stays a pure view.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// (later) the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.

@ProviderFor(ChatInterfaceSettingsController)
final chatInterfaceSettingsControllerProvider =
    ChatInterfaceSettingsControllerProvider._();

/// Holds the 聊天界面设置 configuration (the original `settings.multiModelDisplayStyle`
/// / `showToolDetails` / `showCitationDetails` / `showSystemPromptBubble` /
/// `chatBackground`), so the appearance sub-page stays a pure view.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// (later) the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.
final class ChatInterfaceSettingsControllerProvider
    extends
        $NotifierProvider<
          ChatInterfaceSettingsController,
          ChatInterfaceSettings
        > {
  /// Holds the 聊天界面设置 configuration (the original `settings.multiModelDisplayStyle`
  /// / `showToolDetails` / `showCitationDetails` / `showSystemPromptBubble` /
  /// `chatBackground`), so the appearance sub-page stays a pure view.
  ///
  /// `keepAlive: true`: an app-level preference shared by the settings page and
  /// (later) the chat view. Hydrated from the Drift key/value store on first
  /// build and written through on every change — the port of the web
  /// `dexieStorage.saveSetting` — so the configuration survives a full restart.
  ChatInterfaceSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatInterfaceSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatInterfaceSettingsControllerHash();

  @$internal
  @override
  ChatInterfaceSettingsController create() => ChatInterfaceSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatInterfaceSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatInterfaceSettings>(value),
    );
  }
}

String _$chatInterfaceSettingsControllerHash() =>
    r'b679988ccc06670143c14a61bf71ab263cb8429e';

/// Holds the 聊天界面设置 configuration (the original `settings.multiModelDisplayStyle`
/// / `showToolDetails` / `showCitationDetails` / `showSystemPromptBubble` /
/// `chatBackground`), so the appearance sub-page stays a pure view.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// (later) the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.

abstract class _$ChatInterfaceSettingsController
    extends $Notifier<ChatInterfaceSettings> {
  ChatInterfaceSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatInterfaceSettings, ChatInterfaceSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatInterfaceSettings, ChatInterfaceSettings>,
              ChatInterfaceSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
