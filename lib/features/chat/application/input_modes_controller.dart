import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

part 'input_modes_controller.g.dart';

/// The mutually-exclusive input-box session modes (port of `useExclusiveMode`'s
/// `ExclusiveMode`): 网络搜索 / 图像生成 / 视频生成 / 音频生成(TTS).
enum InputMode { webSearch, image, video, audio }

const String kMediaInputModeSettingKey = 'media_input_mode';

/// The active input-box session mode, or `null` for none.
///
/// Modes are mutually exclusive. Media modes survive restart alongside their
/// persisted model slots; web search remains session-only. The MCP 工具 switch
/// is persisted separately and is **not** one of these modes.
@Riverpod(keepAlive: true)
class InputModeController extends _$InputModeController {
  final Completer<void> _hydrationDone = Completer<void>();
  bool _touched = false;

  Future<void> get hydrated => _hydrationDone.future;

  @override
  InputMode? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    try {
      final stored = await ref
          .read(chatRepositoryProvider)
          .getSetting(kMediaInputModeSettingKey);
      if (!ref.mounted || _touched) return;
      state = switch (stored) {
        'image' => InputMode.image,
        'video' => InputMode.video,
        'audio' => InputMode.audio,
        _ => null,
      };
    } catch (_) {
      // 设置读取失败时保留当前选择，不阻塞发送。
      return;
    } finally {
      if (!_hydrationDone.isCompleted) _hydrationDone.complete();
    }
  }

  /// Toggles [mode]: turns it on (turning any other mode off) or, if it is
  /// already active, back to none — the port of `toggleMode`.
  void toggle(InputMode mode) => set(state == mode ? null : mode);

  /// Arms [mode] unconditionally (or clears with `null`); unlike [toggle]
  /// it never flips an already-active mode off. Used by the model selector
  /// when picking a media-generation model.
  void set(InputMode? mode) {
    _touched = true;
    state = mode;
    ref.read(chatRepositoryProvider).saveSetting(
      kMediaInputModeSettingKey,
      mode == null || mode == InputMode.webSearch ? '' : mode.name,
    );
  }

  void clear() => set(null);
}

/// The standalone 清空内容 button's two-step confirm latch — the port of the web
/// `clearConfirmMode` `useState` shared by `ButtonToolbar` / `ToolsMenu`.
///
/// `true` while the button is armed: the first tap arms it (the glyph swaps to a
/// red `AlertTriangle` and the label to 确认清空) and a second tap within 3 seconds
/// performs the clear; otherwise it disarms itself. Held in memory only — a
/// restart leaves it disarmed. The 扩展 menu runs its own independent confirm
/// (sheet-local) so opening the menu never arms the toolbar button.
@Riverpod(keepAlive: true)
class InputClearConfirm extends _$InputClearConfirm {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Registers a tap. Returns `true` when this tap should perform the clear (it
  /// was already armed); `false` when it merely armed the confirm.
  bool tap() {
    if (state) {
      _disarm();
      return true;
    }
    state = true;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), _disarm);
    return false;
  }

  void _disarm() {
    _timer?.cancel();
    _timer = null;
    if (state) state = false;
  }
}
