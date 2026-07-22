import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes the soft keyboard's 文字编辑面板 (Gboard "Text editing"、讯飞/百度输入法的
/// 编辑面板等) work inside every text field.
///
/// Those panels latch their 选择 toggle by sending a bare Shift key press
/// through the input connection and then tagging the cursor keys with the
/// shift meta state only. The Flutter engine immediately synthesizes a Shift
/// *up* to resync `HardwareKeyboard`'s pressed set, so by the time the arrow
/// key events arrive the framework no longer considers Shift pressed and moves
/// the caret instead of extending the selection — 选择/复制 buttons then never
/// see a selection to act on.
///
/// This widget sits between the focused text field and the app-root
/// `DefaultTextEditingShortcuts`, watching the raw key stream:
///
/// * A Shift down whose matching up is `synthesized` (the IME latch pattern —
///   a physically held Shift produces a real up event) toggles select mode.
/// * While latched, arrow / home / end keys are translated into the
///   selection-*extending* editing intents on the focused editable, exactly
///   what the shortcuts would have produced were Shift still held.
/// * Typing, unfocusing, or toggling Shift again ends the latch.
class ImeEditingPanelSupport extends StatefulWidget {
  const ImeEditingPanelSupport({required this.child, super.key});

  final Widget child;

  @override
  State<ImeEditingPanelSupport> createState() => _ImeEditingPanelSupportState();
}

class _ImeEditingPanelSupportState extends State<ImeEditingPanelSupport> {
  bool _latched = false;
  DateTime _lastArrowAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// A shift pair that *might* be the user toggling 选择 off starts this
  /// timer instead of unlatching immediately: some IMEs (百度/讯飞等) re-send
  /// the latch pair *before every* cursor key, so a pair followed at once by
  /// an arrow is per-key chatter, not a toggle. The arrow cancels the timer;
  /// no arrow means it really was the user toggling off.
  Timer? _unlatchTimer;

  /// Set on the Shift down; if the following Shift up is synthesized the pair
  /// came from an IME latch tap rather than a held hardware key.
  bool _pendingShiftDown = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _unlatchTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    _latched = false;
    _pendingShiftDown = false;
    _unlatchTimer?.cancel();
  }

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isMobile) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isShift =
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight;

    if (isShift) {
      if (event is KeyDownEvent) {
        _pendingShiftDown = true;
      } else if (event is KeyUpEvent && _pendingShiftDown) {
        _pendingShiftDown = false;
        // While the IME's select mode is on, the engine also emits a (down,
        // synthesized up) shift pair shortly after every meta-shifted cursor
        // key; only a standalone pair is the user toggling 选择. When not
        // latched such trailing pairs can't occur, so any pair latches on
        // (which also re-syncs the state if it ever drifts from the IME's).
        if (event.synthesized) {
          final sinceArrow = DateTime.now().difference(_lastArrowAt);
          if (!_latched) {
            _unlatchTimer?.cancel();
            _latched = true;
          } else if (sinceArrow.inMilliseconds > 400) {
            // Either the user toggling 选择 off, or a leading per-key pair
            // from an IME that re-latches before every cursor key. Defer:
            // an arrow arriving right after keeps the selection going.
            _unlatchTimer?.cancel();
            _unlatchTimer = Timer(const Duration(milliseconds: 250), () {
              _latched = false;
            });
          }
        }
      }
      return KeyEventResult.ignored;
    }
    _pendingShiftDown = false;

    final cursorKeys = <LogicalKeyboardKey>{
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
    };
    if (cursorKeys.contains(key)) {
      _lastArrowAt = DateTime.now();
      // An arrow right after a shift pair marks that pair as per-key
      // chatter — keep the latch.
      if (_latched) _unlatchTimer?.cancel();
    }

    if (!_latched || event is KeyUpEvent) return KeyEventResult.ignored;

    // A real modifier being held means a hardware keyboard is in play; defer
    // to the normal shortcuts.
    if (HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      _latched = false;
      return KeyEventResult.ignored;
    }

    final Intent? intent = switch (key) {
      LogicalKeyboardKey.arrowLeft => const ExtendSelectionByCharacterIntent(
        forward: false,
        collapseSelection: false,
      ),
      LogicalKeyboardKey.arrowRight => const ExtendSelectionByCharacterIntent(
        forward: true,
        collapseSelection: false,
      ),
      LogicalKeyboardKey.arrowUp =>
        const ExtendSelectionVerticallyToAdjacentLineIntent(
          forward: false,
          collapseSelection: false,
        ),
      LogicalKeyboardKey.arrowDown =>
        const ExtendSelectionVerticallyToAdjacentLineIntent(
          forward: true,
          collapseSelection: false,
        ),
      LogicalKeyboardKey.home => const ExtendSelectionToLineBreakIntent(
        forward: false,
        collapseSelection: false,
      ),
      LogicalKeyboardKey.end => const ExtendSelectionToLineBreakIntent(
        forward: true,
        collapseSelection: false,
      ),
      _ => null,
    };

    if (intent == null) {
      // Any other key (typing, delete, enter...) drops the IME out of select
      // mode on its side; mirror that.
      _latched = false;
      _unlatchTimer?.cancel();
      return KeyEventResult.ignored;
    }

    final focused = FocusManager.instance.primaryFocus;
    final focusedContext = focused?.context;
    if (focusedContext == null) return KeyEventResult.ignored;
    // `maybeInvoke`'s return value can't distinguish "not found" from a void
    // action, so locate the action first and consume the key whenever the
    // focused editable provides one.
    final action = Actions.maybeFind<Intent>(focusedContext, intent: intent);
    if (action == null) return KeyEventResult.ignored;
    Actions.of(focusedContext).invokeAction(action, intent, focusedContext);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: null,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}
