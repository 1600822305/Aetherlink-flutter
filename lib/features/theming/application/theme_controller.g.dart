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
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] is
/// called, so switching themes is instant and side-effect free.
///
/// Persistence is intentionally a seam only for M4.0: the controller seeds with
/// [defaultThemeSpec] and exposes [use] / [reset]. Loading the last-applied
/// theme from M1 Drift is wired in a later theme sub-stage — see [restore].

@ProviderFor(ThemeController)
final themeControllerProvider = ThemeControllerProvider._();

/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] is
/// called, so switching themes is instant and side-effect free.
///
/// Persistence is intentionally a seam only for M4.0: the controller seeds with
/// [defaultThemeSpec] and exposes [use] / [reset]. Loading the last-applied
/// theme from M1 Drift is wired in a later theme sub-stage — see [restore].
final class ThemeControllerProvider
    extends $NotifierProvider<ThemeController, ThemeSpec> {
  /// Holds the currently active [ThemeSpec] and supports hot-swapping it at
  /// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
  ///
  /// The app shell watches this and rebuilds its `ThemeData` whenever [use] is
  /// called, so switching themes is instant and side-effect free.
  ///
  /// Persistence is intentionally a seam only for M4.0: the controller seeds with
  /// [defaultThemeSpec] and exposes [use] / [reset]. Loading the last-applied
  /// theme from M1 Drift is wired in a later theme sub-stage — see [restore].
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

String _$themeControllerHash() => r'8060191d0fc8eb14607c491df0c0f98ebd8cb10e';

/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] is
/// called, so switching themes is instant and side-effect free.
///
/// Persistence is intentionally a seam only for M4.0: the controller seeds with
/// [defaultThemeSpec] and exposes [use] / [reset]. Loading the last-applied
/// theme from M1 Drift is wired in a later theme sub-stage — see [restore].

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
