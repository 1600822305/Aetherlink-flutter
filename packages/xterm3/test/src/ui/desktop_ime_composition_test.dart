import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/custom_text_edit.dart';
import 'package:xterm3/xterm.dart';

import '../../_support/desktop_ime_simulator.dart';

/// Korean 2-set layout: the key a user presses and the Hangul Compatibility
/// Jamo the layout maps it to, which is all a key event carries.
const _jamoKeys = <String, (LogicalKeyboardKey, PhysicalKeyboardKey)>{
  'ㅎ': (LogicalKeyboardKey.keyG, PhysicalKeyboardKey.keyG),
  'ㅏ': (LogicalKeyboardKey.keyK, PhysicalKeyboardKey.keyK),
  'ㄴ': (LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS),
  'ㄱ': (LogicalKeyboardKey.keyR, PhysicalKeyboardKey.keyR),
  'ㅡ': (LogicalKeyboardKey.keyM, PhysicalKeyboardKey.keyM),
  'ㄹ': (LogicalKeyboardKey.keyF, PhysicalKeyboardKey.keyF),
  'ㅌ': (LogicalKeyboardKey.keyX, PhysicalKeyboardKey.keyX),
  'ㅔ': (LogicalKeyboardKey.keyP, PhysicalKeyboardKey.keyP),
  'ㅅ': (LogicalKeyboardKey.keyT, PhysicalKeyboardKey.keyT),
};

final _macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

void macTest(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: _macOS);
}

void main() {
  late List<String> output;
  late DesktopImeSimulator ime;
  late Terminal terminal;

  Widget view({bool readOnly = false, bool deleteDetection = false}) {
    return MaterialApp(
      home: TerminalView(
        terminal,
        autofocus: true,
        readOnly: readOnly,
        deleteDetection: deleteDetection,
      ),
    );
  }

  TerminalViewState viewState(WidgetTester tester) =>
      tester.state<TerminalViewState>(find.byType(TerminalView));

  Future<void> pumpTerminal(
    WidgetTester tester, {
    bool markedText = false,
  }) async {
    output = <String>[];
    terminal = Terminal(
      onOutput: output.add,
      platform: TerminalTargetPlatform.macos,
    );
    ime = DesktopImeSimulator(tester, markedText: markedText);
    addTearDown(ime.dispose);

    await tester.pumpWidget(view());
    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> typeJamo(String jamo) async {
    for (final rune in jamo.runes) {
      final jamoChar = String.fromCharCode(rune);
      final (logical, physical) = _jamoKeys[jamoChar]!;
      await ime.typeKey(logical, jamoChar, physicalKey: physical);
    }
  }

  Future<void> typeSpace() => ime.typeKey(
        LogicalKeyboardKey.space,
        ' ',
        physicalKey: PhysicalKeyboardKey.space,
      );

  Future<void> typeEnter() => ime.typeKey(
        LogicalKeyboardKey.enter,
        '\r',
        physicalKey: PhysicalKeyboardKey.enter,
      );

  group('desktop input method composition (in-place IME)', () {
    macTest('composes 한글테스트 without stray jamo or backspaces', (
      tester,
    ) async {
      await pumpTerminal(tester);

      // gksrmfxptmxm on the 2-Set Korean layout.
      await typeJamo('ㅎㅏㄴㄱㅡㄹㅌㅔㅅㅡㅌㅡ');
      expect(output.join(), '한글테스');
      await typeEnter();

      expect(output.join(), '한글테스트\r');
    });

    macTest('a vowel after a final rewrites and appends: 한 + ㅏ = 하나', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏㄴㅏ');
      await typeEnter();

      expect(output.join(), '하나\r');
    });

    macTest('Backspace while composing edits the held syllable', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏㄴ');
      await ime.pressBackspace();
      await typeEnter();

      expect(output.join(), '하\r');
    });

    macTest('Backspace on the last jamo leaves nothing to send', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎ');
      await ime.pressBackspace();
      await typeEnter();

      expect(output.join(), '\r');
    });

    macTest('Backspace with nothing held goes to the terminal', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await ime.pressBackspace();

      expect(output, ['\x7f']);
      expect(ime.keysSeenByIme, isEmpty);
    });

    macTest('Hangul is sent before an arrow key', (tester) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);

      expect(output, ['하', '\x1b[D']);
    });

    macTest('Hangul can be typed again after Enter', (tester) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏㄴ');
      await typeEnter();
      await typeJamo('ㄱㅡㄹ');
      await typeEnter();

      expect(output.join(), '한\r글\r');
    });

    macTest('Latin text is sent at once, one key at a time', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await ime.typeKey(
        LogicalKeyboardKey.keyA,
        'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      expect(output, ['a']);
      await ime.typeKey(
        LogicalKeyboardKey.keyB,
        'b',
        physicalKey: PhysicalKeyboardKey.keyB,
      );

      expect(output, ['a', 'b']);
    });

    macTest('Latin after Hangul sends both in order', (tester) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await ime.typeKey(
        LogicalKeyboardKey.keyA,
        'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );

      expect(output.join(), '하a');
    });

    macTest('Option-composed text reaches the terminal once', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await ime.typeKey(
        LogicalKeyboardKey.keyA,
        'å',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(output, ['å']);
    });

    macTest('a shifted symbol without a character is still typed', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.digit2,
        character: '',
        physicalKey: PhysicalKeyboardKey.digit2,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(output, ['@']);
    });

    macTest('a held key keeps repeating without the input method', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyJ,
        character: 'j',
        physicalKey: PhysicalKeyboardKey.keyJ,
      );
      await tester.sendKeyRepeatEvent(
        LogicalKeyboardKey.keyJ,
        character: 'j',
        physicalKey: PhysicalKeyboardKey.keyJ,
      );
      await tester.sendKeyRepeatEvent(
        LogicalKeyboardKey.keyJ,
        character: 'j',
        physicalKey: PhysicalKeyboardKey.keyJ,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);

      // The press is the input method's, which the stub does not answer here;
      // only the two repeats reach the terminal directly.
      expect(output, ['j', 'j']);
    });

    macTest('a command chord is not offered to the input method', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final handled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyC,
        character: '\x03',
        physicalKey: PhysicalKeyboardKey.keyC,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(handled, isTrue);
      expect(output, ['\x03']);
    });

    macTest('readOnly sends nothing to the terminal', (tester) async {
      final output = <String>[];
      final terminal = Terminal(
        onOutput: output.add,
        platform: TerminalTargetPlatform.macos,
      );
      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, readOnly: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        character: 'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      // readOnly sends no input; typing without a connection is covered by
      // 'closeKeyboard sends the syllable and releases the keys'.
      expect(output, isEmpty);
    });
  });

  group('holding a Hangul syllable', () {
    macTest('deleteBackward: from another input source drops the syllable', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏㄴ');
      // Caps Lock switches to ABC, which keeps the held syllable.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.capsLock);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.capsLock);
      ime.abc = true;
      await ime.pressBackspace();
      await ime.typeKey(
        LogicalKeyboardKey.keyA,
        'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );

      expect(output, ['a']);
    });

    macTest('Option+Backspace is the terminal\'s, after the syllable', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await ime.pressBackspace();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(ime.keysSeenByIme, isNot(contains('<backspace>')));
      expect(output.first, '하');
      expect(output, hasLength(2));
    });

    macTest('Cmd+Backspace is the terminal\'s, after the syllable', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await ime.pressBackspace();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      expect(ime.keysSeenByIme, isNot(contains('<backspace>')));
      expect(output.first, '하');
    });

    macTest('Option+letter flushes the syllable first', (tester) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await ime.typeKey(
        LogicalKeyboardKey.keyB,
        '∫',
        physicalKey: PhysicalKeyboardKey.keyB,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(output.first, '하');
    });

    macTest('closeKeyboard sends the syllable and releases the keys', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      viewState(tester).closeKeyboard();
      await tester.pump();
      expect(output, ['하']);

      // No input connection: keys take the old path and are not swallowed.
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        character: 'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      expect(output, ['하', 'a']);
      expect(tester.takeException(), isNull);
    });

    macTest('toggling readOnly sends the syllable without a build error', (
      tester,
    ) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await tester.pumpWidget(view(readOnly: true));
      await tester.pump();

      expect(output, ['하']);
      expect(tester.takeException(), isNull);
    });

    macTest('disposing the view sends the syllable', (tester) async {
      await pumpTerminal(tester);

      await typeJamo('ㅎㅏ');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(output, ['하']);
      expect(tester.takeException(), isNull);
    });

    macTest('a paste does not overtake the syllable', (tester) async {
      await pumpTerminal(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': 'xyz'} : null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await typeJamo('ㅎㅏ');
      final context = tester.element(find.byType(CustomTextEdit));
      Actions.invoke(
        context,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
      await tester.pump();

      expect(output, ['하', 'xyz']);
    });

    macTest('deleteDetection keeps the old key path on macOS', (tester) async {
      output = <String>[];
      terminal = Terminal(
        onOutput: output.add,
        platform: TerminalTargetPlatform.macos,
      );
      ime = DesktopImeSimulator(tester);
      addTearDown(ime.dispose);
      await tester.pumpWidget(view(deleteDetection: true));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      final handled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        character: 'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      expect(handled, isTrue);
      expect(output, ['a']);
    });

    testWidgets('Linux keeps the old key path', (tester) async {
      output = <String>[];
      terminal = Terminal(onOutput: output.add);
      await tester.pumpWidget(view());
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      final handled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        character: 'a',
        physicalKey: PhysicalKeyboardKey.keyA,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

      expect(handled, isTrue);
      expect(output, ['a']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('desktop input method composition (marked-text IME)', () {
    macTest('composes Hangul instead of sending raw jamo', (tester) async {
      await pumpTerminal(tester, markedText: true);

      await typeJamo('ㅎㅏㄴㄱㅡㄹㅌㅔㅅㅡㅌㅡ');
      await typeSpace();

      expect(output.join(), '한글테스트 ');
    });

    macTest('keeps the composition across a commit', (tester) async {
      await pumpTerminal(tester, markedText: true);

      // ㄱ commits 한 and marks the next syllable within one keystroke.
      await typeJamo('ㅎㅏㄴㄱ');
      await typeJamo('ㅡ');
      await typeSpace();

      expect(output.join(), '한그 ');
    });

    macTest('a commit and a new mark in one keystroke are not repeated', (
      tester,
    ) async {
      await pumpTerminal(tester, markedText: true);

      await ime.typeScriptedKey(
        LogicalKeyboardKey.keyK,
        'k',
        [('commit', '日本語'), ('mark', 'k')],
        physicalKey: PhysicalKeyboardKey.keyK,
      );
      await ime.typeScriptedKey(
        LogicalKeyboardKey.enter,
        '\r',
        [('commit', 'か')],
        physicalKey: PhysicalKeyboardKey.enter,
      );

      expect(output.join(), '日本語か');
    });

    macTest('commitComposing sends only what was not sent yet', (
      tester,
    ) async {
      await pumpTerminal(tester, markedText: true);

      await ime.typeScriptedKey(
        LogicalKeyboardKey.keyR,
        'ㄱ',
        [('commit', '한'), ('mark', 'ㄱ')],
        physicalKey: PhysicalKeyboardKey.keyR,
      );
      expect(viewState(tester).commitComposing(), isTrue);

      expect(output.join(), '한ㄱ');
    });
  });
}
