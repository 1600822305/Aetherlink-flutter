import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';

part 'top_toolbar_settings_controller.g.dart';

/// Storage key for the persisted top-toolbar DIY layout (a single JSON blob,
/// mirroring how the web kept `settings.topToolbar`).
const String kTopToolbarSettingsKey = 'topToolbarSettings';

/// Holds the chat top-toolbar DIY configuration (the original
/// `settings.topToolbar.componentPositions` + `modelSelectorDisplayStyle`), so
/// the appearance 顶部工具栏设置 sub-page stays a pure view.
///
/// Hydrated from the Drift key/value store on first build and written through
/// on every change, so the layout survives a full restart (the web kept it in
/// the `settings` slice).
///
/// `keepAlive: true`: an app-level preference that must survive the settings
/// page being disposed when navigating away.
@Riverpod(keepAlive: true)
class TopToolbarSettingsController extends _$TopToolbarSettingsController
    with JsonKvNotifier<TopToolbarSettings> {
  /// The original `EDGE_PADDING`: the 1% left/right air-wall every placed
  /// component's x is clamped into.
  static const double _edgePadding = 1;

  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kTopToolbarSettingsKey;

  @override
  TopToolbarSettings fromStored(Map<String, dynamic> json) =>
      TopToolbarSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(TopToolbarSettings value) => value.toJson();

  @override
  TopToolbarSettings build() => hydrate(const TopToolbarSettings());

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
    persist(state.copyWith(positions: List.unmodifiable(next)));
  }

  /// Remove a single placed [component] (the eye-off button / `handleRemoveComponent`).
  void removeComponent(TopToolbarComponent component) {
    persist(
      state.copyWith(
        positions: List.unmodifiable(
          state.positions.where((p) => p.component != component),
        ),
      ),
    );
  }

  /// 重置布局: drop every custom position (`handleResetLayout`).
  void resetLayout() {
    if (state.positions.isEmpty) return;
    persist(state.copyWith(positions: const []));
  }

  /// 矫正对齐: vertically center every placed component AND 聚合按钮 (y = 50%)
  /// and re-clamp x into the air-wall (`handleAlignComponents`).
  void alignLayout() {
    if (state.positions.isEmpty && state.groups.isEmpty) return;
    persist(
      state.copyWith(
        positions: List.unmodifiable([
          for (final p in state.positions)
            p.copyWith(
              x: p.x.clamp(_edgePadding, 100 - _edgePadding).toDouble(),
              y: 50,
            ),
        ]),
        groups: List.unmodifiable([
          for (final g in state.groups)
            g.copyWith(
              x: g.x.clamp(_edgePadding, 100 - _edgePadding).toDouble(),
              y: 50,
            ),
        ]),
      ),
    );
  }

  /// Sets the model selector display style (the 模型选择器显示样式 radio group).
  void setModelSelectorDisplayStyle(ModelSelectorDisplayStyle style) {
    persist(state.copyWith(modelSelectorDisplayStyle: style));
  }

  // --- 聚合按钮 (aggregate buttons) ---------------------------------------

  /// Creates a new empty 聚合按钮 at ([x], [y]) and returns its generated id, so
  /// the caller can immediately open its editor.
  String addGroup(double x, double y) {
    final group = TopToolbarGroup(
      id: generateId('tbgrp'),
      x: x.clamp(_edgePadding, 100 - _edgePadding).toDouble(),
      y: y.clamp(0, 100).toDouble(),
    );
    persist(
      state.copyWith(groups: List.unmodifiable([...state.groups, group])),
    );
    return group.id;
  }

  /// Moves the group [id] to ([x], [y]), clamped into the same air-wall placed
  /// components use.
  void moveGroup(String id, double x, double y) {
    _updateGroup(
      id,
      (g) => g.copyWith(
        x: x.clamp(_edgePadding, 100 - _edgePadding).toDouble(),
        y: y.clamp(0, 100).toDouble(),
      ),
    );
  }

  /// Removes the group [id] entirely.
  void removeGroup(String id) {
    persist(
      state.copyWith(
        groups: List.unmodifiable(state.groups.where((g) => g.id != id)),
      ),
    );
  }

  /// Renames the group [id] (the group editor's name field).
  void renameGroup(String id, String label) {
    _updateGroup(id, (g) => g.copyWith(label: label));
  }

  /// Sets the group [id]'s glyph.
  void setGroupIcon(String id, TopToolbarGroupIcon icon) {
    _updateGroup(id, (g) => g.copyWith(icon: icon));
  }

  /// Appends [component] to the group [id]'s children (no-op if already there).
  void addGroupChild(String id, TopToolbarComponent component) {
    _updateGroup(id, (g) {
      if (g.children.contains(component)) return g;
      return g.copyWith(children: List.unmodifiable([...g.children, component]));
    });
  }

  /// Removes [component] from the group [id]'s children.
  void removeGroupChild(String id, TopToolbarComponent component) {
    _updateGroup(
      id,
      (g) => g.copyWith(
        children: List.unmodifiable(
          g.children.where((c) => c != component),
        ),
      ),
    );
  }

  /// Reorders the group [id]'s children, moving the child at [oldIndex] to
  /// [newIndex] (matching `ReorderableListView.onReorderItem` semantics, where
  /// [newIndex] is already adjusted for the removed item).
  void reorderGroupChildren(String id, int oldIndex, int newIndex) {
    _updateGroup(id, (g) {
      final next = [...g.children];
      if (oldIndex < 0 || oldIndex >= next.length) return g;
      final moved = next.removeAt(oldIndex);
      next.insert(newIndex.clamp(0, next.length), moved);
      return g.copyWith(children: List.unmodifiable(next));
    });
  }

  void _updateGroup(String id, TopToolbarGroup Function(TopToolbarGroup) f) {
    final index = state.groups.indexWhere((g) => g.id == id);
    if (index < 0) return;
    final next = [...state.groups];
    next[index] = f(next[index]);
    persist(state.copyWith(groups: List.unmodifiable(next)));
  }
}
