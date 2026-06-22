// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_bubble_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the 信息气泡管理 configuration (the original `settings.messageActionMode`
/// / `showMicroBubbles` / `showTTSButton` / `versionSwitchStyle` / bubble widths
/// / avatar & name toggles / hide-bubble toggles / `customBubbleColors`), so the
/// appearance sub-page and the chat view stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.

@ProviderFor(MessageBubbleSettingsController)
final messageBubbleSettingsControllerProvider =
    MessageBubbleSettingsControllerProvider._();

/// Holds the 信息气泡管理 configuration (the original `settings.messageActionMode`
/// / `showMicroBubbles` / `showTTSButton` / `versionSwitchStyle` / bubble widths
/// / avatar & name toggles / hide-bubble toggles / `customBubbleColors`), so the
/// appearance sub-page and the chat view stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.
final class MessageBubbleSettingsControllerProvider
    extends
        $NotifierProvider<
          MessageBubbleSettingsController,
          MessageBubbleSettings
        > {
  /// Holds the 信息气泡管理 configuration (the original `settings.messageActionMode`
  /// / `showMicroBubbles` / `showTTSButton` / `versionSwitchStyle` / bubble widths
  /// / avatar & name toggles / hide-bubble toggles / `customBubbleColors`), so the
  /// appearance sub-page and the chat view stay pure views.
  ///
  /// `keepAlive: true`: an app-level preference shared by the settings page and the
  /// chat view. Hydrated from the Drift key/value store on first build and written
  /// through on every change — the port of the web `dexieStorage.saveSetting` — so
  /// the configuration survives a full restart.
  MessageBubbleSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageBubbleSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageBubbleSettingsControllerHash();

  @$internal
  @override
  MessageBubbleSettingsController create() => MessageBubbleSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageBubbleSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageBubbleSettings>(value),
    );
  }
}

String _$messageBubbleSettingsControllerHash() =>
    r'b1df0084d836c51b67b384c010bbea30e5e78109';

/// Holds the 信息气泡管理 configuration (the original `settings.messageActionMode`
/// / `showMicroBubbles` / `showTTSButton` / `versionSwitchStyle` / bubble widths
/// / avatar & name toggles / hide-bubble toggles / `customBubbleColors`), so the
/// appearance sub-page and the chat view stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.

abstract class _$MessageBubbleSettingsController
    extends $Notifier<MessageBubbleSettings> {
  MessageBubbleSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MessageBubbleSettings, MessageBubbleSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageBubbleSettings, MessageBubbleSettings>,
              MessageBubbleSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
