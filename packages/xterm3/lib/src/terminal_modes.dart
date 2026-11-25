part of 'terminal.dart';

/// Holds every DEC/ANSI terminal mode flag together with the two reset
/// semantics ([reset] and [softReset]) that [Terminal.reset] and
/// [Terminal.softReset] delegate to.
///
/// Before this class existed, adding a new mode meant touching three call
/// sites by hand: the field declaration, [Terminal.reset], and
/// [Terminal.softReset], with no compiler help if one was missed. Bundling
/// the fields with their own reset methods here makes that a single-site
/// change again.
///
/// [reset] and [softReset] intentionally differ: full [reset] additionally
/// clears [_cursorLineHighlightMode], which [softReset] (DECSTR) does not
/// touch. This mirrors the exact behaviour of the original hand-written
/// `Terminal.reset`/`Terminal.softReset` methods and must not be
/// "normalized" away.
class _TerminalModes {
  _ProtectionMode _protectionMode = _ProtectionMode.off;

  bool _insertMode = false;

  bool _sendReceiveMode = true;

  bool _keyboardActionMode = false;

  bool _lineFeedMode = false;

  bool _cursorKeysMode = false;

  bool _reverseDisplayMode = false;

  bool _originMode = false;

  bool _enableColumnMode = false;

  bool _slowScrollMode = false;

  bool _autoWrapMode = true;

  bool _autoRepeatMode = false;

  bool _reverseWrapMode = false;

  bool _reverseWrapExtendedMode = false;

  MouseMode _mouseMode = MouseMode.none;

  MouseReportMode _mouseReportMode = MouseReportMode.normal;

  bool _cursorBlinkMode = false;

  bool _cursorVisibleMode = true;

  TerminalCursorType? _applicationCursorType;

  bool _appKeypadMode = false;

  bool _ignoreKeypadWithNumLockMode = true;

  bool _backarrowKeyMode = false;

  bool _reportFocusMode = false;

  bool _mouseShiftCaptureMode = false;

  bool _altBufferMouseScrollMode = false;

  bool _altEscPrefixMode = true;

  bool _altSendsEscapeMode = false;

  bool _bracketedPasteMode = false;

  bool _inBandSizeReportMode = false;

  bool _reportColorSchemeMode = false;

  bool _graphemeClusterMode = true;

  bool _leftRightMarginMode = false;

  bool _cursorLineHighlightMode = false;

  int _kittyKeyboardMode = 0;

  int _modifyOtherKeysMode = 0;

  final _kittyKeyboardModeStack = <int>[];

  bool _synchronizedUpdateMode = false;

  /// Full mode reset (RIS). Also clears [_cursorLineHighlightMode], unlike
  /// [softReset].
  void reset() {
    _synchronizedUpdateMode = false;
    _protectionMode = _ProtectionMode.off;
    _insertMode = false;
    _sendReceiveMode = true;
    _keyboardActionMode = false;
    _lineFeedMode = false;
    _cursorKeysMode = false;
    _reverseDisplayMode = false;
    _originMode = false;
    _enableColumnMode = false;
    _slowScrollMode = false;
    _autoWrapMode = true;
    _autoRepeatMode = false;
    _reverseWrapMode = false;
    _reverseWrapExtendedMode = false;
    _mouseMode = MouseMode.none;
    _mouseReportMode = MouseReportMode.normal;
    _cursorBlinkMode = false;
    _cursorVisibleMode = true;
    _applicationCursorType = null;
    _appKeypadMode = false;
    _ignoreKeypadWithNumLockMode = true;
    _backarrowKeyMode = false;
    _reportFocusMode = false;
    _mouseShiftCaptureMode = false;
    _altBufferMouseScrollMode = false;
    _altEscPrefixMode = true;
    _altSendsEscapeMode = false;
    _bracketedPasteMode = false;
    _inBandSizeReportMode = false;
    _reportColorSchemeMode = false;
    _graphemeClusterMode = true;
    _leftRightMarginMode = false;
    _cursorLineHighlightMode = false;
    _kittyKeyboardMode = 0;
    _modifyOtherKeysMode = 0;
    _kittyKeyboardModeStack.clear();
  }

  /// Soft mode reset (DECSTR). Does not touch [_cursorLineHighlightMode].
  void softReset() {
    _synchronizedUpdateMode = false;
    _protectionMode = _ProtectionMode.off;
    _insertMode = false;
    _sendReceiveMode = true;
    _keyboardActionMode = false;
    _lineFeedMode = false;
    _cursorKeysMode = false;
    _reverseDisplayMode = false;
    _originMode = false;
    _enableColumnMode = false;
    _slowScrollMode = false;
    _autoWrapMode = true;
    _autoRepeatMode = false;
    _reverseWrapMode = false;
    _reverseWrapExtendedMode = false;
    _mouseMode = MouseMode.none;
    _mouseReportMode = MouseReportMode.normal;
    _cursorBlinkMode = false;
    _cursorVisibleMode = true;
    _applicationCursorType = null;
    _appKeypadMode = false;
    _ignoreKeypadWithNumLockMode = true;
    _backarrowKeyMode = false;
    _reportFocusMode = false;
    _mouseShiftCaptureMode = false;
    _altBufferMouseScrollMode = false;
    _altEscPrefixMode = true;
    _altSendsEscapeMode = false;
    _bracketedPasteMode = false;
    _inBandSizeReportMode = false;
    _reportColorSchemeMode = false;
    _graphemeClusterMode = true;
    _leftRightMarginMode = false;
    _kittyKeyboardMode = 0;
    _modifyOtherKeysMode = 0;
    _kittyKeyboardModeStack.clear();
  }
}
