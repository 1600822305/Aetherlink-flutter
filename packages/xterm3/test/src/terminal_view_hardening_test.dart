import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  void mockClipboard(WidgetTester tester, String text) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': text} : null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  Future<void> pumpView(
    WidgetTester tester,
    Terminal terminal, {
    bool readOnly = false,
    TerminalController? controller,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TerminalView(
          terminal,
          autofocus: true,
          readOnly: readOnly,
          controller: controller,
        ),
      ),
    ));
    await tester.pump();
  }

  group('OSC 52 clipboard read', () {
    testWidgets('is not answered by default', (tester) async {
      mockClipboard(tester, 'hunter2');
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add);
      await pumpView(tester, terminal);

      terminal.write('\x1b]52;c;?\x07');
      await tester.pump();

      expect(terminal.onClipboardQuery, isNull);
      expect(out, isEmpty);
    });

    testWidgets('is answered when the embedder opts in', (tester) async {
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add)
        ..onClipboardQuery = (_) => 'hunter2';
      await pumpView(tester, terminal);

      terminal.write('\x1b]52;c;?\x07');
      await tester.pump();

      expect(out, ['\x1b]52;c;aHVudGVyMg==\x1b\\']);
    });

    testWidgets('clipboard store is still installed by default', (
      tester,
    ) async {
      final terminal = Terminal();
      await pumpView(tester, terminal);

      expect(terminal.onClipboardStore, isNotNull);
    });
  });

  group('readOnly', () {
    testWidgets('hardware keys do not reach the terminal', (tester) async {
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add);
      await pumpView(tester, terminal, readOnly: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(out, isEmpty);
    });

    testWidgets('paste is a no-op', (tester) async {
      mockClipboard(tester, 'rm -rf ~\r');
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add);
      await pumpView(tester, terminal, readOnly: true);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.insert);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(out, isEmpty);
    });

    testWidgets('select-all shortcut still works', (tester) async {
      final terminal = Terminal()..write('hello');
      final controller = TerminalController();
      addTearDown(controller.dispose);
      await pumpView(tester, terminal, readOnly: true, controller: controller);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(controller.selection, isNotNull);
    });

    testWidgets('paste still works when not read-only', (tester) async {
      mockClipboard(tester, 'ls');
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add);
      await pumpView(tester, terminal);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.insert);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(out.join(), 'ls');
    });
  });

  group('IME', () {
    testWidgets('a cancelled composition sends nothing', (tester) async {
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add);
      await pumpView(tester, terminal);
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'n',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ));
      await tester.pump();

      expect(out, isEmpty);
    });

    testWidgets('an empty no-op value at the floor is still a backspace', (
      tester,
    ) async {
      final out = <String>[];
      final terminal = Terminal(onOutput: out.add);
      await pumpView(tester, terminal);
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ));
      await tester.pump();

      expect(out, ['\x7f']);
    });
  });
}
