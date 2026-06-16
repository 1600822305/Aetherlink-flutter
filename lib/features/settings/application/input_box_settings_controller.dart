import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';

part 'input_box_settings_controller.g.dart';

/// Holds the input-box configuration (the original `settings.inputBoxStyle` +
/// `integratedInputLeftButtons` / `integratedInputRightButtons`), so the
/// appearance 输入框管理设置 sub-page stays a pure view and the chat composer can
/// follow the same source of truth.
///
/// Like [ThemeModeController] / [FontSizeController] it lives in memory only for
/// now: the original persisted these in the `settings` slice, but where app
/// preferences live (shared_preferences vs a Drift settings table) is a
/// separate decision, so the config resets to [InputBoxSettings]'s defaults on
/// each cold start until persistence is wired.
///
/// `keepAlive: true`: an app-level preference shared by the chat page and the
/// settings page that must survive either being disposed when navigating away.
@Riverpod(keepAlive: true)
class InputBoxSettingsController extends _$InputBoxSettingsController {
  @override
  InputBoxSettings build() => const InputBoxSettings();

  /// Sets the input-box visual preset (the 输入框风格 dropdown).
  void setStyle(InputBoxStyle style) {
    state = state.copyWith(style: style);
  }

  /// Replaces the left / right toolbar layout (the drag-and-drop config). The
  /// original keeps a combined list too, but the left / right split is the only
  /// thing the composer reads, so that is all we store.
  void updateLayout({
    required List<InputBoxButtonId> left,
    required List<InputBoxButtonId> right,
  }) {
    state = state.copyWith(
      leftButtons: List.unmodifiable(left),
      rightButtons: List.unmodifiable(right),
    );
  }
}
