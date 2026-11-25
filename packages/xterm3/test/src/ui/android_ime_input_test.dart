import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  Future<void> compose(
    WidgetTester tester,
    String text, {
    required bool collapsed,
  }) async {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing:
            collapsed ? TextRange.empty : TextRange(start: 0, end: text.length),
      ),
    );
  }

  Future<List<String>> pumpTerminal(WidgetTester tester) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );
    await tester.tap(find.byType(TerminalView));
    await tester.pump();

    return output;
  }

  testWidgets(
    'commits composing text before Android newline and ignores its delayed commit',
    (tester) async {
      final output = await pumpTerminal(tester);

      await compose(tester, 'htop', collapsed: false);
      expect(output, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await compose(tester, 'htop', collapsed: true);

      expect(output.join(), 'htop\r');
    },
  );

  testWidgets('commits a multi-word Android composition exactly once', (
    tester,
  ) async {
    final output = await pumpTerminal(tester);

    // Android keyboards may update the full composing buffer while the user
    // types each word. No intermediate update may be sent to the terminal.
    await compose(tester, 'cd', collapsed: false);
    await compose(tester, 'cd /var/log', collapsed: false);
    expect(output, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await compose(tester, 'cd /var/log', collapsed: true);

    expect(output.join(), 'cd /var/log\r');
  });

  testWidgets('resetEditingState drops a pending composition', (tester) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);
    final viewKey = GlobalKey<TerminalViewState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, key: viewKey, autofocus: true),
        ),
      ),
    );
    await tester.tap(find.byType(TerminalView));
    await tester.pump();

    await compose(tester, 'ls', collapsed: false);
    expect(output, isEmpty);

    viewKey.currentState!.resetEditingState();
    await tester.pump();

    // deleteDetection is off by default, so the initial state is empty text.
    expect(tester.testTextInput.editingState?['text'], '');
    expect(output, isEmpty);

    await compose(tester, 'pwd', collapsed: true);
    expect(output.join(), 'pwd');
  });
}
