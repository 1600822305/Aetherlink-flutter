// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the 设置 tab (侧边栏快捷设置面板) configuration so the sidebar stays a pure
/// view and the chat view can react to the wired-up toggles.
///
/// `keepAlive: true`: an app-level preference shared by the sidebar, the drawer
/// width and the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change (the port of the web
/// `dexieStorage.saveSetting` / `localStorage` `appSettings`), so it survives a
/// full restart.

@ProviderFor(SidebarSettingsController)
final sidebarSettingsControllerProvider = SidebarSettingsControllerProvider._();

/// Holds the 设置 tab (侧边栏快捷设置面板) configuration so the sidebar stays a pure
/// view and the chat view can react to the wired-up toggles.
///
/// `keepAlive: true`: an app-level preference shared by the sidebar, the drawer
/// width and the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change (the port of the web
/// `dexieStorage.saveSetting` / `localStorage` `appSettings`), so it survives a
/// full restart.
final class SidebarSettingsControllerProvider
    extends $NotifierProvider<SidebarSettingsController, SidebarSettings> {
  /// Holds the 设置 tab (侧边栏快捷设置面板) configuration so the sidebar stays a pure
  /// view and the chat view can react to the wired-up toggles.
  ///
  /// `keepAlive: true`: an app-level preference shared by the sidebar, the drawer
  /// width and the chat view. Hydrated from the Drift key/value store on first
  /// build and written through on every change (the port of the web
  /// `dexieStorage.saveSetting` / `localStorage` `appSettings`), so it survives a
  /// full restart.
  SidebarSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidebarSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidebarSettingsControllerHash();

  @$internal
  @override
  SidebarSettingsController create() => SidebarSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SidebarSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SidebarSettings>(value),
    );
  }
}

String _$sidebarSettingsControllerHash() =>
    r'da856e5e5afa9df30c3528d9801ef8bbf3b6f855';

/// Holds the 设置 tab (侧边栏快捷设置面板) configuration so the sidebar stays a pure
/// view and the chat view can react to the wired-up toggles.
///
/// `keepAlive: true`: an app-level preference shared by the sidebar, the drawer
/// width and the chat view. Hydrated from the Drift key/value store on first
/// build and written through on every change (the port of the web
/// `dexieStorage.saveSetting` / `localStorage` `appSettings`), so it survives a
/// full restart.

abstract class _$SidebarSettingsController extends $Notifier<SidebarSettings> {
  SidebarSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SidebarSettings, SidebarSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SidebarSettings, SidebarSettings>,
              SidebarSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
