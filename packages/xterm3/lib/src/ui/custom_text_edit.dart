import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Whether the embedder on this platform hands a key to the input method only
/// when the framework left it unhandled.
///
/// The macOS embedder sends every key event to the framework first and passes
/// it on to the platform input method (NSTextInputContext) only if nothing
/// handled it. Consuming a key in the framework therefore keeps it away from
/// the IME, so composition (Hangul, kana, pinyin, dead keys) never starts.
/// Windows delivers IME input through its own messages and mobile and web have
/// no such ordering, so none of them is affected. Linux has the same ordering
/// but does not serialize key events, so text updates can arrive after a
/// reset; it is left as it was until that can be tested on a device.
bool get platformInputMethodNeedsUnhandledKeys =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

class CustomTextEdit extends StatefulWidget {
  CustomTextEdit({
    super.key,
    required this.child,
    required this.onInsert,
    required this.onDelete,
    required this.onComposing,
    required this.onAction,
    required this.onKeyEvent,
    required this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    // this.initEditingState = TextEditingValue.empty,
    int? viewId,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.newline,
    this.keyboardAppearance = Brightness.light,
    this.deleteDetection = false,
  }) : viewId = viewId ?? PlatformDispatcher.instance.implicitView?.viewId {
    if (this.viewId == null) {
      throw Exception('Cannot open input connection without a valid viewId.');
    }
  }

  final Widget child;

  final void Function(String) onInsert;

  final void Function() onDelete;

  final void Function(String?) onComposing;

  final void Function(TextInputAction) onAction;

  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  final FocusNode focusNode;

  final bool autofocus;

  final bool readOnly;

  final TextInputType inputType;

  final TextInputAction inputAction;

  final Brightness keyboardAppearance;

  final bool deleteDetection;

  final int? viewId;

  @override
  CustomTextEditState createState() => CustomTextEditState();
}

class CustomTextEditState extends State<CustomTextEdit> with TextInputClient {
  TextInputConnection? _connection;

  /// Text synchronously written when an IME action arrived with an active
  /// composing range. Android may subsequently send the same text as a
  /// collapsed editing value; it must not reach the terminal twice.
  String? _actionCommittedText;

  /// The content of an open, not-yet-resolved composing range in
  /// [deleteDetection] mode - see [_updateEditingValueWithDeleteDetection].
  /// Non-null exactly while such a range is open and its fate (genuine
  /// preview vs. trapped keystroke) has not yet been decided.
  String? _pendingComposingText;

  /// The `composing.start` of [_pendingComposingText], used to tell a
  /// composing range that is being extended in place (same base, growing
  /// text - a real preview) from one that has been replaced by an unrelated
  /// fresh range at the same base (a trapped keystroke, see f6568e1).
  int? _pendingComposingBase;

  /// The part of the platform's editing text that the terminal has received,
  /// in desktop mode - see [_updateEditingValueDesktop]. A prefix of the
  /// platform text, except while the input method rewrites sent characters.
  String _sent = '';

  /// The trailing Hangul character of the platform text, which the terminal
  /// has not received yet and the view shows as the composing preview.
  String _held = '';

  /// Whether the platform text should be cleared at the next safe moment.
  ///
  /// It is never cleared from inside [updateEditingValue]: an input method
  /// can commit and open a new mark within one keystroke, the embedder then
  /// reports both as separate values, and a reset sent for the first would
  /// land after the platform has already made the second (and discard its
  /// marked text). Between keystrokes nothing is in flight, so the clear
  /// waits for the next key event, an action, or the end of the connection.
  bool _resetPending = false;

  /// Whether editing values take the desktop path.
  ///
  /// The macOS input methods differ from the mobile ones: Korean
  /// does not mark the syllable being composed. It inserts the jamo and then
  /// rewrites the last character of the document (`ㅎ`, `하`, `한`), using
  /// the document text as its context. Clearing the document while such a
  /// character is still open makes the next jamo start from nothing, so the
  /// document is only reset when no Hangul character is at its end, and what
  /// was sent is tracked by content rather than by length.
  bool get _desktopMode =>
      platformInputMethodNeedsUnhandledKeys && !widget.deleteDetection;

  @override
  void initState() {
    widget.focusNode.addListener(_onFocusChange);
    super.initState();
  }

  @override
  void didUpdateWidget(CustomTextEdit oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }

    if (!_shouldCreateInputConnection) {
      _closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && widget.focusNode.hasFocus) {
        _openInputConnection();
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    // What the user saw on screen as typed must not be lost with the view.
    _flushHeld();
    _closeInputConnectionIfNeeded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }

  bool get hasInputConnection => _connection != null && _connection!.attached;

  void requestKeyboard() {
    if (widget.focusNode.hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void closeKeyboard() {
    _closeInputConnectionIfNeeded();
  }

  void setEditingState(TextEditingValue value) {
    _currentEditingState = value;
    _sent = '';
    _held = '';
    _resetPending = false;
    _connection?.setEditingState(value);
  }

  /// Drops any in-flight composition and restores the initial editing state.
  void resetEditingState() {
    widget.onComposing(null);
    _resetEditingState();
  }

  /// Sends a Hangul character the view is still holding back, so that input
  /// from outside the keyboard (a paste) does not overtake it. Does nothing on
  /// platforms that do not hold characters back.
  void commitHeld() {
    if (_desktopMode && hasInputConnection && _held.isNotEmpty) {
      _flushHeld();
      _resetEditingState();
    }
  }

  void setEditableRect(Rect rect, Rect caretRect) {
    if (!hasInputConnection) {
      return;
    }

    _connection?.setEditableSizeAndTransform(
      rect.size,
      Matrix4.translationValues(0, 0, 0),
    );

    _connection?.setCaretRect(caretRect);
  }

  void _onFocusChange() {
    _openOrCloseInputConnectionIfNeeded();
  }

  KeyEventResult _onKeyEvent(FocusNode focusNode, KeyEvent event) {
    final desktop = _desktopMode;
    if (desktop && !hasInputConnection) {
      // No input method to hand keys to; nothing typed may be left waiting.
      _flushHeld();
      _currentEditingState = _initEditingState;
    }

    if (!_currentEditingState.composing.isCollapsed) {
      return KeyEventResult.skipRemainingHandlers;
    }

    if (desktop && _held.isEmpty && _resetPending && event is! KeyUpEvent) {
      // Nothing is composing and no Hangul character is open, so clearing
      // the platform text cannot cost the input method any context.
      _resetEditingState();
    }

    if (desktop && _held.isNotEmpty) {
      switch (_routeWhileHolding(event)) {
        case _HeldKeyRoute.ime:
          // The input method may still rewrite the held character, and the
          // terminal must not see the key before it does.
          return KeyEventResult.skipRemainingHandlers;
        case _HeldKeyRoute.flush:
          // The terminal handles this key itself, so the input method will
          // not see it: what was typed has to arrive first, and the platform
          // text is no longer needed as the input method's context.
          _flushHeld();
          _resetEditingState();
        case _HeldKeyRoute.neutral:
          break;
      }
    }

    return widget.onKeyEvent(focusNode, event);
  }

  _HeldKeyRoute _routeWhileHolding(KeyEvent event) {
    if (event is KeyUpEvent) return _HeldKeyRoute.neutral;
    final key = event.logicalKey;
    if (_modifierKeys.contains(key)) return _HeldKeyRoute.neutral;

    // A chord is the terminal's, whatever key it is on.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return _HeldKeyRoute.flush;
    }
    if (key == LogicalKeyboardKey.backspace) return _HeldKeyRoute.ime;

    final character = event.character;
    if (character != null && character.isNotEmpty) {
      final unit = character.codeUnitAt(0);
      if (unit >= 0x20 && unit != 0x7f) return _HeldKeyRoute.ime;
    }
    return _HeldKeyRoute.flush;
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!widget.focusNode.hasFocus) {
      _closeInputConnectionIfNeeded();
    }
  }

  bool get _shouldCreateInputConnection => kIsWeb || !widget.readOnly;

  void _openInputConnection() {
    if (!_shouldCreateInputConnection) {
      return;
    }

    if (hasInputConnection) {
      _connection!.show();
    } else {
      final config = TextInputConfiguration(
        viewId: widget.viewId,
        inputType: widget.inputType,
        inputAction: widget.inputAction,
        keyboardAppearance: widget.keyboardAppearance,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
      );

      _connection = TextInput.attach(this, config);

      _connection!.show();

      // setEditableRect(Rect.zero, Rect.zero);

      _forgetDesktopState();
      _currentEditingState = _initEditingState;
      _connection!.setEditingState(_initEditingState);
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_connection != null && _connection!.attached) {
      _flushHeld();
      _connection!.close();
      _connection = null;
    }
    _forgetDesktopState();
    if (_desktopMode) {
      _currentEditingState = _initEditingState;
    }
  }

  TextEditingValue get _initEditingState => widget.deleteDetection
      ? const TextEditingValue(
          text: '  ',
          selection: TextSelection.collapsed(offset: 2),
        )
      : const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );

  late var _currentEditingState = _initEditingState.copyWith();

  @override
  TextEditingValue? get currentTextEditingValue {
    return _currentEditingState;
  }

  @override
  AutofillScope? get currentAutofillScope {
    return null;
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    final previousText = _currentEditingState.text;
    _currentEditingState = value;

    if (widget.deleteDetection) {
      _updateEditingValueWithDeleteDetection(value);
      return;
    }

    if (_desktopMode) {
      _updateEditingValueDesktop(value);
      return;
    }

    // Get input after composing is done
    if (!_currentEditingState.composing.isCollapsed) {
      final text = _currentEditingState.text;
      final composingText = _currentEditingState.composing.textInside(text);
      widget.onComposing(composingText);
      return;
    }

    widget.onComposing(null);

    final textDelta = _textDelta(_currentEditingState);
    final actionCommittedText = _actionCommittedText;

    if (actionCommittedText != null) {
      if (textDelta == actionCommittedText) {
        _actionCommittedText = null;
        _resetEditingState();
        return;
      }

      // Preserve input that arrives together with a delayed action commit.
      // This is uncommon, but it prevents losing a character if an IME batches
      // the next edit with its final composition commit.
      if (textDelta.startsWith(actionCommittedText)) {
        _actionCommittedText = null;
        final remainingText = textDelta.substring(actionCommittedText.length);
        if (remainingText.isNotEmpty) {
          widget.onInsert(remainingText);
        }
        _resetEditingState();
        return;
      }

      _actionCommittedText = null;
    }

    if (_currentEditingState.text.length < _initEditingState.text.length) {
      widget.onDelete();
    } else if (textDelta.isEmpty &&
        _currentEditingState.text == _initEditingState.text) {
      // The local buffer is already at its floor (empty, cursor at 0), so
      // there is nothing left for a backspace to shorten. Some soft
      // keyboards still emit this exact no-op editing value for that
      // keypress instead of staying silent - treat it as the delete it
      // represents rather than as an empty insert. Coming from an
      // uncommitted composition it is a cancel, not a delete: nothing was
      // sent that could be deleted.
      if (previousText == _initEditingState.text) widget.onDelete();
    } else {
      widget.onInsert(textDelta);
    }

    // Reset editing state if composing is done
    if (_currentEditingState.composing.isCollapsed &&
        _currentEditingState.text != _initEditingState.text) {
      _resetEditingState();
    }
  }

  /// Handles [updateEditingValue] for [CustomTextEdit.deleteDetection] mode.
  ///
  /// This mode pads the editing state with a sentinel (see
  /// [_initEditingState]) so a backspace at offset 0 always has something to
  /// remove, letting the deletion be derived from how much of the sentinel
  /// is left rather than from a raw text-length diff against empty.
  ///
  /// Composition must still work here. While `value.composing` is a genuine,
  /// still-open multi-character preview, emission is deferred and only the
  /// text the IME actually commits is emitted once composing closes.
  ///
  /// The complication is the pattern some Android keyboards (Gboard,
  /// Samsung, SwiftKey) produce for a single already-resolved keypress: they
  /// wrap it in a composing range that never collapses on its own (fixed by
  /// f6568e1). Such a range opens fresh with exactly one character in it -
  /// but so does a genuine preview, on its very first keystroke. A bare
  /// length check can't tell those apart, so instead this tracks whether an
  /// open composing range is being *extended in place*:
  ///
  ///   - a range whose base stays put and whose text keeps growing is a
  ///     real, still-open preview - keep deferring.
  ///   - a range that collapses is a resolved commit - emit it once.
  ///   - a *different* range appearing at the same base without the
  ///     previous one ever growing or collapsing is the f6568e1 shape: the
  ///     previous keystroke was already resolved and is never coming back,
  ///     so it is flushed now instead of waiting for a collapse that will
  ///     never arrive.
  void _updateEditingValueWithDeleteDetection(TextEditingValue value) {
    final text = value.text;
    final initLength = _initEditingState.text.length;

    // An out-of-band commit is echoed by the IME on the very next editing
    // value, if at all, so the guard lives for exactly this call. Holding it
    // any longer would swallow the same word typed again later.
    final actionCommittedText = _actionCommittedText;
    _actionCommittedText = null;

    if (value.composing.isValid) {
      final composingText = value.composing.textInside(text);
      final base = value.composing.start;
      final pending = _pendingComposingText;

      final isExtendingPending = pending != null &&
          base == _pendingComposingBase &&
          composingText.length > pending.length;

      if (isExtendingPending) {
        _pendingComposingText = composingText;
        widget.onComposing(composingText);
        return;
      }

      if (pending != null && pending.length > 1) {
        // The pending range already held more than one character, so it was
        // never an ambiguous fresh single-keystroke open - it was already a
        // confirmed, substantial preview (e.g. a pinyin buffer). Replacing
        // it wholesale, even with something shorter, is an ordinary step in
        // the same composition (e.g. picking a hanzi candidate), not the
        // f6568e1 trapped-keystroke shape, which only ever involves single
        // characters. Keep deferring.
        _pendingComposingText = composingText;
        _pendingComposingBase = base;
        widget.onComposing(composingText);
        return;
      }

      if (pending != null) {
        // The pending range was a single, unconfirmed character and has now
        // been replaced by another fresh range without ever growing or
        // collapsing - the previous keystroke is done and will never
        // collapse on its own (f6568e1), so flush it now. The replacement
        // is exactly as resolved as the one it replaced (nothing else has
        // arrived to prove otherwise), so it is flushed immediately too
        // rather than reopened as a new pending range.
        if (pending.isNotEmpty) {
          widget.onInsert(pending);
        }
        if (composingText.isNotEmpty) {
          widget.onInsert(composingText);
        }
        widget.onComposing(null);
        _resetEditingState();
        return;
      }

      // Freshly opened range, nothing pending yet. This might be the start
      // of a genuine preview or a trapped keystroke - hold it pending and
      // let the next update (extension, collapse, or replacement above)
      // decide, instead of assuming either way.
      _pendingComposingText = composingText;
      _pendingComposingBase = base;
      widget.onComposing(composingText);
      return;
    }

    widget.onComposing(null);
    _pendingComposingText = null;
    _pendingComposingBase = null;

    if (text.length < initLength) {
      final deleteCount = initLength - text.length;
      for (var i = 0; i < deleteCount; i++) {
        widget.onDelete();
      }
      _resetEditingState();
      return;
    }

    if (text.length > initLength) {
      final textDelta = text.substring(initLength);

      // A composition committed out of band — by an action (Enter) or by
      // [commitComposing] — is often echoed back by the IME a moment later as
      // its own delayed commit. It has already been emitted, so swallow the
      // echo instead of sending the whole word to the terminal a second time.
      if (actionCommittedText != null) {
        if (textDelta == actionCommittedText) {
          _resetEditingState();
          return;
        }

        // Some IMEs batch the next edit into that delayed commit. Only the
        // echoed part is dropped; the rest is genuinely new input.
        if (textDelta.startsWith(actionCommittedText)) {
          final remainingText = textDelta.substring(actionCommittedText.length);
          if (remainingText.isNotEmpty) {
            widget.onInsert(remainingText);
          }
          _resetEditingState();
          return;
        }
      }

      if (textDelta.isNotEmpty) {
        widget.onInsert(textDelta);
      }
      _resetEditingState();
      return;
    }

    if (text != _initEditingState.text) {
      _resetEditingState();
    }
  }

  /// Handles [updateEditingValue] on macOS and Linux, see [_desktopMode].
  ///
  /// The platform text is compared with what the terminal already has:
  /// appended text is sent as it is, and characters the input method rewrote
  /// after they were sent are taken back with a backspace each. A trailing
  /// Hangul character is not sent but shown as the composing preview, since
  /// that is the one the input method keeps rewriting (`ㅎ`, `하`, `한`, and
  /// `한` + `ㅏ` becoming `하나`); it is sent once something follows it, or on
  /// [_flushHeld]. Other text is sent at once, so single-key commands do not
  /// wait. An input method that marks its text (kana, pinyin) sets a
  /// composing range, which is shown as the preview as ever.
  void _updateEditingValueDesktop(TextEditingValue value) {
    final text = value.text;
    final composing = value.composing;

    if (!composing.isCollapsed) {
      _syncSent(text.substring(0, composing.start.clamp(0, text.length)));
      _held = '';
      widget.onComposing(composing.textInside(text));
      return;
    }

    final actionCommittedText = _actionCommittedText;
    _actionCommittedText = null;
    if (actionCommittedText != null && text == actionCommittedText) {
      widget.onComposing(null);
      _resetPending = true;
      return;
    }

    final endsInHangul =
        text.isNotEmpty && _isHangul(text.codeUnitAt(text.length - 1));
    _held = endsInHangul ? text.substring(text.length - 1) : '';
    _syncSent(endsInHangul ? text.substring(0, text.length - 1) : text);
    widget.onComposing(endsInHangul ? _held : null);

    if (!endsInHangul && text.isNotEmpty) {
      // Nothing the input method could still rewrite is left in the text.
      _resetPending = true;
    }
  }

  /// Makes the terminal's copy of the platform text equal to [target].
  String _syncSent(String target) {
    final sent = _sent;
    var common = 0;
    final limit = sent.length < target.length ? sent.length : target.length;
    while (common < limit &&
        sent.codeUnitAt(common) == target.codeUnitAt(common)) {
      common++;
    }
    // Never split a surrogate pair.
    if (common > 0 && _isHighSurrogate(sent.codeUnitAt(common - 1))) {
      common--;
    }
    _sent = target;
    final removed = sent.substring(common).runes.length;
    for (var i = 0; i < removed; i++) {
      widget.onDelete();
    }
    final added = target.substring(common);
    if (added.isNotEmpty) {
      widget.onInsert(added);
    }
    return added;
  }

  /// Sends the held Hangul character and drops the preview.
  void _flushHeld() {
    if (_held.isEmpty) return;
    final held = _held;
    _held = '';
    _sent = '';
    _clearPreview();
    widget.onInsert(held);
  }

  /// Takes the composing preview away. Closing the connection can happen
  /// while the framework builds (a read-only toggle) or tears the view down,
  /// when the preview's owner may not be told synchronously.
  void _clearPreview() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComposing(null);
      });
    } else {
      widget.onComposing(null);
    }
  }

  void _forgetDesktopState() {
    _sent = '';
    _held = '';
    _resetPending = false;
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  /// Hangul syllables and the conjoining and compatibility jamo.
  static bool _isHangul(int unit) =>
      (unit >= 0xAC00 && unit <= 0xD7A3) ||
      (unit >= 0x1100 && unit <= 0x11FF) ||
      (unit >= 0x3130 && unit <= 0x318F) ||
      (unit >= 0xA960 && unit <= 0xA97F) ||
      (unit >= 0xD7B0 && unit <= 0xD7FF) ||
      (unit >= 0xFFA0 && unit <= 0xFFDC);

  @override
  void performSelector(String selectorName) {
    // The macOS plugin turns the keys it has no handler for into selectors.
    // Backspace from a source that does not compose (ABC after Korean) comes
    // this way, and the held syllable is what it deletes: it was never sent.
    if (_desktopMode && _held.isNotEmpty && selectorName == 'deleteBackward:') {
      _held = '';
      _clearPreview();
      _resetEditingState();
    }
  }

  @override
  void performAction(TextInputAction action) {
    _commitComposingTextForAction();
    widget.onAction(action);
  }

  /// Commits a pending IME composition as terminal input, and reports whether
  /// there was one.
  ///
  /// Input that reaches the terminal from outside the keyboard — a mobile
  /// extra-keys bar, a paste button — is appended to what the terminal has
  /// already received, but an open composition has *not* been received yet: it
  /// is still sitting in the IME, deferred until the composition resolves. Send
  /// such input without committing first and it lands against a line the user
  /// cannot see the rest of, so `www` + Tab completes an empty line instead of
  /// `www`.
  ///
  /// Prefer this over [resetEditingState] for anything that types: resetting
  /// throws the composition away, which loses what the user typed.
  bool commitComposing() => _commitComposingTextForAction();

  String _textDelta(TextEditingValue value) {
    final initialTextLength = _initEditingState.text.length;
    if (value.text.length < initialTextLength) {
      return '';
    }

    return value.text.substring(initialTextLength);
  }

  /// Emits an open composition as input and clears it. Returns false when
  /// there was nothing composing.
  bool _commitComposingTextForAction() {
    if (_currentEditingState.composing.isCollapsed) {
      if (_desktopMode && (_held.isNotEmpty || _resetPending)) {
        final hadHeld = _held.isNotEmpty;
        _flushHeld();
        _resetEditingState();
        return hadHeld;
      }
      return false;
    }

    final String textDelta;
    if (_desktopMode) {
      // Everything before the composing range has been sent already.
      textDelta = _syncSent(_currentEditingState.text);
    } else {
      textDelta = _textDelta(_currentEditingState);
    }
    widget.onComposing(null);

    if (textDelta.isNotEmpty) {
      if (!_desktopMode) widget.onInsert(textDelta);
      _actionCommittedText = textDelta;
    }

    _resetEditingState();
    return true;
  }

  void _resetEditingState() {
    _currentEditingState = _initEditingState;
    _pendingComposingText = null;
    _pendingComposingBase = null;
    _sent = '';
    _held = '';
    _resetPending = false;
    _connection?.setEditingState(_initEditingState);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // print('updateFloatingCursor $point');
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // print('showAutocorrectionPromptRect');
  }

  @override
  void connectionClosed() {
    _flushHeld();
    _forgetDesktopState();
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // print('performPrivateCommand $action');
  }

  @override
  void insertTextPlaceholder(Size size) {
    // print('insertTextPlaceholder');
  }

  @override
  void removeTextPlaceholder() {
    // print('removeTextPlaceholder');
  }

  @override
  void showToolbar() {
    // print('showToolbar');
  }
}

/// What a key does while a Hangul character is held back.
enum _HeldKeyRoute {
  /// The input method gets it, possibly rewriting the held character.
  ime,

  /// The terminal handles it; the held character goes first.
  flush,

  /// Not a key that decides anything, such as a modifier or a key release.
  neutral,
}

final _modifierKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.altGraph,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
};
