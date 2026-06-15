import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

part 'theme_controller.g.dart';

/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] is
/// called, so switching themes is instant and side-effect free.
///
/// Persistence is intentionally a seam only for M4.0: the controller seeds with
/// [defaultThemeSpec] and exposes [use] / [reset]. Loading the last-applied
/// theme from M1 Drift is wired in a later theme sub-stage — see [restore].
@riverpod
class ThemeController extends _$ThemeController {
  @override
  ThemeSpec build() => defaultThemeSpec;

  /// Hot-swap the active theme. The app shell rebuilds its `ThemeData` from the
  /// new spec on the next frame.
  void use(ThemeSpec spec) => state = spec;

  /// Revert to the built-in default theme.
  void reset() => state = defaultThemeSpec;

  /// Seam for persistence: a later sub-stage loads the last-applied [ThemeSpec]
  /// from M1 Drift and calls this before the first frame. Until then it is a
  /// no-op fed by the default seed.
  // ignore: use_setters_to_change_properties
  void restore(ThemeSpec persisted) => state = persisted;
}
