// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] /
/// [useStyle] is called, so switching themes is instant and side-effect free.
///
/// The selected built-in preset is persisted through the Drift key/value store
/// (the port of the web `dexieStorage.saveSetting('themeStyle', …)`): [build]
/// seeds with [defaultThemeSpec] and hydrates the last-applied style on first
/// build, and [useStyle] writes the choice through so it survives a restart.

@ProviderFor(ThemeController)
final themeControllerProvider = ThemeControllerProvider._();

/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] /
/// [useStyle] is called, so switching themes is instant and side-effect free.
///
/// The selected built-in preset is persisted through the Drift key/value store
/// (the port of the web `dexieStorage.saveSetting('themeStyle', …)`): [build]
/// seeds with [defaultThemeSpec] and hydrates the last-applied style on first
/// build, and [useStyle] writes the choice through so it survives a restart.
final class ThemeControllerProvider
    extends $NotifierProvider<ThemeController, ThemeSpec> {
  /// Holds the currently active [ThemeSpec] and supports hot-swapping it at
  /// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
  ///
  /// The app shell watches this and rebuilds its `ThemeData` whenever [use] /
  /// [useStyle] is called, so switching themes is instant and side-effect free.
  ///
  /// The selected built-in preset is persisted through the Drift key/value store
  /// (the port of the web `dexieStorage.saveSetting('themeStyle', …)`): [build]
  /// seeds with [defaultThemeSpec] and hydrates the last-applied style on first
  /// build, and [useStyle] writes the choice through so it survives a restart.
  ThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeControllerHash();

  @$internal
  @override
  ThemeController create() => ThemeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeSpec value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeSpec>(value),
    );
  }
}

String _$themeControllerHash() => r'0bf2a580550a7141c7c758fd9a772d2c38984c09';

/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] /
/// [useStyle] is called, so switching themes is instant and side-effect free.
///
/// The selected built-in preset is persisted through the Drift key/value store
/// (the port of the web `dexieStorage.saveSetting('themeStyle', …)`): [build]
/// seeds with [defaultThemeSpec] and hydrates the last-applied style on first
/// build, and [useStyle] writes the choice through so it survives a restart.

abstract class _$ThemeController extends $Notifier<ThemeSpec> {
  ThemeSpec build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeSpec, ThemeSpec>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeSpec, ThemeSpec>,
              ThemeSpec,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
