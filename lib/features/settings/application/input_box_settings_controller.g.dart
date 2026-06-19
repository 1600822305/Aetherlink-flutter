// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'input_box_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the input-box configuration (the original `settings.inputBoxStyle` +
/// `integratedInputLeftButtons` / `integratedInputRightButtons`), so the
/// appearance 输入框管理设置 sub-page stays a pure view and the chat composer can
/// follow the same source of truth.
///
/// Each field persists under its own Drift key/value entry — the visual preset
/// as its raw id and each toolbar layout as a JSON array of button ids — so the
/// configuration is hydrated on first build and written through on every change,
/// surviving a full restart (the same pattern as [BehaviorSettingsController],
/// reaching the KV store via the `app/` [appSettingsStoreProvider] seam).
///
/// `keepAlive: true`: an app-level preference shared by the chat page and the
/// settings page that must survive either being disposed when navigating away.

@ProviderFor(InputBoxSettingsController)
final inputBoxSettingsControllerProvider =
    InputBoxSettingsControllerProvider._();

/// Holds the input-box configuration (the original `settings.inputBoxStyle` +
/// `integratedInputLeftButtons` / `integratedInputRightButtons`), so the
/// appearance 输入框管理设置 sub-page stays a pure view and the chat composer can
/// follow the same source of truth.
///
/// Each field persists under its own Drift key/value entry — the visual preset
/// as its raw id and each toolbar layout as a JSON array of button ids — so the
/// configuration is hydrated on first build and written through on every change,
/// surviving a full restart (the same pattern as [BehaviorSettingsController],
/// reaching the KV store via the `app/` [appSettingsStoreProvider] seam).
///
/// `keepAlive: true`: an app-level preference shared by the chat page and the
/// settings page that must survive either being disposed when navigating away.
final class InputBoxSettingsControllerProvider
    extends $NotifierProvider<InputBoxSettingsController, InputBoxSettings> {
  /// Holds the input-box configuration (the original `settings.inputBoxStyle` +
  /// `integratedInputLeftButtons` / `integratedInputRightButtons`), so the
  /// appearance 输入框管理设置 sub-page stays a pure view and the chat composer can
  /// follow the same source of truth.
  ///
  /// Each field persists under its own Drift key/value entry — the visual preset
  /// as its raw id and each toolbar layout as a JSON array of button ids — so the
  /// configuration is hydrated on first build and written through on every change,
  /// surviving a full restart (the same pattern as [BehaviorSettingsController],
  /// reaching the KV store via the `app/` [appSettingsStoreProvider] seam).
  ///
  /// `keepAlive: true`: an app-level preference shared by the chat page and the
  /// settings page that must survive either being disposed when navigating away.
  InputBoxSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inputBoxSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inputBoxSettingsControllerHash();

  @$internal
  @override
  InputBoxSettingsController create() => InputBoxSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InputBoxSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InputBoxSettings>(value),
    );
  }
}

String _$inputBoxSettingsControllerHash() =>
    r'b2f4fd53182a9c0be043780573fed290ba4e084b';

/// Holds the input-box configuration (the original `settings.inputBoxStyle` +
/// `integratedInputLeftButtons` / `integratedInputRightButtons`), so the
/// appearance 输入框管理设置 sub-page stays a pure view and the chat composer can
/// follow the same source of truth.
///
/// Each field persists under its own Drift key/value entry — the visual preset
/// as its raw id and each toolbar layout as a JSON array of button ids — so the
/// configuration is hydrated on first build and written through on every change,
/// surviving a full restart (the same pattern as [BehaviorSettingsController],
/// reaching the KV store via the `app/` [appSettingsStoreProvider] seam).
///
/// `keepAlive: true`: an app-level preference shared by the chat page and the
/// settings page that must survive either being disposed when navigating away.

abstract class _$InputBoxSettingsController
    extends $Notifier<InputBoxSettings> {
  InputBoxSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<InputBoxSettings, InputBoxSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InputBoxSettings, InputBoxSettings>,
              InputBoxSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
