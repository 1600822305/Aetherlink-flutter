import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';

part 'input_box_settings_controller.g.dart';

/// Storage key for the 输入框风格 preset (the web `settings.inputBoxStyle` key).
const String kInputBoxStyleKey = 'inputBoxStyle';

/// Storage key for the left toolbar layout (the web
/// `settings.integratedInputLeftButtons` key).
const String kInputBoxLeftButtonsKey = 'integratedInputLeftButtons';

/// Storage key for the right toolbar layout (the web
/// `settings.integratedInputRightButtons` key).
const String kInputBoxRightButtonsKey = 'integratedInputRightButtons';

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
@Riverpod(keepAlive: true)
class InputBoxSettingsController extends _$InputBoxSettingsController {
  @override
  InputBoxSettings build() {
    _hydrate();
    return const InputBoxSettings();
  }

  Future<void> _hydrate() async {
    final store = ref.read(appSettingsStoreProvider);
    final results = await Future.wait([
      store.getSetting(kInputBoxStyleKey),
      store.getSetting(kInputBoxLeftButtonsKey),
      store.getSetting(kInputBoxRightButtonsKey),
    ]);
    final style = results[0];
    final left = _decodeButtons(results[1]);
    final right = _decodeButtons(results[2]);
    state = state.copyWith(
      style: style == null ? state.style : InputBoxStyle.fromId(style),
      leftButtons: left ?? state.leftButtons,
      rightButtons: right ?? state.rightButtons,
    );
  }

  /// Parses a stored JSON array of button ids, dropping unknown tokens. Returns
  /// `null` when the value is absent or corrupt so the caller keeps its default.
  List<InputBoxButtonId>? _decodeButtons(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    try {
      final ids = (jsonDecode(stored) as List).cast<String>();
      return List.unmodifiable(
        ids.map(InputBoxButtonId.fromId).whereType<InputBoxButtonId>(),
      );
    } on FormatException {
      return null;
    }
  }

  String _encodeButtons(List<InputBoxButtonId> buttons) =>
      jsonEncode(buttons.map((b) => b.id).toList());

  /// Sets the input-box visual preset (the 输入框风格 dropdown).
  void setStyle(InputBoxStyle style) {
    state = state.copyWith(style: style);
    ref.read(appSettingsStoreProvider).saveSetting(kInputBoxStyleKey, style.id);
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
    final store = ref.read(appSettingsStoreProvider);
    store.saveSetting(kInputBoxLeftButtonsKey, _encodeButtons(left));
    store.saveSetting(kInputBoxRightButtonsKey, _encodeButtons(right));
  }
}
