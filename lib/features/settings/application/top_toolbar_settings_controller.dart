import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';

part 'top_toolbar_settings_controller.g.dart';

/// Holds the chat top-toolbar DIY configuration (the original
/// `settings.topToolbar.componentPositions` + `modelSelectorDisplayStyle`), so
/// the appearance 顶部工具栏设置 sub-page stays a pure view.
///
/// Like [ThemeModeController] / [FontSizeController] /
/// [InputBoxSettingsController] it lives in memory only for now: the original
/// persisted these in the `settings` slice, but where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, so
/// the layout resets to [TopToolbarSettings]'s defaults on each cold start
/// until persistence is wired.
///
/// `keepAlive: true`: an app-level preference that must survive the settings
/// page being disposed when navigating away.
@Riverpod(keepAlive: true)
class TopToolbarSettingsController extends _$TopToolbarSettingsController {
  /// The original `EDGE_PADDING`: the 1% left/right air-wall every placed
  /// component's x is clamped into.
  static const double _edgePadding = 1;

  @override
  TopToolbarSettings build() => const TopToolbarSettings();

  /// Add or move [component] to ([x], [y]) (percentages of the preview),
  /// clamping x into the [_edgePadding] air-wall and y to 0–100. An existing
  /// component is updated in place to preserve its z-order (`handleDrop`).
  void placeComponent(TopToolbarComponent component, double x, double y) {
    final placed = TopToolbarComponentPosition(
      component: component,
      x: x.clamp(_edgePadding, 100 - _edgePadding).toDouble(),
      y: y.clamp(0, 100).toDouble(),
    );
    final next = [...state.positions];
    final index = next.indexWhere((p) => p.component == component);
    if (index >= 0) {
      next[index] = placed;
    } else {
      next.add(placed);
    }
    state = state.copyWith(positions: List.unmodifiable(next));
  }

  /// Remove a single placed [component] (the eye-off button / `handleRemoveComponent`).
  void removeComponent(TopToolbarComponent component) {
    state = state.copyWith(
      positions: List.unmodifiable(
        state.positions.where((p) => p.component != component),
      ),
    );
  }

  /// 重置布局: drop every custom position (`handleResetLayout`).
  void resetLayout() {
    if (state.positions.isEmpty) return;
    state = state.copyWith(positions: const []);
  }

  /// 矫正对齐: vertically center every placed component (y = 50%) and re-clamp x
  /// into the air-wall (`handleAlignComponents`).
  void alignLayout() {
    if (state.positions.isEmpty) return;
    state = state.copyWith(
      positions: List.unmodifiable([
        for (final p in state.positions)
          p.copyWith(
            x: p.x.clamp(_edgePadding, 100 - _edgePadding).toDouble(),
            y: 50,
          ),
      ]),
    );
  }

  /// Sets the model selector display style (the 模型选择器显示样式 radio group).
  void setModelSelectorDisplayStyle(ModelSelectorDisplayStyle style) {
    state = state.copyWith(modelSelectorDisplayStyle: style);
  }
}
