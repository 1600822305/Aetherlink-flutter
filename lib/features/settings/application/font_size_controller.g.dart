// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_size_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the global base font size in px (the original `settings.fontSize`),
/// so the appearance page stays a pure view.
///
/// The app shell maps this to a text-scale factor of [defaultSize] (`size / 16`)
/// applied to the active theme, so every text style scales proportionally —
/// matching the original theme's `fontScale = fontSize / 16` (`themes.ts`).
///
/// Seeds [defaultSize] (16px = "标准"), the original default. Like
/// [ThemeModeController], it lives in memory only for now: the original
/// persisted `settings.fontSize`, but where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, so
/// the size resets to the default on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.

@ProviderFor(FontSizeController)
final fontSizeControllerProvider = FontSizeControllerProvider._();

/// Holds the global base font size in px (the original `settings.fontSize`),
/// so the appearance page stays a pure view.
///
/// The app shell maps this to a text-scale factor of [defaultSize] (`size / 16`)
/// applied to the active theme, so every text style scales proportionally —
/// matching the original theme's `fontScale = fontSize / 16` (`themes.ts`).
///
/// Seeds [defaultSize] (16px = "标准"), the original default. Like
/// [ThemeModeController], it lives in memory only for now: the original
/// persisted `settings.fontSize`, but where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, so
/// the size resets to the default on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.
final class FontSizeControllerProvider
    extends $NotifierProvider<FontSizeController, int> {
  /// Holds the global base font size in px (the original `settings.fontSize`),
  /// so the appearance page stays a pure view.
  ///
  /// The app shell maps this to a text-scale factor of [defaultSize] (`size / 16`)
  /// applied to the active theme, so every text style scales proportionally —
  /// matching the original theme's `fontScale = fontSize / 16` (`themes.ts`).
  ///
  /// Seeds [defaultSize] (16px = "标准"), the original default. Like
  /// [ThemeModeController], it lives in memory only for now: the original
  /// persisted `settings.fontSize`, but where app preferences live
  /// (shared_preferences vs a Drift settings table) is a separate decision, so
  /// the size resets to the default on each cold start until persistence is
  /// wired.
  ///
  /// `keepAlive: true`: an app-level preference that must survive the appearance
  /// page being disposed when navigating away, so it is not auto-disposed.
  FontSizeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontSizeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontSizeControllerHash();

  @$internal
  @override
  FontSizeController create() => FontSizeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$fontSizeControllerHash() =>
    r'e2ece35dd2c9bbbb86ea56b0cf9350bbf1a371f6';

/// Holds the global base font size in px (the original `settings.fontSize`),
/// so the appearance page stays a pure view.
///
/// The app shell maps this to a text-scale factor of [defaultSize] (`size / 16`)
/// applied to the active theme, so every text style scales proportionally —
/// matching the original theme's `fontScale = fontSize / 16` (`themes.ts`).
///
/// Seeds [defaultSize] (16px = "标准"), the original default. Like
/// [ThemeModeController], it lives in memory only for now: the original
/// persisted `settings.fontSize`, but where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, so
/// the size resets to the default on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.

abstract class _$FontSizeController extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
