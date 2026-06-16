// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the active [AppThemeMode] (the original `settings.theme`) for the
/// application layer, so the appearance page stays a pure view.
///
/// Seeds [AppThemeMode.system] — matching the app shell's prior behaviour of
/// leaving `MaterialApp.themeMode` unset, which defaults to follow-system. It
/// lives in memory only for now, mirroring the onboarding / view-mode
/// controllers' "seam, not yet persisted" approach: the original persisted
/// `settings.theme`, but where app preferences live (shared_preferences vs a
/// Drift settings table) is a separate decision, so the mode resets to
/// follow-system on each cold start until persistence is wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Holds the active [AppThemeMode] (the original `settings.theme`) for the
/// application layer, so the appearance page stays a pure view.
///
/// Seeds [AppThemeMode.system] — matching the app shell's prior behaviour of
/// leaving `MaterialApp.themeMode` unset, which defaults to follow-system. It
/// lives in memory only for now, mirroring the onboarding / view-mode
/// controllers' "seam, not yet persisted" approach: the original persisted
/// `settings.theme`, but where app preferences live (shared_preferences vs a
/// Drift settings table) is a separate decision, so the mode resets to
/// follow-system on each cold start until persistence is wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.
final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, AppThemeMode> {
  /// Holds the active [AppThemeMode] (the original `settings.theme`) for the
  /// application layer, so the appearance page stays a pure view.
  ///
  /// Seeds [AppThemeMode.system] — matching the app shell's prior behaviour of
  /// leaving `MaterialApp.themeMode` unset, which defaults to follow-system. It
  /// lives in memory only for now, mirroring the onboarding / view-mode
  /// controllers' "seam, not yet persisted" approach: the original persisted
  /// `settings.theme`, but where app preferences live (shared_preferences vs a
  /// Drift settings table) is a separate decision, so the mode resets to
  /// follow-system on each cold start until persistence is wired.
  ///
  /// `keepAlive: true`: an app-level preference that must survive the appearance
  /// page being disposed when navigating away, so it is not auto-disposed.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'd59a037eb369aa44e350d3dc318e17361a47b413';

/// Holds the active [AppThemeMode] (the original `settings.theme`) for the
/// application layer, so the appearance page stays a pure view.
///
/// Seeds [AppThemeMode.system] — matching the app shell's prior behaviour of
/// leaving `MaterialApp.themeMode` unset, which defaults to follow-system. It
/// lives in memory only for now, mirroring the onboarding / view-mode
/// controllers' "seam, not yet persisted" approach: the original persisted
/// `settings.theme`, but where app preferences live (shared_preferences vs a
/// Drift settings table) is a separate decision, so the mode resets to
/// follow-system on each cold start until persistence is wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.

abstract class _$ThemeModeController extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
