import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' show max, min;

import 'package:meta/meta.dart';
import 'package:xterm3/src/base/observable.dart';
import 'package:xterm3/src/core/buffer/buffer.dart';
import 'package:xterm3/src/core/buffer/cell_offset.dart';
import 'package:xterm3/src/core/buffer/line.dart';
import 'package:xterm3/src/core/cell.dart';
import 'package:xterm3/src/core/color_scheme.dart';
import 'package:xterm3/src/core/cursor.dart';
import 'package:xterm3/src/core/escape/emitter.dart';
import 'package:xterm3/src/core/escape/handler.dart';
import 'package:xterm3/src/core/escape/parser.dart';
import 'package:xterm3/src/core/input/handler.dart';
import 'package:xterm3/src/core/input/keys.dart';
import 'package:xterm3/src/core/mouse/button.dart';
import 'package:xterm3/src/core/mouse/button_state.dart';
import 'package:xterm3/src/core/mouse/handler.dart';
import 'package:xterm3/src/core/mouse/mode.dart';
import 'package:xterm3/src/core/mouse/modifiers.dart';
import 'package:xterm3/src/core/platform.dart';
import 'package:xterm3/src/core/state.dart';
import 'package:xterm3/src/core/tabs.dart';
import 'package:xterm3/src/utils/ascii.dart';
import 'package:xterm3/src/utils/circular_buffer.dart';
import 'package:xterm3/src/utils/escape_format.dart';

part 'terminal_clipboard.dart';
part 'terminal_colors.dart';
part 'terminal_context_signal.dart';
part 'terminal_device_settings.dart';
part 'terminal_modes.dart';
part 'terminal_paste.dart';
part 'terminal_semantic_prompt.dart';
part 'terminal_sgr.dart';
part 'terminal_status_string.dart';
part 'terminal_terminfo.dart';

enum _ProtectionMode { off, iso, dec }

/// [Terminal] is an interface to interact with command line applications. It
/// translates escape sequences from the application into updates to the
/// [buffer] and events such as [onTitleChange] or [onBell], as well as
/// translating user input into escape sequences that the application can
/// understand.
class Terminal
    with Observable, _SgrHandlers, _ContextSignalHandlers, _StatusStringReports
    implements TerminalState, EscapeHandler, EscapeTextHandler {
  static const _maxHyperlinks = 4096;
  static const _maxHyperlinkId =
      CellAttr.hyperlinkMask >> CellAttr.hyperlinkShift;
  static const _maxKittyKeyboardModeStackDepth = 4096;
  static const _maxTitleStackDepth = 4096;
  static const _kittyKeyboardModeMask = 0x1f;
  static const _specialColorBaseIndex = 256;
  static const _specialColorCount = 5;
  static const _maxRemoteResize = 1000;

  /// The number of lines that the scrollback buffer can hold. If the buffer
  /// exceeds this size, the lines at the top of the buffer will be removed.
  final int maxLines;

  /// Function that is called when the program requests the terminal to ring
  /// the bell. If not set, the terminal will do nothing.
  void Function()? onBell;

  /// Function that is called when the program requests the terminal to change
  /// the title of the window to [title].
  void Function(String title)? onTitleChange;

  /// Function that is called when the program requests the terminal to change
  /// the icon of the window. `icon` is the name of the icon.
  void Function(String icon)? onIconChange;

  /// Called when the application reports its current directory using OSC 7.
  void Function(String uri)? onCurrentDirectoryChange;

  /// Called when the application reports its remote user/host using OSC 1337.
  void Function(String value)? onRemoteHostChange;

  /// Called when the application reports an iTerm2 user variable.
  void Function(String name, String value)? onUserVariableChange;

  /// Resolves an iTerm2 session variable for OSC 1337 ReportVariable queries.
  String? Function(String name)? onITerm2VariableQuery;

  /// Called when the application sets the iTerm2 badge format.
  void Function(String format)? onITerm2BadgeFormatChange;

  /// Called when the application reports its iTerm2 shell integration version.
  void Function(String version)? onITerm2ShellIntegrationVersionChange;

  /// Called when the application sets an iTerm2 mark at the cursor.
  void Function()? onITerm2Mark;

  /// Called when the application requests an iTerm2 profile change.
  void Function(String profile)? onITerm2ProfileChange;

  /// Called when the application requests terminal focus.
  void Function()? onFocusRequest;

  /// Called when the application requests opening a URL.
  void Function(String url)? onOpenUrl;

  /// Called when the application requests user attention.
  void Function(String value)? onAttentionRequest;

  /// Called when the application requests a desktop notification using
  /// OSC 9 or OSC 777.
  void Function(String title, String body)? onNotification;

  /// Called when the application requests a mouse pointer shape using OSC 22.
  void Function(String shape)? onMouseShapeChange;

  /// Called when the application reports task progress using OSC 9;4.
  void Function(TerminalProgressReport report)? onProgressReport;

  /// Called when the application reports shell-integration prompt state using
  /// OSC 133.
  void Function(TerminalSemanticPromptState state)? onSemanticPrompt;

  /// Called when the application reports a hierarchical context update using
  /// OSC 3008.
  @override
  void Function(TerminalContextSignal signal)? onContextSignal;

  /// Resolves the currently displayed color for OSC color queries. [code] is
  /// 4 for an indexed color, 5 for a special attribute color, or 10–12 for
  /// dynamic colors; [index] is provided only for code 4 or 5. The return value
  /// is a 24-bit RGB color.
  int? Function(int code, int? index)? onColorQuery;

  /// Resolves the current terminal color scheme for CSI ? 996 n queries.
  /// Return null to ignore the query.
  TerminalColorScheme? Function()? onColorSchemeQuery;

  /// Resolves the terminal version string for XTVERSION (CSI > q) queries.
  /// Return null or an empty string to use the default xterm3 version.
  String? Function()? onXtVersionQuery;

  /// Called when the application sends ENQ (0x05). Return null or an empty
  /// string to keep the request silent.
  String? Function()? onEnquiry;

  /// Called when the application requests copying text through OSC 52.
  ///
  /// [selector] is usually `c` for clipboard or `p`/`s` for primary selection.
  /// Leave this unset to deny clipboard writes.
  void Function(String selector, String text)? onClipboardStore;

  /// Called when the application requests clipboard contents through OSC 52.
  ///
  /// Leave this unset to deny clipboard reads: `TerminalView` does not install
  /// a default, since any remote output could then read the user's clipboard.
  /// Return null to deny a request. The result may be asynchronous.
  FutureOr<String?> Function(String selector)? onClipboardQuery;

  /// Function that is called when the terminal emits data to the underlying
  /// program. This is typically caused by user inputs from [textInput],
  /// [keyInput], [mouseInput], or [paste].
  ///
  /// Unless [onReply] is set, this also receives the data the terminal sends
  /// on its own initiative — see there.
  void Function(String data)? onOutput;

  /// Function that is called when the terminal answers the program by itself:
  /// device attributes, status and cursor-position reports, colour and size
  /// queries, terminfo capabilities, focus reports, OSC 52 clipboard reads.
  ///
  /// These bytes travel the same wire as user input and the program cannot
  /// tell them apart — but the embedder can, and sometimes must. An embedder
  /// that treats traffic on [onOutput] as "the user is typing" (to hand
  /// control back from a mirroring device, say) will otherwise be fooled the
  /// moment a full-screen program probes the terminal at startup.
  ///
  /// Leave it null and replies go to [onOutput], as they always have.
  void Function(String data)? onReply;

  /// Where a self-initiated reply goes: [onReply] when the embedder asked for
  /// the distinction, [onOutput] otherwise.
  void Function(String data)? get _replySink => onReply ?? onOutput;

  /// Function that is called when the dimensions of the terminal change.
  void Function(int width, int height, int pixelWidth, int pixelHeight)?
      onResize;

  /// The [TerminalInputHandler] used by this terminal. [defaultInputHandler] is
  /// used when not specified. User of this class can provide their own
  /// implementation of [TerminalInputHandler] or extend [defaultInputHandler]
  /// with [CascadeInputHandler].
  TerminalInputHandler? inputHandler;

  TerminalMouseHandler? mouseHandler;

  /// The callback that is called when the terminal receives a unrecognized
  /// escape sequence.
  void Function(String code, List<String> args)? onPrivateOSC;

  /// Diagnostic hook for escape sequences the parser does not recognise.
  ///
  /// This fires for sequences the terminal deliberately ignores — an
  /// unknown `ESC` dispatch, an unrecognised CSI final byte, an
  /// unrecognised OSC `Ps`, or a DCS payload that matches no known
  /// request. Ignoring unrecognised input is correct terminal behaviour and
  /// this callback does not change that; it only lets you observe it.
  /// `raw` contains the sequence as received, including the leading `ESC`,
  /// formatted for readability (control bytes rendered as `^0x..`, `ESC`
  /// spelled out, etc.) rather than as literal control characters.
  ///
  /// This is a diagnostic tool meant for answering "why isn't my escape
  /// sequence working?" during development. It is not intended to be left
  /// enabled in production: building the diagnostic text has a real cost,
  /// paid only when this callback is set.
  void Function(String raw)? onUnknownSequence;

  /// Flag to toggle os specific behaviors.
  final TerminalTargetPlatform platform;

  /// Characters that break selection when double clicking. If not set, the
  /// [Buffer.defaultWordSeparators] will be used.
  final Set<int>? wordSeparators;

  Terminal({
    this.maxLines = 1000,
    this.onBell,
    this.onTitleChange,
    this.onIconChange,
    this.onCurrentDirectoryChange,
    this.onRemoteHostChange,
    this.onUserVariableChange,
    this.onITerm2VariableQuery,
    this.onITerm2BadgeFormatChange,
    this.onITerm2ShellIntegrationVersionChange,
    this.onITerm2Mark,
    this.onITerm2ProfileChange,
    this.onFocusRequest,
    this.onOpenUrl,
    this.onAttentionRequest,
    this.onNotification,
    this.onMouseShapeChange,
    this.onProgressReport,
    this.onSemanticPrompt,
    this.onContextSignal,
    this.onColorQuery,
    this.onColorSchemeQuery,
    this.onXtVersionQuery,
    this.onEnquiry,
    this.onClipboardStore,
    this.onClipboardQuery,
    this.onOutput,
    this.onResize,
    this.platform = TerminalTargetPlatform.unknown,
    this.inputHandler = defaultInputHandler,
    this.mouseHandler = defaultMouseHandler,
    this.onPrivateOSC,
    this.onUnknownSequence,
    this.reflowEnabled = true,
    this.wordSeparators,
    this.allowRemoteResize = false,
  });

  late final _parser = EscapeParser(this);

  final _emitter = const EscapeEmitter();

  final Map<int, String> _hyperlinks = {};

  final Map<String, int> _explicitHyperlinkIds = {};

  /// Reverse lookup of [_explicitHyperlinkIds], so a hyperlink id can be
  /// resolved to its explicit-id key (if any) in O(1) instead of scanning
  /// the whole map. Kept in sync wherever [_explicitHyperlinkIds] is
  /// written to or cleared.
  final Map<int, String> _explicitHyperlinkKeyByHyperlinkId = {};

  /// Hyperlink ids collected from evicted scrollback lines that have not yet
  /// been checked against the live buffers. See
  /// [_onScrollbackLineEvicted] for why this is batched instead of resolved
  /// immediately.
  final Set<int> _pendingEvictedHyperlinkIds = {};

  /// Fewest distinct evicted hyperlink ids to accumulate before spending a
  /// full buffer scan to resolve them. See [_hyperlinkScanInterval].
  static const _hyperlinkEvictionBatchSize = 128;

  /// How many hyperlink events - evicted ids, or opens once the registry has
  /// hit the [_maxHyperlinks] ceiling - to let pass between two scans of both
  /// buffers.
  ///
  /// A scan costs the whole buffer, so the interval has to grow with the
  /// buffer or the cost per line grows instead. At a fixed 128, output with a
  /// link on every line (`ls --hyperlink`) paid a scan of 10000 lines every
  /// 128 lines; a quarter of the line count keeps that near the cost of
  /// reading a few lines per line written. Half the ceiling caps it, so dead
  /// links waiting for a scan can never fill the registry on their own.
  int get _hyperlinkScanInterval => max(
        _hyperlinkEvictionBatchSize,
        min(_mainBuffer.lines.length ~/ 4, _maxHyperlinks ~/ 2),
      );

  /// Link opens still to go before the registry may be pruned at the ceiling
  /// again. A prune scans both buffers, and with a scrollback full of live
  /// links it frees nothing, or only the few links that scrolled out since
  /// the last one - so pruning on every open at the ceiling was a scan per
  /// link written, 1.9 ms a line at 10000 lines. Opens that find the registry
  /// full while this runs down get no link, as they did when a prune freed
  /// nothing.
  var _hyperlinkPruneCooldown = 0;

  /// Count of `getHyperlinkId` cell inspections spent resolving evicted
  /// hyperlinks. Exposed via [debugHyperlinkEvictionScanCells] for tests
  /// only.
  int _hyperlinkEvictionScanCellsForTesting = 0;

  final _colors = _ColorRegistry();

  final _clipboardCapture = _ClipboardCapture();

  @override
  final _settings = _DeviceSettings();

  final _semanticPrompt = _SemanticPromptTracker();
  final Queue<CellAnchor> _semanticPromptAnchors = Queue<CellAnchor>();

  int _nextHyperlinkId = 1;

  int get colorRevision => _colors._colorRevision;

  TerminalSemanticPromptState get semanticPromptState => _semanticPrompt.state;

  /// Returns whether [line] starts a primary semantic prompt.
  bool isSemanticPromptLine(int line) {
    _pruneSemanticPromptAnchors();
    for (final anchor in _semanticPromptAnchors) {
      if (anchor.y == line) return true;
      if (anchor.y > line) return false;
    }
    return false;
  }

  /// Finds the nearest primary semantic prompt strictly before [line].
  int? semanticPromptLineBefore(int line) {
    _pruneSemanticPromptAnchors();
    int? result;
    for (final anchor in _semanticPromptAnchors) {
      if (anchor.y >= line) break;
      result = anchor.y;
    }
    return result;
  }

  /// Finds the nearest primary semantic prompt strictly after [line].
  int? semanticPromptLineAfter(int line) {
    _pruneSemanticPromptAnchors();
    for (final anchor in _semanticPromptAnchors) {
      if (anchor.y > line) return anchor.y;
    }
    return null;
  }

  Iterable<MapEntry<int, int>> get indexedColorOverrides {
    return _colors._indexedColorOverrides.entries;
  }

  Iterable<MapEntry<int, int>> get specialColorOverrides {
    return _colors._specialColorOverrides.entries;
  }

  int? get foregroundColorOverride => _colors._foregroundColorOverride;

  int? get backgroundColorOverride => _colors._backgroundColorOverride;

  int? get cursorColorOverride => _colors._cursorColorOverride;

  int? get selectionColorOverride => _colors._selectionColorOverride;

  int? get selectionForegroundColorOverride =>
      _colors._selectionForegroundColorOverride;

  @override
  late var _buffer = _mainBuffer;

  late final _mainBuffer = Buffer(
    this,
    maxLines: maxLines,
    isAltBuffer: false,
    wordSeparators: wordSeparators,
    onLineEvicted: _onScrollbackLineEvicted,
  );

  late final _altBuffer = Buffer(
    this,
    maxLines: maxLines,
    isAltBuffer: true,
    wordSeparators: wordSeparators,
    onLineEvicted: _onScrollbackLineEvicted,
  );

  final _tabStops = TabStops();

  /// The last character written to the buffer. Used to implement some escape
  /// sequences that repeat the last character.
  var _precedingCodepoint = 0;

  /* TerminalState */

  @override
  int _viewWidth = 80;

  @override
  int _viewHeight = 24;

  int _cellPixelWidth = 0;

  int _cellPixelHeight = 0;

  @override
  final _cursorStyle = CursorStyle();

  @override
  final _modes = _TerminalModes();

  TerminalCursorType? get applicationCursorType =>
      _modes._applicationCursorType;

  bool _focused = true;

  bool get cursorLineHighlightMode => _modes._cursorLineHighlightMode;

  @override
  final _assignedColors = <int, ({int foreground, int background})>{};

  Timer? _synchronizedUpdateTimer;

  final _savedDecModes = <int, bool>{};

  String? _title;

  String? _iconTitle;

  final _titleStack = <String?>[];

  bool _isDisposed = false;

  var _writing = false;

  /* State getters */

  /// Number of cells in a terminal row.
  @override
  int get viewWidth => _viewWidth;

  /// Number of rows in this terminal.
  @override
  int get viewHeight => _viewHeight;

  @override
  CursorStyle get cursor => _cursorStyle;

  @override
  bool get insertMode => _modes._insertMode;

  @override
  bool get lineFeedMode => _modes._lineFeedMode;

  @override
  bool get cursorKeysMode => _modes._cursorKeysMode;

  @override
  bool get reverseDisplayMode => _modes._reverseDisplayMode;

  @override
  bool get originMode => _modes._originMode;

  @override
  bool get autoWrapMode => _modes._autoWrapMode;

  @override
  bool get reverseWrapMode => _modes._reverseWrapMode;

  @override
  bool get reverseWrapExtendedMode => _modes._reverseWrapExtendedMode;

  @override
  MouseMode get mouseMode => _modes._mouseMode;

  @override
  MouseReportMode get mouseReportMode => _modes._mouseReportMode;

  @override
  bool get cursorBlinkMode => _modes._cursorBlinkMode;

  @override
  bool get cursorVisibleMode => _modes._cursorVisibleMode;

  @override
  bool get appKeypadMode => _modes._appKeypadMode;

  @override
  bool get ignoreKeypadWithNumLockMode => _modes._ignoreKeypadWithNumLockMode;

  @override
  bool get backarrowKeyMode => _modes._backarrowKeyMode;

  @override
  bool get reportFocusMode => _modes._reportFocusMode;

  @override
  bool get mouseShiftCaptureMode => _modes._mouseShiftCaptureMode;

  @override
  bool get altBufferMouseScrollMode => _modes._altBufferMouseScrollMode;

  @override
  bool get altEscPrefixMode => _modes._altEscPrefixMode;

  @override
  bool get altSendsEscapeMode => _modes._altSendsEscapeMode;

  @override
  bool get bracketedPasteMode => _modes._bracketedPasteMode;

  @override
  bool get inBandSizeReportMode => _modes._inBandSizeReportMode;

  @override
  bool get reportColorSchemeMode => _modes._reportColorSchemeMode;

  @override
  bool get graphemeClusterMode => _modes._graphemeClusterMode;

  @override
  int get kittyKeyboardMode => _modes._kittyKeyboardMode;

  @override
  int get modifyOtherKeysMode => _modes._modifyOtherKeysMode;

  /// Current active buffer of the terminal. This is initially [mainBuffer] and
  /// can be switched back and forth from [altBuffer] to [mainBuffer] when
  /// the underlying program requests it.
  Buffer get buffer => _buffer;

  Buffer get mainBuffer => _mainBuffer;

  Buffer get altBuffer => _altBuffer;

  bool get isUsingAltBuffer => _buffer == _altBuffer;

  /// Lines of the active buffer.
  IndexAwareCircularBuffer<BufferLine> get lines => _buffer.lines;

  String? hyperlinkAt(CellOffset position) {
    final hyperlinkId = hyperlinkIdAt(position);
    if (hyperlinkId == 0) return null;
    return _hyperlinks[hyperlinkId];
  }

  int hyperlinkIdAt(CellOffset position) {
    final line = _buffer.lines.elementAtOrNull(position.y);
    if (line == null) return 0;
    if (position.x < 0 || position.x >= line.length) return 0;
    return line.getHyperlinkId(position.x);
  }

  /// Whether the terminal performs reflow when the viewport size changes or
  /// simply truncates lines. true by default.
  @override
  bool reflowEnabled;

  /// Whether the application may resize the terminal through escape
  /// sequences (`CSI 8 ; rows ; cols t`, `CSI Ps t` with Ps >= 24, DECSCPP
  /// and DECSNLS). false by default, matching xterm's `allowWindowOps`: such
  /// requests are ignored and only [resize] called by the embedder changes the
  /// size. When enabled, requested sizes are clamped to 1..1000 columns and
  /// rows.
  bool allowRemoteResize;

  /// Writes the data from the underlying program to the terminal. Calling this
  /// updates the states of the terminal and emits events such as [onBell] or
  /// [onTitleChange] when the escape sequences in [data] request it.
  void write(String data) {
    if (_isDisposed) return;
    assert(!_writing, 'Terminal.write() is not reentrant');
    _writing = true;
    try {
      _parser.write(data);
    } finally {
      _writing = false;
    }
    if (_modes._synchronizedUpdateMode) return;
    notifyListeners();
  }

  /// Clears the viewport and scrollback, then moves renderers to the bottom.
  void clear() {
    if (_isDisposed) return;
    final activePrompt = _activeSemanticPromptOffset();
    _buffer.clear();
    _restoreActiveSemanticPrompt(activePrompt);
    if (_modes._synchronizedUpdateMode) return;
    notifyListeners();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _synchronizedUpdateTimer?.cancel();
    _synchronizedUpdateTimer = null;
    _modes._synchronizedUpdateMode = false;
    clearListeners();
    _clipboardCapture.reset();
    _clearSemanticPromptAnchors();
    _hyperlinks.clear();
    _explicitHyperlinkIds.clear();
    _explicitHyperlinkKeyByHyperlinkId.clear();
    _pendingEvictedHyperlinkIds.clear();
  }

  /// Sends a key event to the underlying program.
  ///
  /// See also:
  /// - [charInput]
  /// - [textInput]
  /// - [paste]
  bool keyInput(
    TerminalKey key, {
    bool shift = false,
    bool alt = false,
    bool ctrl = false,
    bool superKey = false,
    bool capsLock = false,
    bool numLock = false,
    TerminalKeyEventType type = TerminalKeyEventType.press,
    String? text,
  }) {
    if (_isDisposed) return false;
    if (_modes._keyboardActionMode) return false;
    final output = inputHandler?.call(
      TerminalKeyboardEvent(
        key: key,
        shift: shift,
        alt: alt,
        ctrl: ctrl,
        superKey: superKey,
        capsLock: capsLock,
        numLock: numLock,
        state: this,
        altBuffer: isUsingAltBuffer,
        platform: platform,
        type: type,
        text: text,
      ),
    );

    if (output != null) {
      onOutput?.call(output);
      return true;
    }

    return false;
  }

  /// Similary to [keyInput], but takes a character as input instead of a
  /// [TerminalKey].
  ///
  /// See also:
  /// - [keyInput]
  /// - [textInput]
  /// - [paste]
  bool charInput(
    int charCode, {
    bool alt = false,
    bool ctrl = false,
  }) {
    if (_isDisposed) return false;
    if (_modes._keyboardActionMode) return false;
    if (ctrl) {
      // a(97) ~ z(122)
      if (charCode >= Ascii.a && charCode <= Ascii.z) {
        final output = charCode - Ascii.a + 1;
        onOutput?.call(String.fromCharCode(output));
        return true;
      }

      // [(91) ~ _(95)
      if (charCode >= Ascii.openBracket && charCode <= Ascii.underscore) {
        final output = charCode - Ascii.openBracket + 27;
        onOutput?.call(String.fromCharCode(output));
        return true;
      }
    }

    if (alt && platform != TerminalTargetPlatform.macos) {
      if (charCode >= Ascii.a && charCode <= Ascii.z) {
        final code = charCode - Ascii.a + 65;
        final input = [0x1b, code];
        onOutput?.call(String.fromCharCodes(input));
        return true;
      }
    }

    return false;
  }

  /// Sends regular text input to the underlying program.
  ///
  /// See also:
  /// - [keyInput]
  /// - [charInput]
  /// - [paste]
  void textInput(String text) {
    if (_isDisposed) return;
    if (_modes._keyboardActionMode) return;
    onOutput?.call(text);
  }

  /// Similar to [textInput], except that when the program tells the terminal
  /// that it supports [bracketedPasteMode], the text is wrapped in escape
  /// sequences to indicate that it is a paste operation. Prefer this method
  /// over [textInput] when pasting text.
  ///
  /// See also:
  /// - [textInput]
  void paste(String text) {
    if (_isDisposed) return;
    if (_modes._keyboardActionMode) return;
    final sanitizedText = _sanitizePasteText(text);
    if (_modes._bracketedPasteMode) {
      onOutput?.call(_emitter.bracketedPaste(sanitizedText));
      return;
    }

    if (!sanitizedText.contains('\n')) {
      onOutput?.call(sanitizedText);
      return;
    }
    onOutput?.call(sanitizedText.replaceAll(_pasteLineBreak, '\r'));
  }

  /// Returns whether [text] is safe enough to paste without user confirmation.
  ///
  /// This follows the same protection model used by modern terminals such as
  /// Ghostty: newlines and bracketed-paste terminators can inject commands,
  /// while terminal control bytes can alter terminal state. [paste] still
  /// sanitizes the payload; this method is for UI confirmation decisions.
  static bool isPasteSafe(String text) => _isPasteSafe(text);

  /// Reports a terminal viewport focus change to the underlying application.
  void focusInput(bool focused) {
    _focused = focused;
    if (_isDisposed) return;
    if (!_modes._reportFocusMode) return;
    _replySink?.call(switch (focused) {
      true => _emitter.focusIn(),
      false => _emitter.focusOut(),
    });
  }

  // Handle a mouse event and return true if it was handled.
  bool mouseInput(
    TerminalMouseButton button,
    TerminalMouseButtonState buttonState,
    CellOffset position, {
    bool motion = false,
    TerminalMouseModifiers modifiers = TerminalMouseModifiers.none,
    CellOffset? pixelPosition,
  }) {
    if (_isDisposed) return false;
    final output = mouseHandler?.call(TerminalMouseEvent(
      button: button,
      buttonState: buttonState,
      position: position,
      pixelPosition: pixelPosition,
      state: this,
      platform: platform,
      motion: motion,
      modifiers: modifiers,
    ));
    if (output != null) {
      onOutput?.call(output);
      return true;
    }
    return false;
  }

  /// Resize the terminal screen. [newWidth] and [newHeight] should be greater
  /// than 0. Main-buffer text is reflowed when [reflowEnabled] is true.
  @override
  void resize(
    int newWidth,
    int newHeight, [
    int? pixelWidth,
    int? pixelHeight,
  ]) {
    if (_isDisposed) return;
    newWidth = max(newWidth, 1);
    newHeight = max(newHeight, 1);

    final nextCellPixelWidth = pixelWidth ?? _cellPixelWidth;
    final nextCellPixelHeight = pixelHeight ?? _cellPixelHeight;
    final wasSynchronizedUpdateMode = _modes._synchronizedUpdateMode;
    if (wasSynchronizedUpdateMode) {
      _synchronizedUpdateTimer?.cancel();
      _synchronizedUpdateTimer = null;
      _modes._synchronizedUpdateMode = false;
    }

    if (newWidth == _viewWidth &&
        newHeight == _viewHeight &&
        nextCellPixelWidth == _cellPixelWidth &&
        nextCellPixelHeight == _cellPixelHeight) {
      if (wasSynchronizedUpdateMode) notifyListeners();
      if (_modes._inBandSizeReportMode &&
          pixelWidth != null &&
          pixelHeight != null) {
        _sendInBandSizeReport();
      }
      return;
    }

    final widthChanged = newWidth != _viewWidth;

    onResize?.call(newWidth, newHeight, pixelWidth ?? 0, pixelHeight ?? 0);
    if (pixelWidth != null) {
      _cellPixelWidth = pixelWidth;
    }
    if (pixelHeight != null) {
      _cellPixelHeight = pixelHeight;
    }

    //we need to resize both buffers so that they are ready when we switch between them
    _altBuffer.resize(_viewWidth, _viewHeight, newWidth, newHeight);
    _mainBuffer.resize(_viewWidth, _viewHeight, newWidth, newHeight);

    _viewWidth = newWidth;
    _viewHeight = newHeight;

    if (widthChanged) {
      _tabStops.reset();
    }

    if (buffer == _altBuffer) {
      buffer.clearScrollback();
    }

    _altBuffer.resetVerticalMargins();
    _mainBuffer.resetVerticalMargins();

    if (wasSynchronizedUpdateMode) notifyListeners();
    if (_modes._inBandSizeReportMode) _sendInBandSizeReport();
  }

  @override
  void setColumnsPerPage(int cols) {
    if (!allowRemoteResize) return;
    resize(cols.clamp(1, _maxRemoteResize), _viewHeight);
  }

  @override
  void setLinesPerPage(int rows) {
    if (!allowRemoteResize) return;
    resize(_viewWidth, rows.clamp(1, _maxRemoteResize));
  }

  @override
  void setConformanceLevel(int level, int controls) {
    _settings.setConformanceLevel(level, controls);
  }

  @override
  String toString() {
    return 'Terminal(#$hashCode, $_viewWidth x $_viewHeight, ${_buffer.height} lines)';
  }

  /* Handlers */

  @override
  void writeChar(int char) {
    _captureITerm2ClipboardChar(char);
    final cellWidth = _buffer.writeChar(char);
    if (cellWidth > 0) {
      _precedingCodepoint = char;
    }
  }

  @override
  void writeText(String text, int start, int end) {
    if (start >= end) return;
    _captureITerm2ClipboardTextRange(text, start, end);
    _buffer.writeAscii(text, start, end);
    _precedingCodepoint = text.codeUnitAt(end - 1);
  }

  /* SBC */

  @override
  void enquiry() {
    final response = onEnquiry?.call();
    if (response == null || response.isEmpty) return;
    _replySink?.call(response);
  }

  @override
  void bell() {
    onBell?.call();
  }

  @override
  void backspaceReturn() {
    _buffer.moveCursorX(-1);
  }

  @override
  void tab() {
    _captureITerm2ClipboardChar(Ascii.HT);
    final rightLimit = _horizontalTabRightLimit();
    if (_buffer.cursorX >= rightLimit) return;

    _markHorizontalTabOrigin();

    final nextStop = _tabStops.find(_buffer.cursorX + 1, rightLimit + 1);

    if (nextStop != null) {
      _buffer.setCursorX(nextStop);
    } else {
      _buffer.setCursorX(rightLimit);
    }
  }

  void _markHorizontalTabOrigin() {
    final line = _buffer.currentLine;
    final column = _buffer.cursorX;
    if (line.getCodePoint(column) != 0) return;
    if (column > 0 && line.getWidth(column - 1) == 2) return;

    line.setCell(column, Ascii.HT, 1, _cursorStyle);
  }

  @override
  void lineFeed() {
    _captureITerm2ClipboardChar(Ascii.LF);
    _buffer.lineFeed();
    _semanticPromptLineFeed();
  }

  @override
  void carriageReturn() {
    _captureITerm2ClipboardChar(Ascii.CR);
    _buffer.carriageReturn();
  }

  @override
  void shiftOut() {
    _buffer.charset.use(1);
  }

  @override
  void shiftIn() {
    _buffer.charset.use(0);
  }

  @override
  void unknownSBC(int char) {
    // no-op
  }

  /* ANSI sequence */

  @override
  void saveCursor() {
    _buffer.saveCursor(originMode: _modes._originMode);
  }

  @override
  void saveCursorOrSetLeftRightMargins() {
    if (_modes._leftRightMarginMode) {
      return setLeftRightMargins(0);
    }
    saveCursor();
  }

  @override
  void restoreCursor() {
    _modes._originMode = _buffer.restoreCursor();
  }

  @override
  void index() {
    _buffer.index();
  }

  @override
  void nextLine() {
    _buffer.carriageReturn();
    _buffer.index();
  }

  @override
  void setTapStop() {
    _tabStops.setAt(_buffer.cursorX);
  }

  @override
  void reset() {
    _synchronizedUpdateTimer?.cancel();
    _synchronizedUpdateTimer = null;
    _buffer = _mainBuffer;
    _precedingCodepoint = 0;
    _semanticPrompt.reset();
    _clearSemanticPromptAnchors();
    _cursorStyle.reset();
    _cursorStyle.hyperlinkId = 0;
    _cursorStyle.semanticAttrs = 0;
    _modes.reset();
    _savedDecModes.clear();
    _assignedColors.clear();
    _resetColorOverrides();
    _title = null;
    _iconTitle = null;
    _clipboardCapture.reset();
    _titleStack.clear();
    _hyperlinks.clear();
    _explicitHyperlinkIds.clear();
    _explicitHyperlinkKeyByHyperlinkId.clear();
    _pendingEvictedHyperlinkIds.clear();
    _nextHyperlinkId = 1;
    _tabStops.reset();
    _mainBuffer.reset();
    _altBuffer.reset();
  }

  void _resetColorOverrides() {
    _colors._indexedColorOverrides.clear();
    _colors._specialColorOverrides.clear();
    _colors._auxiliaryDynamicColorOverrides.clear();
    _colors._foregroundColorOverride = null;
    _colors._backgroundColorOverride = null;
    _colors._cursorColorOverride = null;
    _colors._selectionColorOverride = null;
    _colors._selectionForegroundColorOverride = null;
    _colors._colorRevision++;
  }

  @override
  void softReset() {
    _synchronizedUpdateTimer?.cancel();
    _synchronizedUpdateTimer = null;
    _precedingCodepoint = 0;
    _semanticPrompt.reset();
    _cursorStyle.reset();
    _cursorStyle.hyperlinkId = 0;
    _cursorStyle.semanticAttrs = 0;
    _modes.softReset();
    _tabStops.reset();
    _buffer.charset.reset();
    _buffer.resetVerticalMargins();
    _buffer.resetHorizontalMargins();
  }

  @override
  void screenAlignmentTest() {
    final style = CursorStyle(
      foreground: _cursorStyle.foreground,
      background: _cursorStyle.background,
    );
    _modes._originMode = false;
    _buffer.screenAlignmentTest(style);
  }

  @override
  void reverseIndex() {
    _buffer.reverseIndex();
  }

  @override
  void backIndex() {
    _buffer.backIndex();
  }

  @override
  void forwardIndex() {
    _buffer.forwardIndex();
  }

  @override
  void designateCharset(int charset, int name) {
    _buffer.charset.designate(charset, name);
  }

  @override
  void useCharset(int charset) {
    _buffer.charset.use(charset);
  }

  @override
  void singleShiftCharset(int charset) {
    _buffer.charset.singleShift(charset);
  }

  @override
  void unknownEscape(int char) {
    if (onUnknownSequence == null) return;
    _reportUnknownSequence();
  }

  /// Builds the diagnostic text for the escape sequence currently being
  /// dispatched and forwards it to [onUnknownSequence].
  ///
  /// Callers must guard on `onUnknownSequence == null` themselves before
  /// calling this, so that no work happens when the callback is unset.
  void _reportUnknownSequence() {
    onUnknownSequence!(
      formatEscapeSequenceForDiagnostics(_parser.capturedToken()),
    );
  }

  @Deprecated('Use unknownEscape instead. Will be removed in the next major.')
  @override
  void unkownEscape(int char) => unknownEscape(char);

  /* CSI */

  @override
  void repeatPreviousCharacter(int count) {
    if (_precedingCodepoint == 0) {
      return;
    }

    // Repeating more than a screenful is indistinguishable from a screenful.
    count = min(count, _viewWidth * _viewHeight);
    for (var i = 0; i < count; i++) {
      _buffer.writeChar(_precedingCodepoint);
    }
  }

  @override
  void setCursor(int x, int y) {
    _buffer.setCursor(x, y);
  }

  @override
  void setCursorX(int x) {
    _buffer.setCursorX(_modes._originMode ? x + _buffer.marginLeft : x);
  }

  @override
  void setCursorY(int y) {
    // setCursor treats x as relative to the left margin in origin mode.
    final x = _modes._originMode
        ? _buffer.cursorX - _buffer.marginLeft
        : _buffer.cursorX;
    _buffer.setCursor(x, y);
  }

  @override
  void moveCursorX(int offset) {
    _buffer.moveCursorX(offset);
  }

  @override
  void moveCursorY(int n) {
    _buffer.moveCursorY(n);
  }

  @override
  void clearTabStopUnderCursor() {
    _tabStops.clearAt(_buffer.cursorX);
  }

  @override
  void clearAllTabStops() {
    _tabStops.clearAll();
  }

  @override
  void resetTabStops() {
    _tabStops.reset();
  }

  @override
  void moveForwardTabs(int count) {
    for (var i = 0; i < count; i++) {
      final rightLimit = _horizontalTabRightLimit();
      if (_buffer.cursorX >= rightLimit) {
        return;
      }

      final nextStop = _tabStops.find(_buffer.cursorX + 1, rightLimit + 1);
      if (nextStop == null) {
        _buffer.setCursorX(rightLimit);
        return;
      }
      _buffer.setCursorX(nextStop);
    }
  }

  @override
  void moveBackwardTabs(int count) {
    for (var i = 0; i < count; i++) {
      final leftLimit = _horizontalTabLeftLimit();
      if (_buffer.cursorX <= leftLimit) {
        return;
      }

      final previousStop = _tabStops.findPrevious(
        _buffer.cursorX - 1,
        leftLimit,
      );
      if (previousStop == null) {
        _buffer.setCursorX(leftLimit);
        return;
      }
      _buffer.setCursorX(previousStop);
    }
  }

  int _horizontalTabRightLimit() {
    return switch (_buffer.cursorX <= _buffer.marginRight) {
      true => _buffer.marginRight,
      false => _viewWidth - 1,
    };
  }

  int _horizontalTabLeftLimit() {
    return switch (_modes._originMode) {
      true => _buffer.marginLeft,
      false => 0,
    };
  }

  @override
  void sendPrimaryDeviceAttributes() {
    _replySink?.call(_emitter.primaryDeviceAttributes());
  }

  @override
  void sendSecondaryDeviceAttributes() {
    _replySink?.call(_emitter.secondaryDeviceAttributes());
  }

  @override
  void sendTertiaryDeviceAttributes() {
    _replySink?.call(_emitter.tertiaryDeviceAttributes());
  }

  @override
  void sendOperatingStatus() {
    _replySink?.call(_emitter.operatingStatus());
  }

  @override
  void sendCursorPosition() {
    final x = switch (_modes._originMode) {
      true => max(0, _buffer.cursorX - _buffer.marginLeft),
      false => _buffer.cursorX,
    };
    final y = switch (_modes._originMode) {
      true => max(0, _buffer.cursorY - _buffer.marginTop),
      false => _buffer.cursorY,
    };
    _replySink?.call(_emitter.cursorPosition(x, y));
  }

  @override
  void sendPrivateDeviceStatusReport(List<int> params) {
    switch (params) {
      case [6]:
        _replySink?.call(
          '\x1b[?${_buffer.cursorY + 1};${_buffer.cursorX + 1};1R',
        );
      case [15]:
        _replySink?.call('\x1b[?13n');
      case [25]:
        _replySink?.call('\x1b[?23n');
      case [26]:
        _replySink?.call('\x1b[?27;1;0;1n');
      case [55]:
        _replySink?.call('\x1b[?53n');
      case [56]:
        _replySink?.call('\x1b[?57;0n');
      case [62]:
        _replySink?.call('\x1b[0*{');
      case [63, final id]:
        _replySink?.call('\x1bP$id!~0000\x1b\\');
      case [75]:
        _replySink?.call('\x1b[?70n');
      case [85]:
        _replySink?.call('\x1b[?83n');
      case _:
        return;
    }
  }

  @override
  void sendRectChecksum(
    int id,
    int page,
    int? top,
    int? left,
    int? bottom,
    int? right,
  ) {
    if (page != 1) return;
    final checksum = _rectChecksum(
      top ?? 1,
      left ?? 1,
      bottom ?? viewHeight,
      right ?? viewWidth,
    );
    final checksumText = checksum.toRadixString(16).padLeft(4, '0');
    _replySink?.call('\x1bP$id!~${checksumText.toUpperCase()}\x1b\\');
  }

  int _rectChecksum(int top, int left, int bottom, int right) {
    final topIndex = min(max(top, 1), viewHeight) - 1;
    final leftIndex = min(max(left, 1), viewWidth) - 1;
    final bottomIndex = min(max(bottom, 1), viewHeight) - 1;
    final rightIndex = min(max(right, 1), viewWidth) - 1;
    if (topIndex > bottomIndex || leftIndex > rightIndex) return 0;

    var sum = 0;
    for (var row = topIndex; row <= bottomIndex; row++) {
      final line = _buffer.lines[_buffer.scrollBack + row];
      for (var col = leftIndex; col <= rightIndex; col++) {
        sum += _cellChecksum(line, col);
      }
    }
    return (-sum) & 0xffff;
  }

  int _cellChecksum(BufferLine line, int col) {
    if (col > 0 && line.getWidth(col - 1) == 2) return 0;

    final codePoint = switch (line.getCodePoint(col)) {
      0 => 0x20,
      final value => value,
    };
    if (codePoint < 0x20) return 0;

    return codePoint +
        _checksumColor(line.getForeground(col), foreground: true) +
        _checksumColor(line.getBackground(col), foreground: false) +
        _checksumAttributes(line.getAttributes(col));
  }

  int _checksumColor(int color, {required bool foreground}) {
    final type = color & CellColor.typeMask;
    final value = switch (type) {
      CellColor.normal => _assignedChecksumColor(foreground: foreground),
      CellColor.named || CellColor.palette => color & CellColor.valueMask,
      _ => null,
    };
    if (value == null) return 0;
    if (value < 0 || value > 15) return 0;
    return switch (foreground) {
      true => value << 4,
      false => value,
    };
  }

  int? _assignedChecksumColor({required bool foreground}) {
    final color = _assignedColors[1];
    if (color == null) return null;
    return switch (foreground) {
      true => color.foreground,
      false => color.background,
    };
  }

  int _checksumAttributes(int attrs) {
    var value = 0;
    if (attrs & CellAttr.protected != 0) value |= 0x04;
    if (attrs & CellAttr.invisible != 0) value |= 0x08;
    if (attrs & CellAttr.underline != 0) value |= 0x10;
    if (attrs & CellAttr.inverse != 0) value |= 0x20;
    if (attrs & CellAttr.blink != 0) value |= 0x40;
    if (attrs & CellAttr.bold != 0) value |= 0x80;
    return value;
  }

  @override
  void sendColorScheme() {
    final colorScheme = onColorSchemeQuery?.call();
    if (colorScheme == null) return;
    _replySink?.call(_emitter.colorScheme(colorScheme));
  }

  void reportColorSchemeChange() {
    if (!_modes._reportColorSchemeMode) return;
    sendColorScheme();
  }

  @override
  void sendXtVersion() {
    _replySink?.call(_emitter.xtVersion(onXtVersionQuery?.call()));
  }

  @override
  void sendStatusString(String query) {
    _replySink?.call(_emitter.statusString(_statusString(query)));
  }

  @override
  void sendTerminfoCapability(String query) {
    final key = _hexDecode(query);
    if (key == null) return;
    final value = _terminfoCapability(
      key,
      columns: viewWidth,
      rows: viewHeight,
    );
    if (value == null) return;
    _replySink?.call(_emitter.terminfoCapability(key, value));
  }

  @override
  void unknownDCS(String payload) {
    if (onUnknownSequence == null) return;
    _reportUnknownSequence();
  }

  @override
  void setMargins(int top, [int? bottom]) {
    final effectiveBottom = bottom ?? viewHeight - 1;
    if (top >= effectiveBottom) return;
    _buffer.setVerticalMargins(top, effectiveBottom);
    _buffer.setCursor(0, 0);
  }

  @override
  void setLeftRightMargins(int left, [int? right]) {
    if (!_modes._leftRightMarginMode) return;

    final effectiveRight = right ?? viewWidth - 1;
    if (left >= effectiveRight) return;

    _buffer.setHorizontalMargins(left, effectiveRight);
    _buffer.setCursor(0, 0);
  }

  @override
  void cursorNextLine(int amount) {
    _buffer.moveCursorY(amount);
    _buffer.setCursorX(0);
  }

  @override
  void cursorPrecedingLine(int amount) {
    _buffer.moveCursorY(-amount);
    _buffer.setCursorX(0);
  }

  @override
  void eraseDisplayBelow() {
    _buffer.eraseDisplayFromCursor(respectProtected: _usesIsoProtection);
  }

  @override
  void eraseDisplayBelowSelective() {
    _buffer.eraseDisplayFromCursor(respectProtected: true);
  }

  @override
  void eraseDisplayAbove() {
    _buffer.eraseDisplayToCursor(respectProtected: _usesIsoProtection);
  }

  @override
  void eraseDisplayAboveSelective() {
    _buffer.eraseDisplayToCursor(respectProtected: true);
  }

  @override
  void eraseDisplay() {
    if (_shouldScrollClearBeforeEraseDisplay()) {
      _buffer.scrollClear();
    }
    _buffer.eraseDisplay(respectProtected: _usesIsoProtection);
  }

  @override
  void eraseDisplaySelective() {
    _buffer.eraseDisplay(respectProtected: true);
  }

  bool _shouldScrollClearBeforeEraseDisplay() {
    if (isUsingAltBuffer) return false;
    return switch (_semanticPrompt.state.content) {
      TerminalSemanticPromptContent.prompt ||
      TerminalSemanticPromptContent.input =>
        true,
      TerminalSemanticPromptContent.output => false,
    };
  }

  @override
  void eraseScrollbackOnly() {
    _buffer.clearScrollback();
  }

  @override
  void eraseDisplayScrollComplete() {
    _buffer.scrollClear();
    _buffer.setCursor(0, 0);
  }

  @override
  void eraseLineRight() {
    _buffer.eraseLineFromCursor(respectProtected: _usesIsoProtection);
  }

  @override
  void eraseLineRightSelective() {
    _buffer.eraseLineFromCursor(respectProtected: true);
  }

  @override
  void eraseLineLeft() {
    _buffer.eraseLineToCursor(respectProtected: _usesIsoProtection);
  }

  @override
  void eraseLineLeftSelective() {
    _buffer.eraseLineToCursor(respectProtected: true);
  }

  @override
  void eraseLine() {
    _buffer.eraseLine(respectProtected: _usesIsoProtection);
  }

  @override
  void eraseLineSelective() {
    _buffer.eraseLine(respectProtected: true);
  }

  @override
  void insertLines(int amount) {
    _buffer.insertLines(amount);
  }

  @override
  void deleteLines(int amount) {
    _buffer.deleteLines(amount);
  }

  @override
  void deleteChars(int amount) {
    _buffer.deleteChars(amount);
  }

  @override
  void insertColumns(int amount) {
    _buffer.insertColumns(amount);
  }

  @override
  void deleteColumns(int amount) {
    _buffer.deleteColumns(amount);
  }

  @override
  void scrollUp(int amount) {
    _buffer.scrollUp(amount);
  }

  @override
  void scrollDown(int amount) {
    _buffer.scrollDown(amount);
  }

  @override
  void eraseChars(int amount) {
    _buffer.eraseChars(amount, respectProtected: _usesIsoProtection);
  }

  @override
  void eraseRect(int top, int left, int bottom, int right) {
    _buffer.eraseRect(
      top,
      left,
      bottom,
      right,
      respectProtected: _usesIsoProtection,
    );
  }

  @override
  void fillRect(int char, int top, int left, int bottom, int right) {
    _buffer.fillRect(char, top, left, bottom, right);
  }

  @override
  void changeRectAttributes(
    int top,
    int left,
    int bottom,
    int right,
    int attribute,
  ) {
    _buffer.changeRectAttributes(
      top,
      left,
      bottom,
      right,
      attribute,
      rectangular: _settings.attributeChangeExtentRectangular,
    );
  }

  @override
  void reverseRectAttributes(
    int top,
    int left,
    int bottom,
    int right,
    int attribute,
  ) {
    _buffer.reverseRectAttributes(
      top,
      left,
      bottom,
      right,
      attribute,
      rectangular: _settings.attributeChangeExtentRectangular,
    );
  }

  @override
  void copyRect(
    int sourceTop,
    int sourceLeft,
    int sourceBottom,
    int sourceRight,
    int sourcePage,
    int destinationTop,
    int destinationLeft,
    int destinationPage,
  ) {
    _buffer.copyRect(
      sourceTop,
      sourceLeft,
      sourceBottom,
      sourceRight,
      sourcePage,
      destinationTop,
      destinationLeft,
      destinationPage,
    );
  }

  @override
  void selectiveEraseRect(int top, int left, int bottom, int right) {
    _buffer.eraseRect(top, left, bottom, right, respectProtected: true);
  }

  @override
  void setAttributeChangeExtent(bool rectangular) {
    _settings.attributeChangeExtentRectangular = rectangular;
  }

  @override
  void setKeyClickVolume(int volume) {
    _settings.setKeyClickVolume(volume);
  }

  @override
  void setMarginBellVolume(int volume) {
    _settings.setMarginBellVolume(volume);
  }

  @override
  void setWarningBellVolume(int volume) {
    _settings.setWarningBellVolume(volume);
  }

  @override
  void setLockKeyStyle(int style) {
    _settings.lockKeyStyle = style;
  }

  @override
  void setTerminalModeEmulation(int mode) {
    _settings.terminalModeEmulation = mode;
  }

  @override
  void setActiveStatusDisplay(int display) {
    _settings.setActiveStatusDisplay(display);
  }

  @override
  void setStatusLineType(int type) {
    _settings.setStatusLineType(type);
  }

  @override
  void setProtectedFieldsAttribute(int attribute) {
    _settings.protectedFieldsAttribute = attribute;
  }

  @override
  void setTransmitTerminationCharacter(int character) {
    _settings.transmitTerminationCharacter = character;
  }

  @override
  void setLineTransmitTerminationCharacter(int character) {
    _settings.lineTransmitTerminationCharacter = character;
  }

  @override
  void setTitleMode(int mode, bool enabled) {
    _settings.setTitleMode(mode, enabled);
  }

  @override
  void setAssignedColor(int selector, int foreground, int background) {
    if (selector < 1 || selector > 2) return;
    if (!_isDecColor(foreground) || !_isDecColor(background)) return;

    final previous = _assignedColors[selector];
    _assignedColors[selector] = (
      foreground: foreground,
      background: background,
    );

    if (selector != 1) return;
    if (_matchesAssignedColor(_cursorStyle.foreground, previous?.foreground)) {
      _cursorStyle.foreground = _namedColor(foreground);
    }
    if (_matchesAssignedColor(_cursorStyle.background, previous?.background)) {
      _cursorStyle.background = _namedColor(background);
    }
  }

  @override
  void setAlternateTextColor(int attribute, int foreground, int background) {
    if (attribute < 0 || attribute > 15) return;
    if (!_isDecColor(foreground) || !_isDecColor(background)) return;

    _settings.alternateTextColors[attribute] = (
      foreground: foreground,
      background: background,
    );
  }

  bool _isDecColor(int color) {
    return color >= 0 && color < 16;
  }

  bool _matchesAssignedColor(int current, int? assigned) {
    if ((current & CellColor.typeMask) == CellColor.normal) return true;
    if (assigned == null) return false;
    return current == _namedColor(assigned);
  }

  @override
  int _namedColor(int color) {
    return color | CellColor.named;
  }

  @override
  void insertBlankChars(int amount) {
    _buffer.insertBlankChars(amount);
  }

  @override
  void sendSize() {
    _replySink?.call(_emitter.size(viewHeight, viewWidth));
  }

  @override
  void sendPixelSize() {
    final pixelWidth = viewWidth * _cellPixelWidth;
    final pixelHeight = viewHeight * _cellPixelHeight;
    _replySink?.call('\x1b[4;$pixelHeight;${pixelWidth}t');
  }

  @override
  void sendCellSize() {
    _replySink?.call('\x1b[6;$_cellPixelHeight;${_cellPixelWidth}t');
  }

  @override
  void sendWindowReport() {
    _replySink?.call('\x1b[$viewHeight;$viewWidth;1;1;1"w');
  }

  @override
  void sendTerminalStateReport(int request) {
    if (request != 1) return;
    _replySink?.call('\x1bP1\$s\x1b\\');
  }

  @override
  void assignUserPreferredSupplementalSet(int size, String charsetFinal) {
    if (size != 94 && size != 96) return;
    if (charsetFinal.isEmpty) return;
    if (charsetFinal.length > 2) return;
    // Optional intermediates (0x20-0x2F) followed by one final (0x30-0x7E).
    final codeUnits = charsetFinal.codeUnits;
    for (var i = 0; i < codeUnits.length - 1; i++) {
      if (codeUnits[i] < 0x20 || codeUnits[i] > 0x2f) return;
    }
    if (codeUnits.last < 0x30 || codeUnits.last > 0x7e) return;

    _settings.preferredSupplementalSetSize = size;
    _settings.preferredSupplementalSetFinal = charsetFinal;
  }

  @override
  void sendUserPreferredSupplementalSet() {
    final size = switch (_settings.preferredSupplementalSetSize) {
      96 => 1,
      _ => 0,
    };
    _replySink
        ?.call('\x1bP$size!u${_settings.preferredSupplementalSetFinal}\x1b\\');
  }

  @override
  void sendPresentationStateReport(int request) {
    switch (request) {
      case 1:
        return _sendCursorInformationReport();
      case 2:
        return _sendTabStopReport();
    }
  }

  void _sendCursorInformationReport() {
    final row = _buffer.cursorY + 1;
    final column = _buffer.cursorX + 1;
    final rendition = _presentationRendition();
    final attributes = switch (_cursorStyle.isProtected) {
      true => 'A',
      false => '@',
    };
    final flags = switch (_modes._originMode) {
      true => 'A',
      false => '@',
    };
    _replySink?.call(
      '\x1bP1\$u$row;$column;1;$rendition;$attributes;$flags;0;1;@BBBB\x1b\\',
    );
  }

  String _presentationRendition() {
    var rendition = 0x40;
    if (_cursorStyle.isInverse) rendition |= 0x08;
    if (_cursorStyle.isBlink) rendition |= 0x04;
    if (_cursorStyle.isUnderline) rendition |= 0x02;
    if (_cursorStyle.isBold) rendition |= 0x01;
    return String.fromCharCode(rendition);
  }

  void _sendTabStopReport() {
    final stops = <String>[];
    for (var column = 1; column < viewWidth; column++) {
      if (!_tabStops.isSetAt(column)) continue;
      stops.add('${column + 1}');
    }
    _replySink?.call('\x1bP2\$u${stops.join('/')}\x1b\\');
  }

  void _sendInBandSizeReport() {
    final pixelWidth = viewWidth * _cellPixelWidth;
    final pixelHeight = viewHeight * _cellPixelHeight;
    _replySink?.call('\x1b[48;$viewHeight;$viewWidth;$pixelHeight;$pixelWidth'
        't');
  }

  @override
  void unknownCSI(int finalByte) {
    if (onUnknownSequence == null) return;
    _reportUnknownSequence();
  }

  @override
  void setCursorShape(int style) {
    if (style == 0) {
      _modes._applicationCursorType = null;
      _modes._cursorBlinkMode = false;
      return;
    }

    _modes._applicationCursorType = switch (style) {
      1 || 2 => TerminalCursorType.block,
      3 || 4 => TerminalCursorType.underline,
      5 || 6 => TerminalCursorType.verticalBar,
      _ => _modes._applicationCursorType,
    };
    if (style < 1 || style > 6) return;
    _modes._cursorBlinkMode = style.isOdd;
  }

  @override
  void setProtectedMode(bool enabled) {
    if (enabled) {
      _modes._protectionMode = _ProtectionMode.dec;
      return _cursorStyle.setProtected();
    }
    _cursorStyle.unsetProtected();
  }

  @override
  void setIsoProtectedMode(bool enabled) {
    if (enabled) {
      _modes._protectionMode = _ProtectionMode.iso;
      return _cursorStyle.setProtected();
    }
    _cursorStyle.unsetProtected();
  }

  bool get _usesIsoProtection => _modes._protectionMode == _ProtectionMode.iso;

  /* Modes */

  @override
  void setInsertMode(bool enabled) {
    _modes._insertMode = enabled;
  }

  @override
  void setSendReceiveMode(bool enabled) {
    _modes._sendReceiveMode = enabled;
  }

  @override
  void setKeyboardActionMode(bool enabled) {
    _modes._keyboardActionMode = enabled;
  }

  @override
  void setLineFeedMode(bool enabled) {
    _modes._lineFeedMode = enabled;
  }

  @override
  void setUnknownMode(int mode, bool enabled) {
    // no-op
  }

  /* DEC Private modes */

  @override
  void setCursorKeysMode(bool enabled) {
    _modes._cursorKeysMode = enabled;
  }

  @override
  void setReverseDisplayMode(bool enabled) {
    _modes._reverseDisplayMode = enabled;
  }

  @override
  void setOriginMode(bool enabled) {
    _modes._originMode = enabled;
    _buffer.setCursor(0, 0);
  }

  @override
  void setColumnMode(bool enabled) {
    if (!_modes._enableColumnMode) return;

    _buffer.resetViewport();
  }

  @override
  void setEnableColumnMode(bool enabled) {
    _modes._enableColumnMode = enabled;
    if (!enabled) return;

    _buffer.resetViewport();
  }

  @override
  void setSlowScrollMode(bool enabled) {
    _modes._slowScrollMode = enabled;
  }

  @override
  void setAutoWrapMode(bool enabled) {
    _modes._autoWrapMode = enabled;
  }

  @override
  void setAutoRepeatMode(bool enabled) {
    _modes._autoRepeatMode = enabled;
  }

  @override
  void setReverseWrapMode(bool enabled) {
    _modes._reverseWrapMode = enabled;
  }

  @override
  void setReverseWrapExtendedMode(bool enabled) {
    _modes._reverseWrapExtendedMode = enabled;
  }

  @override
  void setMouseMode(MouseMode mode) {
    _modes._mouseMode = mode;
  }

  @override
  void setCursorBlinkMode(bool enabled) {
    _modes._cursorBlinkMode = enabled;
  }

  @override
  void setCursorVisibleMode(bool enabled) {
    _modes._cursorVisibleMode = enabled;
  }

  @override
  void useAltBuffer() {
    _endScreenHyperlinkState();
    _buffer = _altBuffer;
    _cursorStyle.semanticAttrs = 0;
  }

  @override
  void useMainBuffer() {
    _endScreenHyperlinkState();
    _buffer = _mainBuffer;
    _cursorStyle.semanticAttrs = _SemanticPromptTracker.semanticAttributes(
      _semanticPrompt.state.content,
      isMainBuffer: identical(_buffer, _mainBuffer),
    );
  }

  void _endScreenHyperlinkState() {
    _cursorStyle.hyperlinkId = 0;
    _mainBuffer.clearSavedCursorHyperlink();
    _altBuffer.clearSavedCursorHyperlink();
  }

  @override
  void clearAltBuffer() {
    _altBuffer.reset();
  }

  @override
  void setAppKeypadMode(bool enabled) {
    _modes._appKeypadMode = enabled;
  }

  @override
  void setIgnoreKeypadWithNumLockMode(bool enabled) {
    _modes._ignoreKeypadWithNumLockMode = enabled;
  }

  @override
  void setBackarrowKeyMode(bool enabled) {
    _modes._backarrowKeyMode = enabled;
  }

  @override
  void setReportFocusMode(bool enabled) {
    _modes._reportFocusMode = enabled;
    if (!enabled) return;

    focusInput(_focused);
  }

  @override
  void setMouseShiftCaptureMode(bool enabled) {
    _modes._mouseShiftCaptureMode = enabled;
  }

  @override
  void setMouseReportMode(MouseReportMode mode) {
    _modes._mouseReportMode = mode;
  }

  @override
  void setAltBufferMouseScrollMode(bool enabled) {
    _modes._altBufferMouseScrollMode = enabled;
  }

  @override
  void setAltEscPrefixMode(bool enabled) {
    _modes._altEscPrefixMode = enabled;
  }

  @override
  void setAltSendsEscapeMode(bool enabled) {
    _modes._altSendsEscapeMode = enabled;
  }

  @override
  void setBracketedPasteMode(bool enabled) {
    _modes._bracketedPasteMode = enabled;
  }

  @override
  void setInBandSizeReportMode(bool enabled) {
    _modes._inBandSizeReportMode = enabled;
    if (!enabled) return;

    _sendInBandSizeReport();
  }

  @override
  void setReportColorSchemeMode(bool enabled) {
    _modes._reportColorSchemeMode = enabled;
    if (!enabled) return;

    sendColorScheme();
  }

  @override
  void setSynchronizedUpdateMode(bool enabled) {
    _synchronizedUpdateTimer?.cancel();
    _modes._synchronizedUpdateMode = enabled;
    if (!enabled) return;

    _synchronizedUpdateTimer = Timer(const Duration(milliseconds: 150), () {
      _modes._synchronizedUpdateMode = false;
      _synchronizedUpdateTimer = null;
      notifyListeners();
    });
  }

  @override
  void setGraphemeClusterMode(bool enabled) {
    _modes._graphemeClusterMode = enabled;
  }

  @override
  void reportMode(int mode, bool decPrivate) {
    final state = switch (decPrivate) {
      true => _decModeState(mode),
      false => _ansiModeState(mode),
    };
    final privateMarker = switch (decPrivate) {
      true => '?',
      false => '',
    };
    _replySink?.call('\x1b[$privateMarker$mode;$state\x24y');
  }

  int _ansiModeState(int mode) {
    return switch (mode) {
      2 => _reportedState(_modes._keyboardActionMode),
      4 => _reportedState(_modes._insertMode),
      12 => _reportedState(_modes._sendReceiveMode),
      20 => _reportedState(_modes._lineFeedMode),
      _ => 0,
    };
  }

  int _decModeState(int mode) {
    return switch (mode) {
      1 => _reportedState(_modes._cursorKeysMode),
      3 => 0,
      4 => _reportedState(_modes._slowScrollMode),
      5 => _reportedState(_modes._reverseDisplayMode),
      6 => _reportedState(_modes._originMode),
      7 => _reportedState(_modes._autoWrapMode),
      8 => _reportedState(_modes._autoRepeatMode),
      9 => _reportedState(_modes._mouseMode == MouseMode.clickOnly),
      12 || 13 => _reportedState(_modes._cursorBlinkMode),
      25 => _reportedState(_modes._cursorVisibleMode),
      40 => _reportedState(_modes._enableColumnMode),
      45 => _reportedState(_modes._reverseWrapMode),
      47 || 1047 || 1049 => _reportedState(isUsingAltBuffer),
      1048 => _reportedState(false),
      66 => _reportedState(_modes._appKeypadMode),
      67 => _reportedState(_modes._backarrowKeyMode),
      69 => _reportedState(_modes._leftRightMarginMode),
      1000 => _reportedState(_modes._mouseMode == MouseMode.upDownScroll),
      1002 => _reportedState(_modes._mouseMode == MouseMode.upDownScrollDrag),
      1003 => _reportedState(_modes._mouseMode == MouseMode.upDownScrollMove),
      1004 => _reportedState(_modes._reportFocusMode),
      1005 => _reportedState(_modes._mouseReportMode == MouseReportMode.utf),
      1006 => _reportedState(_modes._mouseReportMode == MouseReportMode.sgr),
      1007 => _reportedState(_modes._altBufferMouseScrollMode),
      1015 => _reportedState(_modes._mouseReportMode == MouseReportMode.urxvt),
      1016 =>
        _reportedState(_modes._mouseReportMode == MouseReportMode.sgrPixels),
      1035 => _reportedState(_modes._ignoreKeypadWithNumLockMode),
      1036 => _reportedState(_modes._altEscPrefixMode),
      1039 => _reportedState(_modes._altSendsEscapeMode),
      1045 => _reportedState(_modes._reverseWrapExtendedMode),
      2004 => _reportedState(_modes._bracketedPasteMode),
      2026 => _reportedState(_modes._synchronizedUpdateMode),
      2027 => _reportedState(_modes._graphemeClusterMode),
      2031 => _reportedState(_modes._reportColorSchemeMode),
      2048 => _reportedState(_modes._inBandSizeReportMode),
      _ => 0,
    };
  }

  int _reportedState(bool enabled) {
    return switch (enabled) {
      true => 1,
      false => 2,
    };
  }

  @override
  void saveDecMode(int mode) {
    final state = _decModeEnabled(mode);
    if (state == null) return;

    _savedDecModes[mode] = state;
  }

  @override
  void restoreDecMode(int mode) {
    final state = _savedDecModes[mode];
    if (state == null) return;

    _applyDecMode(mode, state);
  }

  bool? _decModeEnabled(int mode) {
    return switch (mode) {
      1 => _modes._cursorKeysMode,
      4 => _modes._slowScrollMode,
      5 => _modes._reverseDisplayMode,
      6 => _modes._originMode,
      7 => _modes._autoWrapMode,
      8 => _modes._autoRepeatMode,
      9 => _modes._mouseMode == MouseMode.clickOnly,
      12 || 13 => _modes._cursorBlinkMode,
      25 => _modes._cursorVisibleMode,
      40 => _modes._enableColumnMode,
      45 => _modes._reverseWrapMode,
      47 || 1047 || 1049 => isUsingAltBuffer,
      66 => _modes._appKeypadMode,
      67 => _modes._backarrowKeyMode,
      69 => _modes._leftRightMarginMode,
      1000 => _modes._mouseMode == MouseMode.upDownScroll,
      1002 => _modes._mouseMode == MouseMode.upDownScrollDrag,
      1003 => _modes._mouseMode == MouseMode.upDownScrollMove,
      1004 => _modes._reportFocusMode,
      1005 => _modes._mouseReportMode == MouseReportMode.utf,
      1006 => _modes._mouseReportMode == MouseReportMode.sgr,
      1007 => _modes._altBufferMouseScrollMode,
      1015 => _modes._mouseReportMode == MouseReportMode.urxvt,
      1016 => _modes._mouseReportMode == MouseReportMode.sgrPixels,
      1035 => _modes._ignoreKeypadWithNumLockMode,
      1036 => _modes._altEscPrefixMode,
      1039 => _modes._altSendsEscapeMode,
      1045 => _modes._reverseWrapExtendedMode,
      2004 => _modes._bracketedPasteMode,
      2026 => _modes._synchronizedUpdateMode,
      2027 => _modes._graphemeClusterMode,
      2031 => _modes._reportColorSchemeMode,
      2048 => _modes._inBandSizeReportMode,
      _ => null,
    };
  }

  void _applyDecMode(int mode, bool enabled) {
    switch (mode) {
      case 1:
        return setCursorKeysMode(enabled);
      case 4:
        return setSlowScrollMode(enabled);
      case 5:
        return setReverseDisplayMode(enabled);
      case 6:
        return setOriginMode(enabled);
      case 7:
        return setAutoWrapMode(enabled);
      case 8:
        return setAutoRepeatMode(enabled);
      case 9:
        return setMouseMode(switch (enabled) {
          true => MouseMode.clickOnly,
          false => MouseMode.none,
        });
      case 12:
      case 13:
        return setCursorBlinkMode(enabled);
      case 25:
        return setCursorVisibleMode(enabled);
      case 40:
        return setEnableColumnMode(enabled);
      case 45:
        return setReverseWrapMode(enabled);
      case 47:
      case 1047:
      case 1049:
        if (enabled) {
          return useAltBuffer();
        }
        return useMainBuffer();
      case 66:
        return setAppKeypadMode(enabled);
      case 67:
        return setBackarrowKeyMode(enabled);
      case 69:
        return setLeftRightMarginMode(enabled);
      case 1000:
        return setMouseMode(switch (enabled) {
          true => MouseMode.upDownScroll,
          false => MouseMode.none,
        });
      case 1002:
        return setMouseMode(switch (enabled) {
          true => MouseMode.upDownScrollDrag,
          false => MouseMode.none,
        });
      case 1003:
        return setMouseMode(switch (enabled) {
          true => MouseMode.upDownScrollMove,
          false => MouseMode.none,
        });
      case 1004:
        return setReportFocusMode(enabled);
      case 1005:
        return setMouseReportMode(switch (enabled) {
          true => MouseReportMode.utf,
          false => MouseReportMode.normal,
        });
      case 1006:
        return setMouseReportMode(switch (enabled) {
          true => MouseReportMode.sgr,
          false => MouseReportMode.normal,
        });
      case 1007:
        return setAltBufferMouseScrollMode(enabled);
      case 1015:
        return setMouseReportMode(switch (enabled) {
          true => MouseReportMode.urxvt,
          false => MouseReportMode.normal,
        });
      case 1016:
        return setMouseReportMode(switch (enabled) {
          true => MouseReportMode.sgrPixels,
          false => MouseReportMode.normal,
        });
      case 1035:
        return setIgnoreKeypadWithNumLockMode(enabled);
      case 1036:
        return setAltEscPrefixMode(enabled);
      case 1039:
        return setAltSendsEscapeMode(enabled);
      case 1045:
        return setReverseWrapExtendedMode(enabled);
      case 2004:
        return setBracketedPasteMode(enabled);
      case 2026:
        return setSynchronizedUpdateMode(enabled);
      case 2027:
        return setGraphemeClusterMode(enabled);
      case 2031:
        return setReportColorSchemeMode(enabled);
      case 2048:
        return setInBandSizeReportMode(enabled);
    }
  }

  @override
  void reportKittyKeyboardMode() {
    _replySink
        ?.call('\x1b[?${_modes._kittyKeyboardMode & _kittyKeyboardModeMask}u');
  }

  @override
  void setKittyKeyboardMode(int mode, int behavior) {
    final normalizedMode = mode & _kittyKeyboardModeMask;
    _modes._kittyKeyboardMode = switch (behavior) {
      2 => _modes._kittyKeyboardMode | normalizedMode,
      3 => _modes._kittyKeyboardMode & ~normalizedMode,
      _ => normalizedMode,
    };
  }

  @override
  void pushKittyKeyboardMode(int mode) {
    if (_modes._kittyKeyboardModeStack.length >=
        _maxKittyKeyboardModeStackDepth) {
      _modes._kittyKeyboardModeStack.removeAt(0);
    }

    final normalizedMode = mode & _kittyKeyboardModeMask;
    _modes._kittyKeyboardModeStack.add(_modes._kittyKeyboardMode);
    _modes._kittyKeyboardMode = normalizedMode;
  }

  @override
  void popKittyKeyboardModes(int count) {
    if (count <= 0) return;

    if (count > _modes._kittyKeyboardModeStack.length) {
      _modes._kittyKeyboardModeStack.clear();
      _modes._kittyKeyboardMode = 0;
      return;
    }

    final newLength = _modes._kittyKeyboardModeStack.length - count;
    _modes._kittyKeyboardMode = _modes._kittyKeyboardModeStack[newLength];
    _modes._kittyKeyboardModeStack.length = newLength;
  }

  @override
  void setModifyOtherKeysMode(int resource, int mode) {
    if (resource != 4) return;
    _modes._modifyOtherKeysMode = switch (mode) {
      2 => 2,
      _ => 0,
    };
  }

  @override
  void setUnknownDecMode(int mode, bool enabled) {
    // no-op
  }

  @override
  void setLeftRightMarginMode(bool enabled) {
    _modes._leftRightMarginMode = enabled;
    if (enabled) return;

    _buffer.resetHorizontalMargins();
  }

  /* OSC */

  @override
  void setTitle(String name) {
    _title = name;
    onTitleChange?.call(name);
  }

  @override
  void setIconName(String name) {
    _iconTitle = name;
    onIconChange?.call(name);
  }

  @override
  void reportTitle() {
    // Echoing the title would inject attacker-controlled text into the input
    // stream, so the reply is always empty.
    _replySink?.call('\x1b]l\x1b\\');
  }

  @override
  void pushTitle() {
    if (_titleStack.length >= _maxTitleStackDepth) {
      _titleStack.removeAt(0);
    }
    _titleStack.add(_title);
  }

  @override
  void popTitle() {
    if (_titleStack.isEmpty) return;
    final title = _titleStack.removeLast();
    _title = title;
    onTitleChange?.call(title ?? '');
  }

  @override
  void setCurrentDirectory(String uri) {
    onCurrentDirectoryChange?.call(uri);
  }

  @override
  void setRemoteHost(String value) {
    onRemoteHostChange?.call(value);
  }

  @override
  void reportITerm2CellSize() {
    _replySink?.call(
      '\x1b]1337;ReportCellSize=$_cellPixelHeight;$_cellPixelWidth\x1b\\',
    );
  }

  @override
  void reportITerm2Variable(String data) {
    String name;
    try {
      name = utf8.decode(base64.decode(data));
    } on FormatException {
      return;
    }

    if (name.isEmpty) return;

    final value = _resolveITerm2Variable(name);
    if (value == null) return;

    final encoded = base64.encode(utf8.encode(value));
    _replySink?.call('\x1b]1337;ReportVariable=$encoded\x1b\\');
  }

  String? _resolveITerm2Variable(String name) {
    if (onITerm2VariableQuery?.call(name) case final value?) {
      return value;
    }

    return switch (name) {
      'columns' => viewWidth.toString(),
      'rows' => viewHeight.toString(),
      'terminalIconName' => _iconTitle ?? '',
      'terminalWindowName' => _title ?? '',
      'autoName' || 'name' || 'presentationName' => _title ?? '',
      _ => null,
    };
  }

  @override
  void setITerm2BadgeFormat(String data) {
    if (data.isEmpty) {
      onITerm2BadgeFormatChange?.call('');
      return;
    }

    try {
      final value = utf8.decode(base64.decode(data));
      onITerm2BadgeFormatChange?.call(value);
    } on FormatException {
      return;
    }
  }

  @override
  void setITerm2ShellIntegrationVersion(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    onITerm2ShellIntegrationVersionChange?.call(trimmed);
  }

  @override
  void setITerm2Mark() {
    onITerm2Mark?.call();
  }

  @override
  void setITerm2Profile(String value) {
    onITerm2ProfileChange?.call(value);
  }

  @override
  void setUserVariable(String name, String data) {
    if (name.isEmpty || data.isEmpty) return;

    try {
      final value = utf8.decode(base64.decode(data));
      onUserVariableChange?.call(name, value);
    } on FormatException {
      return;
    }
  }

  @override
  void requestFocus() {
    onFocusRequest?.call();
  }

  @override
  void openUrl(String url) {
    onOpenUrl?.call(url);
  }

  @override
  void requestAttention(String value) {
    onAttentionRequest?.call(value);
  }

  @override
  void showNotification(String title, String body) {
    onNotification?.call(title, body);
  }

  @override
  void setMouseShape(String shape) {
    onMouseShapeChange?.call(shape);
  }

  @override
  void setCursorLineHighlight(bool enabled) {
    if (_modes._cursorLineHighlightMode == enabled) return;
    _modes._cursorLineHighlightMode = enabled;
  }

  @override
  void reportProgress(TerminalProgressReport report) {
    onProgressReport?.call(report);
  }

  @override
  void setHyperlink(String params, String uri) {
    String? explicitId;
    for (final param in params.split(':')) {
      if (!param.startsWith('id=')) continue;
      final id = param.substring(3);
      if (id.isNotEmpty) explicitId = id;
      break;
    }

    if (uri.isEmpty) {
      _cursorStyle.hyperlinkId = 0;
      return;
    }

    final key = explicitId == null ? null : '$explicitId\x00$uri';
    final existingId = key == null ? null : _explicitHyperlinkIds[key];
    if (existingId != null) {
      _cursorStyle.hyperlinkId = existingId;
      return;
    }
    if (_hyperlinkPruneCooldown > 0) _hyperlinkPruneCooldown--;
    if (_hyperlinks.length >= _maxHyperlinks) {
      if (_hyperlinkPruneCooldown == 0) {
        _pruneUnusedHyperlinks();
        _hyperlinkPruneCooldown = _hyperlinkScanInterval;
      }
      if (_hyperlinks.length >= _maxHyperlinks) {
        _cursorStyle.hyperlinkId = 0;
        return;
      }
    }

    final hyperlinkId = _allocateHyperlinkId();
    if (hyperlinkId == null) {
      _cursorStyle.hyperlinkId = 0;
      return;
    }

    _hyperlinks[hyperlinkId] = uri;
    if (key != null) {
      _explicitHyperlinkIds[key] = hyperlinkId;
      _explicitHyperlinkKeyByHyperlinkId[hyperlinkId] = key;
    }
    _cursorStyle.hyperlinkId = hyperlinkId;
  }

  int? _allocateHyperlinkId() {
    for (var attempts = 0; attempts < _maxHyperlinkId; attempts++) {
      final hyperlinkId = _nextHyperlinkId;
      _nextHyperlinkId++;
      if (_nextHyperlinkId > _maxHyperlinkId) {
        _nextHyperlinkId = 1;
      }
      if (!_hyperlinks.containsKey(hyperlinkId)) {
        return hyperlinkId;
      }
    }
    return null;
  }

  /// Called whenever a line falls out of scrollback. This only collects the
  /// hyperlink ids that lived on [line] - bounded by the line's length, so
  /// it's cheap and happens on every eviction.
  ///
  /// It deliberately does NOT check whether those ids are still referenced
  /// elsewhere here: doing that requires a full scan of both buffers, and in
  /// the common case for hyperlink-heavy output (e.g. `ls --hyperlink=auto`,
  /// build logs, test runners) every line carries its own distinct
  /// hyperlink, so that scan would find nothing and run to completion on
  /// every single eviction - turning scrolling into an O(evictions * buffer
  /// size) operation. Instead, candidate ids are accumulated in
  /// [_pendingEvictedHyperlinkIds] and resolved together in one batched scan
  /// once enough of them have piled up. See
  /// [_resolvePendingHyperlinkEvictions].
  void _onScrollbackLineEvicted(BufferLine line) {
    if (_hyperlinks.isEmpty) return;

    final written = line.writtenLength;
    for (var column = 0; column < written; column++) {
      final hyperlinkId = line.getHyperlinkId(column);
      if (hyperlinkId != 0) _pendingEvictedHyperlinkIds.add(hyperlinkId);
    }

    if (_pendingEvictedHyperlinkIds.length >= _hyperlinkScanInterval) {
      _resolvePendingHyperlinkEvictions();
    }
  }

  /// Resolves every id in [_pendingEvictedHyperlinkIds] in a single pass over
  /// both buffers, removing whichever ones are no longer referenced by the
  /// cursor's current style or by any live cell.
  ///
  /// Batching size ([_hyperlinkScanInterval]) is the amortization knob: one
  /// scan now answers up to that many candidates instead of one scan per
  /// candidate, so the average cost per evicted hyperlink is O(buffer size /
  /// batch size) rather than O(buffer size). It starts at 128 and grows with
  /// the scrollback, up to half of [_maxHyperlinks] - so that many dead
  /// hyperlinks can be left resident between scans, and no more.
  void _resolvePendingHyperlinkEvictions() {
    if (_pendingEvictedHyperlinkIds.isEmpty) return;

    final remaining = _pendingEvictedHyperlinkIds;
    if (_cursorStyle.hyperlinkId != 0) {
      remaining.remove(_cursorStyle.hyperlinkId);
    }

    void scanBuffer(Buffer buffer) {
      final lines = buffer.lines;
      for (var i = 0; i < lines.length; i++) {
        if (remaining.isEmpty) break;
        final line = lines[i];
        final written = line.writtenLength;
        _hyperlinkEvictionScanCellsForTesting += written;
        for (var column = 0; column < written; column++) {
          final hyperlinkId = line.getHyperlinkId(column);
          if (hyperlinkId != 0) remaining.remove(hyperlinkId);
        }
      }
    }

    if (remaining.isNotEmpty) scanBuffer(_mainBuffer);
    if (remaining.isNotEmpty) scanBuffer(_altBuffer);

    for (final hyperlinkId in remaining) {
      _hyperlinks.remove(hyperlinkId);
      final explicitKey = _explicitHyperlinkKeyByHyperlinkId.remove(
        hyperlinkId,
      );
      if (explicitKey != null) _explicitHyperlinkIds.remove(explicitKey);
    }

    _pendingEvictedHyperlinkIds.clear();
  }

  /// The number of hyperlinks currently held in the registry. Exposed only
  /// for tests that verify the registry stays bounded as scrollback lines
  /// are evicted; not part of the public API surface.
  @visibleForTesting
  int get debugHyperlinkCount => _hyperlinks.length;

  /// The number of `getHyperlinkId` cell inspections spent resolving evicted
  /// hyperlinks and pruning the registry at its ceiling so far. Exposed only so a test can assert this stays
  /// sub-quadratic in the number of evicted lines; not part of the public
  /// API surface.
  @visibleForTesting
  int get debugHyperlinkEvictionScanCells =>
      _hyperlinkEvictionScanCellsForTesting;

  void _pruneUnusedHyperlinks() {
    final usedIds = <int>{};
    if (_cursorStyle.hyperlinkId != 0) {
      usedIds.add(_cursorStyle.hyperlinkId);
    }

    void collectBuffer(Buffer buffer) {
      buffer.lines.forEach((line) {
        final written = line.writtenLength;
        _hyperlinkEvictionScanCellsForTesting += written;
        for (var column = 0; column < written; column++) {
          final hyperlinkId = line.getHyperlinkId(column);
          if (hyperlinkId != 0) usedIds.add(hyperlinkId);
        }
      });
    }

    collectBuffer(_mainBuffer);
    collectBuffer(_altBuffer);

    for (final hyperlinkId in _hyperlinks.keys.toList()) {
      if (!usedIds.contains(hyperlinkId)) {
        _hyperlinks.remove(hyperlinkId);
        final explicitKey = _explicitHyperlinkKeyByHyperlinkId.remove(
          hyperlinkId,
        );
        if (explicitKey != null) _explicitHyperlinkIds.remove(explicitKey);
      }
    }

    // This scan is authoritative over the whole registry, so any hyperlink
    // id still sitting in the eviction batch has already been accounted for
    // above (either it wasn't used and is now gone, or it is used and
    // doesn't need to be resolved again until it's evicted for real).
    _pendingEvictedHyperlinkIds.clear();
  }

  @override
  void setIndexedColor(int index, String value) {
    final specialIndex = _specialColorIndexFromPaletteIndex(index);
    if (specialIndex != null) {
      setSpecialColor(specialIndex, value);
      return;
    }
    if (index < 0 || index > 255) return;
    final color = _parseOscColor(value);
    if (color == null || _colors._indexedColorOverrides[index] == color) return;
    _colors._indexedColorOverrides[index] = color;
    _colors._colorRevision++;
  }

  @override
  void queryIndexedColor(int index) {
    final specialIndex = _specialColorIndexFromPaletteIndex(index);
    if (specialIndex != null) {
      _querySpecialColor(index, specialIndex, 4);
      return;
    }
    if (index < 0 || index > 255) return;
    final color =
        _colors._indexedColorOverrides[index] ?? onColorQuery?.call(4, index);
    if (color == null) return;
    _replySink?.call('\x1b]4;$index;${_formatOscColor(color)}\x1b\\');
  }

  @override
  void resetIndexedColors(List<int> indices) {
    if (indices.isEmpty) {
      if (_colors._indexedColorOverrides.isEmpty) return;
      _colors._indexedColorOverrides.clear();
      _colors._colorRevision++;
      return;
    }

    var changed = false;
    for (final index in indices) {
      final specialIndex = _specialColorIndexFromPaletteIndex(index);
      if (specialIndex != null) {
        changed = _colors._specialColorOverrides.remove(specialIndex) != null ||
            changed;
        continue;
      }
      changed = _colors._indexedColorOverrides.remove(index) != null || changed;
    }
    if (changed) _colors._colorRevision++;
  }

  @override
  void setSpecialColor(int index, String value) {
    if (!_isSpecialColorIndex(index)) return;
    final color = _parseOscColor(value);
    if (color == null || _colors._specialColorOverrides[index] == color) return;
    _colors._specialColorOverrides[index] = color;
    _colors._colorRevision++;
  }

  @override
  void querySpecialColor(int index) {
    _querySpecialColor(index, index, 5);
  }

  void _querySpecialColor(int reportIndex, int storageIndex, int code) {
    if (!_isSpecialColorIndex(storageIndex)) return;
    final color = _colors._specialColorOverrides[storageIndex] ??
        onColorQuery?.call(5, storageIndex);
    if (color == null) return;
    _replySink?.call('\x1b]$code;$reportIndex;${_formatOscColor(color)}\x1b\\');
  }

  @override
  void resetSpecialColors(List<int> indices) {
    if (indices.isEmpty) {
      if (_colors._specialColorOverrides.isEmpty) return;
      _colors._specialColorOverrides.clear();
      _colors._colorRevision++;
      return;
    }

    var changed = false;
    for (final index in indices) {
      if (!_isSpecialColorIndex(index)) continue;
      changed = _colors._specialColorOverrides.remove(index) != null || changed;
    }
    if (changed) _colors._colorRevision++;
  }

  int? _specialColorIndexFromPaletteIndex(int index) {
    final specialIndex = index - _specialColorBaseIndex;
    if (!_isSpecialColorIndex(specialIndex)) return null;
    return specialIndex;
  }

  bool _isSpecialColorIndex(int index) {
    return index >= 0 && index < _specialColorCount;
  }

  @override
  void setDynamicColor(int code, String value) {
    final color = _parseOscColor(value);
    if (color == null) return;

    switch (code) {
      case 10:
        if (_colors._foregroundColorOverride == color) return;
        _colors._foregroundColorOverride = color;
        break;
      case 11:
        if (_colors._backgroundColorOverride == color) return;
        _colors._backgroundColorOverride = color;
        break;
      case 12:
        if (_colors._cursorColorOverride == color) return;
        _colors._cursorColorOverride = color;
        break;
      case 13:
      case 14:
      case 15:
      case 16:
      case 18:
        if (_colors._auxiliaryDynamicColorOverrides[code] == color) return;
        _colors._auxiliaryDynamicColorOverrides[code] = color;
        break;
      case 17:
        if (_colors._selectionColorOverride == color) return;
        _colors._selectionColorOverride = color;
        break;
      case 19:
        if (_colors._selectionForegroundColorOverride == color) return;
        _colors._selectionForegroundColorOverride = color;
        break;
      default:
        return;
    }
    _colors._colorRevision++;
  }

  @override
  void queryDynamicColor(int code) {
    final override = switch (code) {
      10 => _colors._foregroundColorOverride,
      11 => _colors._backgroundColorOverride,
      12 => _colors._cursorColorOverride,
      17 => _colors._selectionColorOverride,
      19 => _colors._selectionForegroundColorOverride,
      _ => _colors._auxiliaryDynamicColorOverrides[code],
    };
    final color = override ?? onColorQuery?.call(code, null);
    if (color == null) return;
    _replySink?.call('\x1b]$code;${_formatOscColor(color)}\x1b\\');
  }

  @override
  void resetDynamicColor(int code) {
    switch (code) {
      case 10:
        if (_colors._foregroundColorOverride == null) return;
        _colors._foregroundColorOverride = null;
        break;
      case 11:
        if (_colors._backgroundColorOverride == null) return;
        _colors._backgroundColorOverride = null;
        break;
      case 12:
        if (_colors._cursorColorOverride == null) return;
        _colors._cursorColorOverride = null;
        break;
      case 13:
      case 14:
      case 15:
      case 16:
      case 18:
        if (_colors._auxiliaryDynamicColorOverrides.remove(code) == null) {
          return;
        }
        break;
      case 17:
        if (_colors._selectionColorOverride == null) return;
        _colors._selectionColorOverride = null;
        break;
      case 19:
        if (_colors._selectionForegroundColorOverride == null) return;
        _colors._selectionForegroundColorOverride = null;
        break;
      default:
        return;
    }
    _colors._colorRevision++;
  }

  @override
  void startITerm2ClipboardCapture(String selector) {
    _clipboardCapture.start(selector);
  }

  @override
  void endITerm2ClipboardCapture() {
    final result = _clipboardCapture.end();
    if (result == null) return;
    onClipboardStore?.call(result.selector, result.text);
  }

  void _captureITerm2ClipboardChar(int codePoint) {
    _clipboardCapture.captureChar(codePoint);
  }

  void _captureITerm2ClipboardTextRange(String text, int start, int end) {
    _clipboardCapture.captureTextRange(text, start, end);
  }

  @override
  void storeClipboard(String selector, String data) {
    final clipboardSelector = _resolveClipboardSelector(selector);
    if (clipboardSelector == null) return;

    try {
      final bytes = base64.decode(data);
      final text = utf8.decode(bytes);
      onClipboardStore?.call(clipboardSelector, text);
    } on FormatException {
      return;
    }
  }

  @override
  void queryClipboard(String selector) {
    final clipboardSelector = _resolveClipboardSelector(selector);
    if (clipboardSelector == null) return;

    final callback = onClipboardQuery;
    if (callback == null) return;

    unawaited(Future<String?>.value(callback(clipboardSelector)).then((text) {
      if (_isDisposed) return;
      if (text == null) return;

      final encoded = base64.encode(utf8.encode(text));
      _replySink?.call('\x1b]52;$clipboardSelector;$encoded\x1b\\');
    }));
  }

  @override
  void unknownOSC(String ps, List<String> pt) {
    _handleSemanticPromptOsc(ps, pt);
    _handleVsCodeShellIntegrationOsc(ps, pt);
    _handleContextSignalOsc(ps, pt);
    onPrivateOSC?.call(ps, pt);

    if (onUnknownSequence == null) return;
    // These OSC families are recognised and acted on above; they only
    // reach this fallback dispatch because they share it with genuinely
    // unknown OSCs. Reporting them here would be a false positive.
    if (ps == '133' || ps == '633' || ps == '3008') return;
    _reportUnknownSequence();
  }

  void _handleSemanticPromptOsc(String ps, List<String> pt) {
    if (ps != '133' || pt.isEmpty) return;
    final action = pt.first;
    if (action.isEmpty) return;
    final actionCode = action.codeUnitAt(0);

    switch (actionCode) {
      case 0x41: // A: prompt start
      case 0x4e: // N: fresh-line prompt start
      case 0x4c: // L: fresh line
        _semanticPromptFreshLine();
    }

    if (actionCode == 0x4c) return;

    final options = _parseSemanticPromptOptions(pt);

    final content = switch (actionCode) {
      0x41 || 0x4e || 0x50 => TerminalSemanticPromptContent.prompt,
      0x42 || 0x49 => TerminalSemanticPromptContent.input,
      0x43 || 0x44 => TerminalSemanticPromptContent.output,
      _ => null,
    };
    if (content == null) return;

    final exitCode = switch (actionCode) {
      0x44 => _parseSemanticPromptExitCode(pt),
      _ => _semanticPrompt.state.lastCommandExitCode,
    };
    final state = TerminalSemanticPromptState(
      content: content,
      lastCommandExitCode: exitCode,
      aid: options['aid'],
      promptKind: _parseSemanticPromptKind(options['k']),
      clickMode: _parseSemanticPromptClickMode(options),
      redraw: _parseSemanticPromptRedraw(options['redraw']),
      specialKey: _parseSemanticPromptBoolean(options['special_key']),
      commandLine: _parseSemanticPromptCommandLine(options),
    );
    _semanticPrompt.inputTerminatesAtLineFeed = actionCode == 0x49;
    _semanticPrompt.state = state;
    _cursorStyle.semanticAttrs = _SemanticPromptTracker.semanticAttributes(
      content,
      isMainBuffer: identical(_buffer, _mainBuffer),
    );
    if (_SemanticPromptTracker.isPrimaryPrompt(state)) {
      _recordSemanticPromptAnchor();
    }
    onSemanticPrompt?.call(state);
  }

  void _semanticPromptFreshLine() {
    if (_buffer.cursorX == 0) return;
    carriageReturn();
    index();
  }

  void _semanticPromptLineFeed() {
    if (!_semanticPrompt.inputTerminatesAtLineFeed) return;
    if (_semanticPrompt.state.content != TerminalSemanticPromptContent.input) {
      _semanticPrompt.inputTerminatesAtLineFeed = false;
      return;
    }

    _semanticPrompt.inputTerminatesAtLineFeed = false;
    final state = TerminalSemanticPromptState(
      content: TerminalSemanticPromptContent.output,
      lastCommandExitCode: _semanticPrompt.state.lastCommandExitCode,
    );
    _semanticPrompt.state = state;
    _cursorStyle.semanticAttrs = 0;
    onSemanticPrompt?.call(state);
  }

  void _handleVsCodeShellIntegrationOsc(String ps, List<String> pt) {
    if (ps != '633' || pt.isEmpty) return;
    final action = pt.first;
    if (action.isEmpty) return;

    if (action == 'P') {
      final options = _parseSemanticPromptOptions(pt);
      final currentDirectory = options['Cwd'] ?? options['cwd'];
      if (currentDirectory != null && currentDirectory.isNotEmpty) {
        setCurrentDirectory(currentDirectory);
      }
      return;
    }

    final content = switch (action.codeUnitAt(0)) {
      0x41 => TerminalSemanticPromptContent.prompt,
      0x42 => TerminalSemanticPromptContent.input,
      0x43 || 0x44 => TerminalSemanticPromptContent.output,
      _ => null,
    };
    if (content == null) return;

    final exitCode = switch (action.codeUnitAt(0)) {
      0x44 => _parseSemanticPromptExitCode(pt),
      _ => _semanticPrompt.state.lastCommandExitCode,
    };
    final state = TerminalSemanticPromptState(
      content: content,
      lastCommandExitCode: exitCode,
    );
    _semanticPrompt.state = state;
    _cursorStyle.semanticAttrs = _SemanticPromptTracker.semanticAttributes(
      content,
      isMainBuffer: identical(_buffer, _mainBuffer),
    );
    if (content == TerminalSemanticPromptContent.prompt) {
      _recordSemanticPromptAnchor();
    }
    onSemanticPrompt?.call(state);
  }

  void _recordSemanticPromptAnchor() {
    if (!identical(_buffer, _mainBuffer)) return;
    _pruneSemanticPromptAnchors();

    final last = switch (_semanticPromptAnchors.isEmpty) {
      true => null,
      false => _semanticPromptAnchors.last,
    };
    if (last != null &&
        _isValidSemanticPromptAnchor(last) &&
        last.y == _mainBuffer.absoluteCursorY) {
      return;
    }

    while (_semanticPromptAnchors.length >= _mainBuffer.lines.maxLength) {
      _semanticPromptAnchors.removeFirst().dispose();
    }
    _mainBuffer.currentLine.setSemanticContent(
      _mainBuffer.cursorX,
      CellAttr.semanticPrompt,
    );
    _semanticPromptAnchors.add(_mainBuffer.createAnchorFromCursor());
  }

  void _pruneSemanticPromptAnchors() {
    // Anchors do not go stale in order. Eviction takes them from the front,
    // but overwriting a prompt line invalidates one wherever it sits, and a
    // head-only prune leaves those behind for every later query to walk and
    // re-validate. Rebuild the queue instead, and only when something is
    // actually stale so the common case stays allocation-free.
    // Each anchor is validated exactly once. `survivors` stays null until the
    // first stale one is found, so a queue with nothing to drop - the common
    // case - allocates nothing and rewrites nothing.
    List<CellAnchor>? survivors;
    var index = 0;
    for (final anchor in _semanticPromptAnchors) {
      if (_isValidSemanticPromptAnchor(anchor)) {
        survivors?.add(anchor);
      } else {
        survivors ??= _semanticPromptAnchors.take(index).toList();
        anchor.dispose();
      }
      index++;
    }
    if (survivors == null) return;

    _semanticPromptAnchors
      ..clear()
      ..addAll(survivors);
  }

  bool _isValidSemanticPromptAnchor(CellAnchor anchor) {
    if (!_mainBuffer.ownsAnchor(anchor)) return false;
    final line = anchor.line;
    if (line == null) return false;
    for (var column = 0; column < line.length; column++) {
      if (line.getSemanticContent(column) == CellAttr.semanticPrompt) {
        return true;
      }
    }
    return false;
  }

  void _clearSemanticPromptAnchors() {
    for (final anchor in _semanticPromptAnchors) {
      anchor.dispose();
    }
    _semanticPromptAnchors.clear();
  }

  ({int rowsAboveCursor, int column})? _activeSemanticPromptOffset() {
    if (!identical(_buffer, _mainBuffer)) return null;
    if (_semanticPrompt.state.content == TerminalSemanticPromptContent.output) {
      return null;
    }

    _pruneSemanticPromptAnchors();
    CellAnchor? anchor;
    for (final candidate in _semanticPromptAnchors) {
      if (_isValidSemanticPromptAnchor(candidate)) anchor = candidate;
    }
    if (anchor == null) return null;
    final rowsAboveCursor = _mainBuffer.absoluteCursorY - anchor.y;
    if (rowsAboveCursor < 0 || rowsAboveCursor >= _mainBuffer.viewHeight) {
      return null;
    }
    return (rowsAboveCursor: rowsAboveCursor, column: anchor.x);
  }

  void _restoreActiveSemanticPrompt(
    ({int rowsAboveCursor, int column})? prompt,
  ) {
    _pruneSemanticPromptAnchors();
    if (prompt == null) return;

    final line = _mainBuffer.absoluteCursorY - prompt.rowsAboveCursor;
    if (line < 0 || line >= _mainBuffer.lines.length) return;
    final column = prompt.column.clamp(0, _mainBuffer.viewWidth - 1);
    _semanticPromptAnchors.add(_mainBuffer.createAnchor(column, line));
  }
}

String? _resolveClipboardSelector(String selector) {
  if (selector.isEmpty) return 'c';

  for (final codeUnit in selector.codeUnits) {
    switch (codeUnit) {
      case 0x63:
        return 'c';
      case 0x70:
      case 0x73:
        return 's';
    }
  }
  return null;
}

String _resolveITerm2ClipboardSelector(String selector) {
  final name = selector.toLowerCase();
  return switch (name) {
    '' || 'rule' || 'find' || 'font' => 'c',
    'primary' || 'selection' => 's',
    _ => 'c',
  };
}

int? _parseOscColor(String value) {
  if (value.startsWith('#')) {
    final hex = value.substring(1);
    if (hex.length != 3 &&
        hex.length != 6 &&
        hex.length != 9 &&
        hex.length != 12) {
      return null;
    }
    final componentLength = hex.length ~/ 3;
    return _parseOscColorComponents([
      hex.substring(0, componentLength),
      hex.substring(componentLength, componentLength * 2),
      hex.substring(componentLength * 2),
    ]);
  }

  if (!value.startsWith('rgb:')) return null;
  return _parseOscColorComponents(value.substring(4).split('/'));
}

int? _parseOscColorComponents(List<String> components) {
  if (components.length != 3) return null;
  var color = 0;
  for (final component in components) {
    if (component.isEmpty || component.length > 4) return null;
    if (!_isHexDigits(component)) return null;
    final value = int.tryParse(component, radix: 16);
    if (value == null) return null;
    final maximum = (1 << (component.length * 4)) - 1;
    color = (color << 8) | ((value * 255 + maximum ~/ 2) ~/ maximum);
  }
  return color;
}

final _hexDigits = RegExp(r'^[0-9a-fA-F]+$');

/// Unlike [int.tryParse], rejects a leading sign.
bool _isHexDigits(String value) => _hexDigits.hasMatch(value);

String _formatOscColor(int color) {
  String component(int shift) {
    final value = ((color >> shift) & 0xff) * 0x101;
    return value.toRadixString(16).padLeft(4, '0');
  }

  return 'rgb:${component(16)}/${component(8)}/${component(0)}';
}
