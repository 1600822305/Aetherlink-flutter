import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the macOS embedder and a Korean 2-set input method, which
/// [TestTextInput] cannot do: it pushes values straight into the framework
/// and never offers a key to an input method.
///
/// It reproduces the embedder behaviours the desktop fix depends on:
///
///  - a key goes to the framework first, and reaches the input method only if
///    the framework left it unhandled (`FlutterKeyboardManager`);
///  - one keystroke may make the input method change the platform's editing
///    state twice (commit a syllable, mark the next one), and both changes
///    are applied before the framework has seen either, as the embedder
///    sends them as two asynchronous messages (`FlutterTextInputPlugin`
///    insertText / setMarkedText);
///  - a `setEditingState` from the framework replaces the platform's text,
///    and one that carries no composing range while the platform has marked
///    text discards that marked text (`FlutterTextInputPlugin
///    setEditingState:`), which ends the input method's composition.
///
/// Two input method styles are modelled. The default is what the built-in
/// macOS 2-Set Korean source does on a real Mac: it never sets a composing
/// range, it rewrites the last character of the platform document in place
/// (`ㅎ`, `하`, `한`) and reads the previous character from that document, so
/// clearing the document mid-syllable makes it insert bare jamo. With
/// [markedText] it instead marks the syllable being composed, as kana and
/// pinyin input methods do.
class DesktopImeSimulator {
  DesktopImeSimulator(this.tester, {this.markedText = false}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      _handlePlatformCall,
    );
  }

  final WidgetTester tester;

  final bool markedText;

  /// Whether the active input source is ABC: it inserts what is typed and
  /// asks the plugin for a selector on Backspace, as the macOS plugin has no
  /// `deleteBackward:` of its own.
  var abc = false;

  int? _clientId;
  var _text = '';
  var _composing = TextRange.empty;

  /// Keys the framework left unhandled and the input method therefore saw.
  final keysSeenByIme = <String>[];

  final _hangul = _HangulComposer();

  void dispose() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      null,
    );
  }

  /// Types one key. [character] is what the layout maps the key to, which for
  /// the Korean layout is a Hangul Compatibility Jamo.
  Future<void> typeKey(
    LogicalKeyboardKey key,
    String character, {
    PhysicalKeyboardKey? physicalKey,
  }) async {
    final handled = await tester.sendKeyDownEvent(
      key,
      character: character,
      physicalKey: physicalKey,
    );
    if (!handled) {
      keysSeenByIme.add(character);
      _processInIme(character);
    }
    await tester.sendKeyUpEvent(key, physicalKey: physicalKey);
    await tester.pump();
  }

  /// Presses a key to which the input method answers with the given events
  /// instead of composing: `('commit', text)` is `insertText`, `('mark',
  /// text)` is `setMarkedText`.
  Future<void> typeScriptedKey(
    LogicalKeyboardKey key,
    String character,
    List<(String, String)> script, {
    PhysicalKeyboardKey? physicalKey,
  }) async {
    final handled = await tester.sendKeyDownEvent(
      key,
      character: character,
      physicalKey: physicalKey,
    );
    if (!handled) {
      keysSeenByIme.add(character);
      _applyEvents([
        for (final (kind, text) in script)
          if (kind == 'commit') _Commit(text) else _Mark(text),
      ]);
    }
    await tester.sendKeyUpEvent(key, physicalKey: physicalKey);
    await tester.pump();
  }

  /// Presses Backspace; the input method sees it only if the framework left
  /// it unhandled.
  Future<void> pressBackspace() async {
    final handled = await tester.sendKeyDownEvent(
      LogicalKeyboardKey.backspace,
      physicalKey: PhysicalKeyboardKey.backspace,
    );
    if (!handled) {
      keysSeenByIme.add('<backspace>');
      if (abc) {
        _sendSelector('deleteBackward:');
      } else {
        _deliver(_hangulBackspace());
      }
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
  }

  void _sendSelector(String selector) {
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.performSelectors', [
          _clientId,
          [selector],
        ]),
      ),
      (_) {},
    );
  }

  /// Document states after the input method deletes backwards, one jamo at a
  /// time.
  List<String> _hangulBackspace() {
    if (_text.isEmpty) return [];
    final last = _text.codeUnitAt(_text.length - 1);
    final head = _text.substring(0, _text.length - 1);
    if (last >= 0xAC00 && last <= 0xD7A3) {
      final index = last - 0xAC00;
      final l = index ~/ 588;
      final v = (index % 588) ~/ 28;
      final t = index % 28;
      if (t != 0) {
        return [head + _syllable(l, v, 0)];
      }
      return [head + _InPlaceHangul.initials[l]];
    }
    return [head];
  }

  static String _syllable(int l, int v, int t) =>
      String.fromCharCode(0xAC00 + (l * 21 + v) * 28 + t);

  void _processInIme(String character) {
    if (abc) {
      _deliver([_text + character]);
      return;
    }
    if (!markedText) {
      _deliver(_InPlaceHangul.type(_text, character));
      return;
    }
    _applyEvents(_hangul.type(character));
  }

  void _applyEvents(List<_ImeEvent> events) {
    // The platform applies every change first ...
    final states = <Map<String, dynamic>>[];
    for (final event in events) {
      switch (event) {
        case _Commit(:final text):
          _insertText(text);
        case _Mark(:final text):
          _setMarkedText(text);
      }
      states.add(_editingState());
    }
    // ... and the framework hears about them afterwards, in order.
    for (final state in states) {
      _sendToFramework(state);
    }
  }

  /// Replaces the platform document with each of [documents] in turn, which
  /// is how the in-place input method reports one keystroke: the platform
  /// has the last state before the framework hears about the first.
  void _deliver(List<String> documents) {
    final states = <Map<String, dynamic>>[];
    for (final document in documents) {
      _text = document;
      _composing = TextRange.empty;
      states.add(_editingState());
    }
    for (final state in states) {
      _sendToFramework(state);
    }
  }

  bool get _isComposing => _composing.isValid && !_composing.isCollapsed;

  void _insertText(String text) {
    if (_isComposing) {
      _text = _text.replaceRange(_composing.start, _composing.end, text);
      _composing = TextRange.empty;
    } else {
      _text += text;
    }
  }

  void _setMarkedText(String text) {
    final start = _isComposing ? _composing.start : _text.length;
    final end = _isComposing ? _composing.end : start;
    _text = _text.replaceRange(start, end, text);
    _composing = TextRange(start: start, end: start + text.length);
  }

  Map<String, dynamic> _editingState() => {
        'text': _text,
        'selectionBase': _text.length,
        'selectionExtent': _text.length,
        'selectionAffinity': 'TextAffinity.downstream',
        'selectionIsDirectional': false,
        'composingBase': _composing.isValid ? _composing.start : -1,
        'composingExtent': _composing.isValid ? _composing.end : -1,
      };

  void _sendToFramework(Map<String, dynamic> state) {
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingState', [_clientId, state]),
      ),
      (_) {},
    );
  }

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'TextInput.setClient':
        _clientId = (call.arguments as List)[0] as int;
      case 'TextInput.clearClient':
        _clientId = null;
      case 'TextInput.setEditingState':
        final state = call.arguments as Map;
        final wasComposing = _isComposing;
        _text = state['text'] as String;
        final base = state['composingBase'] as int;
        final extent = state['composingExtent'] as int;
        _composing = base < 0
            ? TextRange.empty
            : TextRange(
                start: base.clamp(0, _text.length),
                end: extent.clamp(0, _text.length),
              );
        if (!_isComposing && wasComposing) {
          _hangul.discard();
        }
    }
    return null;
  }
}

sealed class _ImeEvent {}

class _Commit extends _ImeEvent {
  _Commit(this.text);
  final String text;
}

class _Mark extends _ImeEvent {
  _Mark(this.text);
  final String text;
}

/// A minimal 2-set Korean composer: initial, medial, optional final, with
/// no compound finals. Enough to compose the syllables the tests type.
class _HangulComposer {
  static const _initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
  static const _medials = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
  static const _finals = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ';

  String? _initial;
  String? _medial;
  String? _final;

  bool get _composing => _initial != null || _medial != null;

  void discard() {
    _initial = _medial = _final = null;
  }

  String _current() {
    if (_initial == null) return _medial ?? '';
    if (_medial == null) return _initial!;
    final index =
        (_initials.indexOf(_initial!) * 21 + _medials.indexOf(_medial!)) * 28 +
            (_final == null ? 0 : _finals.indexOf(_final!));
    return String.fromCharCode(0xAC00 + index);
  }

  List<_ImeEvent> type(String ch) {
    final isVowel = _medials.contains(ch);
    final isConsonant = _initials.contains(ch);
    if (!isVowel && !isConsonant) {
      final events = <_ImeEvent>[
        if (_composing) _Commit(_current()),
        // Enter ends the composition and is consumed by the input method.
        if (ch != '\r') _Commit(ch),
      ];
      discard();
      return events;
    }
    if (isConsonant) {
      if (_initial != null &&
          _medial != null &&
          _final == null &&
          _finals.contains(ch)) {
        _final = ch;
        return [_Mark(_current())];
      }
      final events = <_ImeEvent>[if (_composing) _Commit(_current())];
      discard();
      _initial = ch;
      return [...events, _Mark(_current())];
    }
    if (_initial != null && _medial == null) {
      _medial = ch;
      return [_Mark(_current())];
    }
    if (_final != null) {
      // The final consonant moves to the start of the next syllable.
      final moved = _final!;
      _final = null;
      final commit = _Commit(_current());
      discard();
      _initial = moved;
      _medial = ch;
      return [commit, _Mark(_current())];
    }
    final events = <_ImeEvent>[if (_composing) _Commit(_current())];
    discard();
    _medial = ch;
    return [...events, _Mark(_current())];
  }
}

/// 2-Set Korean the way the macOS built-in source behaves: the previous
/// character is read back from the document and rewritten in place.
class _InPlaceHangul {
  static const initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
  static const medials = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
  static const finals = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ';

  static String _syllable(int l, int v, int t) =>
      String.fromCharCode(0xAC00 + (l * 21 + v) * 28 + t);

  /// The document states after typing [ch] into [document].
  static List<String> type(String document, String ch) {
    final isVowel = medials.contains(ch);
    final isConsonant = initials.contains(ch);
    if (!isVowel && !isConsonant) return [document + ch];
    if (document.isEmpty) return [ch];

    final head = document.substring(0, document.length - 1);
    final last = document[document.length - 1];
    final code = last.codeUnitAt(0);

    if (code >= 0xAC00 && code <= 0xD7A3) {
      final index = code - 0xAC00;
      final l = index ~/ 588;
      final v = (index % 588) ~/ 28;
      final t = index % 28;
      if (isConsonant && t == 0 && finals.contains(ch)) {
        return [head + _syllable(l, v, finals.indexOf(ch))];
      }
      if (isVowel && t != 0) {
        // The final consonant moves to a new syllable: the previous syllable
        // is rewritten and another one appended.
        final moved = initials.indexOf(finals[t]);
        return [
          head + _syllable(l, v, 0),
          head + _syllable(l, v, 0) + _syllable(moved, medials.indexOf(ch), 0),
        ];
      }
      return [document + ch];
    }
    if (isVowel && initials.contains(last)) {
      return [head + _syllable(initials.indexOf(last), medials.indexOf(ch), 0)];
    }
    return [document + ch];
  }
}
