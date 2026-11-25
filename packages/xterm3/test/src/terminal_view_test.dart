import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xterm3/src/ui/shortcut/actions.dart';
import 'package:xterm3/xterm.dart';

import '../_fixture/_fixture.dart';

@GenerateNiceMocks([MockSpec<TerminalInputHandler>()])
import 'terminal_view_test.mocks.dart';

const _lightTheme = TerminalTheme(
  cursor: Color(0xff111111),
  selection: Color(0xffcccccc),
  foreground: Color(0xff111111),
  background: Color(0xffffffff),
  black: Color(0xff000000),
  red: Color(0xffaa0000),
  green: Color(0xff00aa00),
  yellow: Color(0xffaa5500),
  blue: Color(0xff0000aa),
  magenta: Color(0xffaa00aa),
  cyan: Color(0xff00aaaa),
  white: Color(0xffaaaaaa),
  brightBlack: Color(0xff555555),
  brightRed: Color(0xffff5555),
  brightGreen: Color(0xff55ff55),
  brightYellow: Color(0xffffff55),
  brightBlue: Color(0xff5555ff),
  brightMagenta: Color(0xffff55ff),
  brightCyan: Color(0xff55ffff),
  brightWhite: Color(0xffffffff),
  searchHitBackground: Color(0xffffff2b),
  searchHitBackgroundCurrent: Color(0xff31ff26),
  searchHitForeground: Color(0xff000000),
);

void main() {
  testWidgets('terminal writes avoid layout when geometry is unchanged', (
    tester,
  ) async {
    final terminal = Terminal();
    await tester.pumpWidget(MaterialApp(home: TerminalView(terminal)));
    await tester.pump();
    final state = tester.state<TerminalViewState>(find.byType(TerminalView));

    terminal.write('text');

    expect(state.renderTerminal.debugNeedsLayout, isFalse);
  });

  testWidgets('TerminalView answers color queries from its theme', (
    tester,
  ) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);
    await tester.pumpWidget(MaterialApp(
      home: TerminalView(
        terminal,
        theme: TerminalThemes.whiteOnBlack,
      ),
    ));

    terminal.write(
      '\x1b]4;1;?\x1b\\'
      '\x1b]10;?;?;?\x1b\\'
      '\x1b[?996n',
    );

    expect(output, [
      '\x1b]4;1;rgb:cdcd/3131/3131\x1b\\',
      '\x1b]10;rgb:ffff/ffff/ffff\x1b\\',
      '\x1b]11;rgb:0000/0000/0000\x1b\\',
      '\x1b]12;rgb:aeae/afaf/adad\x1b\\',
      '\x1b[?997;1n',
    ]);

    await tester.pumpWidget(const SizedBox());
    expect(terminal.onColorQuery, isNull);
    expect(terminal.onColorSchemeQuery, isNull);
  });

  testWidgets('TerminalView reports color scheme changes when requested', (
    tester,
  ) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(MaterialApp(
      home: TerminalView(
        terminal,
        theme: TerminalThemes.whiteOnBlack,
      ),
    ));

    terminal.write('\x1b[?2031h');

    await tester.pumpWidget(MaterialApp(
      home: TerminalView(
        terminal,
        theme: _lightTheme,
      ),
    ));

    terminal.write('\x1b[?2031l');

    await tester.pumpWidget(MaterialApp(
      home: TerminalView(
        terminal,
        theme: TerminalThemes.whiteOnBlack,
      ),
    ));

    expect(output, [
      '\x1b[?997;1n',
      '\x1b[?997;2n',
    ]);
  });

  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'htop golden test',
    (tester) async {
      final terminal = Terminal();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal),
        ),
      ));

      terminal.write(TestFixtures.htop_80x25_3s());
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/htop_80x25_3s.png'),
      );
    },
    skip: !Platform.isMacOS,
  );

  testWidgets(
    'color golden test',
    (tester) async {
      final terminal = Terminal();

      // terminal.lineFeedMode = true;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            textStyle: TerminalStyle(fontSize: 8),
          ),
        ),
      ));

      terminal.write(TestFixtures.colors().replaceAll('\n', '\r\n'));
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/colors.png'),
      );
    },
    skip: !Platform.isMacOS,
  );

  group('TerminalView.predictionText', () {
    testWidgets('renders without error and takes the prediction paint path', (
      tester,
    ) async {
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, predictionText: 'ls'),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      expect(state.renderTerminal.debugIsShowingPrediction, isTrue);
    });

    testWidgets('null and empty strings draw nothing', (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal)),
      );
      await tester.pump();

      var state = tester.state<TerminalViewState>(find.byType(TerminalView));
      expect(state.renderTerminal.debugIsShowingPrediction, isFalse);

      await tester.pumpWidget(
        MaterialApp(home: TerminalView(terminal, predictionText: '')),
      );
      await tester.pump();

      state = tester.state<TerminalViewState>(find.byType(TerminalView));
      expect(state.renderTerminal.debugIsShowingPrediction, isFalse);
    });

    testWidgets(
      'changing predictionText on a mounted widget updates the render object',
      (tester) async {
        final terminal = Terminal();

        await tester.pumpWidget(
          MaterialApp(home: TerminalView(terminal)),
        );
        await tester.pump();

        final state =
            tester.state<TerminalViewState>(find.byType(TerminalView));
        expect(state.renderTerminal.debugIsShowingPrediction, isFalse);

        await tester.pumpWidget(
          MaterialApp(home: TerminalView(terminal, predictionText: 'ls -al')),
        );
        await tester.pump();

        expect(state.renderTerminal.debugIsShowingPrediction, isTrue);

        await tester.pumpWidget(
          MaterialApp(home: TerminalView(terminal)),
        );
        await tester.pump();

        expect(state.renderTerminal.debugIsShowingPrediction, isFalse);
      },
    );
  });

  group('TerminalView.readOnly', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, readOnly: true, autofocus: true),
        ),
      ));

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), isEmpty);
    });

    testWidgets('does not block input when false', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, readOnly: false, autofocus: true),
        ),
      ));

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), 'ls -al');
    });
  });

  group('TerminalView.focusNode', () {
    testWidgets('reports focus changes when requested by the application', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..write('\x1b[?1004h');
      final terminalFocus = FocusNode();
      final otherFocus = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                height: 200,
                child: TerminalView(terminal, focusNode: terminalFocus),
              ),
              Focus(focusNode: otherFocus, child: const SizedBox()),
            ],
          ),
        ),
      );

      terminalFocus.requestFocus();
      await tester.pump();
      otherFocus.requestFocus();
      await tester.pump();

      expect(output, ['\x1b[I', '\x1b[I', '\x1b[O']);
      await tester.pumpWidget(const SizedBox());
      terminalFocus.dispose();
      otherFocus.dispose();
    });

    testWidgets('is not listened when terminal is disposed', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, isActive, child) {
              if (!isActive) {
                return Container();
              }
              return TerminalView(
                terminal,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ));

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isTrue);

      isActive.value = false;
      await tester.pumpAndSettle();

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isFalse);
    });

    testWidgets('does not dispose external focus node', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, isActive, child) {
              if (!isActive) {
                return Container();
              }
              return TerminalView(
                terminal,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ));

      isActive.value = false;
      await tester.pumpAndSettle();

      expect(() => focusNode.addListener(() {}), returnsNormally);
    });
  });

  testWidgets('TerminalView renders and times out cursor blinking', (
    tester,
  ) async {
    final terminal = Terminal()..write('\x1b[1 q');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal,
          focusNode: focusNode,
          autofocus: true,
        ),
      ),
    );
    await tester.pump();

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    expect(state.renderTerminal.isCursorBlinkVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 750));
    expect(state.renderTerminal.isCursorBlinkVisible, isFalse);

    await tester.pump(const Duration(milliseconds: 750));
    expect(state.renderTerminal.isCursorBlinkVisible, isTrue);

    await tester.pump(const Duration(seconds: 5));
    expect(state.renderTerminal.isCursorBlinkVisible, isTrue);

    terminal.write('x');
    await tester.pump();
    expect(state.renderTerminal.isCursorBlinkVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 750));
    expect(state.renderTerminal.isCursorBlinkVisible, isFalse);

    await tester.pumpWidget(const SizedBox());
    focusNode.dispose();
  });

  testWidgets('TerminalView activates OSC 8 hyperlinks with modifier', (
    tester,
  ) async {
    final terminal = Terminal()
      ..write('\x1b]8;;https://example.com\x1b\\link\x1b]8;;\x1b\\');
    String? activatedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal,
          onHyperlinkTap: (uri) => activatedUri = uri,
        ),
      ),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final position = state.renderTerminal.localToGlobal(const Offset(2, 2));

    // A mouse click without the modifier held must not activate the link —
    // that's reserved for touch, which has no modifier key to hold.
    await tester.tapAt(position, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(activatedUri, isNull);
    expect(state.renderTerminal.activeHyperlinkId, isNull);

    final modifierKey = switch (defaultTargetPlatform == TargetPlatform.macOS) {
      true => LogicalKeyboardKey.metaLeft,
      false => LogicalKeyboardKey.controlLeft,
    };
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(position));
    await tester.sendKeyDownEvent(modifierKey);
    await tester.pump();

    expect(state.renderTerminal.activeHyperlinkId, isNotNull);

    await tester.tapAt(position, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(activatedUri, 'https://example.com');

    await tester.sendKeyUpEvent(modifierKey);
    await tester.pump();

    expect(state.renderTerminal.activeHyperlinkId, isNull);
  });

  testWidgets('TerminalView activates OSC 8 hyperlinks on touch tap', (
    tester,
  ) async {
    final terminal = Terminal()
      ..write('\x1b]8;;https://example.com\x1b\\link\x1b]8;;\x1b\\');
    String? activatedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal,
          onHyperlinkTap: (uri) => activatedUri = uri,
        ),
      ),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final position = state.renderTerminal.localToGlobal(const Offset(2, 2));

    // Touch has no modifier key to hold, so tapping a link opens it directly.
    await tester.tapAt(position, kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(activatedUri, 'https://example.com');
  });

  testWidgets('TerminalView activates plain-text URLs on touch tap', (
    tester,
  ) async {
    final terminal = Terminal()..write('see https://example.com/foo now');
    String? activatedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal,
          onHyperlinkTap: (uri) => activatedUri = uri,
        ),
      ),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final cellSize = state.renderTerminal.cellSize;
    // Column 4 lands inside "https://example.com/foo" ("see " is 4 columns).
    final position = state.renderTerminal.localToGlobal(
      Offset(cellSize.width * 4.5, cellSize.height * 0.5),
    );

    await tester.tapAt(position, kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(activatedUri, 'https://example.com/foo');
  });

  testWidgets(
      'TerminalView activates hovered OSC 8 links when modifier is held',
      (tester) async {
    final terminal = Terminal()
      ..write('\x1b]8;;https://example.com\x1b\\link\x1b]8;;\x1b\\');
    String? activatedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal,
          onHyperlinkTap: (uri) => activatedUri = uri,
        ),
      ),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
    final modifierKey = switch (defaultTargetPlatform == TargetPlatform.macOS) {
      true => LogicalKeyboardKey.metaLeft,
      false => LogicalKeyboardKey.controlLeft,
    };
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    await tester.sendKeyDownEvent(modifierKey);
    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();

    expect(state.renderTerminal.activeHyperlinkId, isNotNull);

    await tester.tapAt(position);
    await tester.pump();

    expect(activatedUri, 'https://example.com');

    await tester.sendKeyUpEvent(modifierKey);
  });

  testWidgets(
      'TerminalView underlines a plain-text URL when the modifier goes down '
      'under a stationary pointer', (tester) async {
    // Plain-text URL detection is skipped while the modifier is up, because
    // nothing can act on the result and detection rebuilds the logical line
    // at pointer-move rates. Pressing the modifier without moving the pointer
    // has to run it once, or the link never lights up.
    final terminal = Terminal()..write('see https://example.com/x for more');
    final controller = TerminalController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalView(terminal, controller: controller)),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final cell = state.renderTerminal.getOffset(const CellOffset(8, 0));
    final position = state.renderTerminal.localToGlobal(cell);
    final modifierKey = switch (defaultTargetPlatform == TargetPlatform.macOS) {
      true => LogicalKeyboardKey.metaLeft,
      false => LogicalKeyboardKey.controlLeft,
    };
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();
    expect(controller.underlines, isEmpty);

    await tester.sendKeyDownEvent(modifierKey);
    await tester.pump();
    expect(controller.underlines, hasLength(1));

    await tester.sendKeyUpEvent(modifierKey);
    await tester.pump();
    expect(controller.underlines, isEmpty);
  });

  testWidgets(
      'TerminalView reports the editable rect once per frame, not '
      'once per write', (tester) async {
    // `_notifyEditableRect` walks to the root through `localToGlobal`. A PTY
    // hands over many small chunks between frames and each is a
    // `Terminal.write`, so reporting inline meant one ancestor walk per chunk
    // to publish a rect that can only be observed after the frame.
    final terminal = Terminal();

    await tester.pumpWidget(MaterialApp(home: TerminalView(terminal)));

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    var reports = 0;
    state.renderTerminal.onEditableRect = (rect, caretRect) => reports++;

    for (var i = 0; i < 50; i++) {
      terminal.write('chunk $i\r\n');
    }
    expect(reports, 0, reason: 'writes alone must not report');

    await tester.pump();
    expect(reports, 1);

    // A frame with no terminal change must not report again.
    await tester.pump();
    expect(reports, 1);
  });

  testWidgets('TerminalView updates hovered links from global modifiers', (
    tester,
  ) async {
    final terminal = Terminal()
      ..write('\x1b]8;;https://example.com\x1b\\link\x1b]8;;\x1b\\');

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(terminal),
      ),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
    final modifierKey = switch (defaultTargetPlatform == TargetPlatform.macOS) {
      true => LogicalKeyboardKey.metaLeft,
      false => LogicalKeyboardKey.controlLeft,
    };
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();
    expect(state.renderTerminal.activeHyperlinkId, isNull);

    await tester.sendKeyDownEvent(modifierKey);
    await tester.pump();
    expect(state.renderTerminal.activeHyperlinkId, isNotNull);

    await tester.sendKeyUpEvent(modifierKey);
    await tester.pump();
    expect(state.renderTerminal.activeHyperlinkId, isNull);
  });

  testWidgets('TerminalView reports hovered cell offsets', (tester) async {
    final terminal = Terminal()..write('abcdef');
    CellOffset? hoveredOffset;
    var exited = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalView(
          terminal,
          onHover: (_, offset) => hoveredOffset = offset,
          onExit: (_) => exited = true,
        ),
      ),
    );

    final state = tester.state<TerminalViewState>(find.byType(TerminalView));
    final position = state.renderTerminal.localToGlobal(
      Offset(state.renderTerminal.cellSize.width * 2.5, 2),
    );
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    await tester.sendEventToBinding(pointer.hover(position));
    await tester.pump();

    expect(hoveredOffset, const CellOffset(2, 0));

    await tester.sendEventToBinding(pointer.hover(const Offset(-10, -10)));
    await tester.pump();

    expect(exited, isTrue);
  });

  group('TerminalController.pointerInputs', () {
    testWidgets('reports pointer motion requested by the application', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)
        ..write('\x1b[?1003h\x1b[?1006h');
      final controller = TerminalController(pointerInputs: PointerInputs.all());

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, controller: controller),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(4, 4)));
      await tester.pump();

      expect(output, isNotEmpty);
      expect(output.last, startsWith('\x1b[<35;'));
    });

    testWidgets('reports pointer motion with the default controller', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)
        ..write('\x1b[?1003h\x1b[?1006h');
      final controller = TerminalController();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, controller: controller),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(4, 4)));
      await tester.pump();

      expect(output, isNotEmpty);
      expect(output.last, startsWith('\x1b[<35;'));

      controller.dispose();
    });

    testWidgets('does not report pointer motion without a mouse mode', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = TerminalController();

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalView(terminal, controller: controller),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(4, 4)));
      await tester.pump();

      expect(output, isEmpty);

      controller.dispose();
    });

    testWidgets('works', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.all(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: terminalView,
            ),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isNotEmpty);
    });

    testWidgets('does not respond when disabled', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.none(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: terminalView,
            ),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isEmpty);
    });

    testWidgets('shift bypasses mouse reporting for selection', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..write('abcdef');
      terminal.write('\x1b[?1002h');

      final controller = TerminalController(
        pointerInputs: PointerInputs.all(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final cellSize = state.renderTerminal.cellSize;
      final start = state.renderTerminal.localToGlobal(
        Offset(cellSize.width * 0.5, cellSize.height * 0.5),
      );
      final end = state.renderTerminal.localToGlobal(
        Offset(cellSize.width * 3.5, cellSize.height * 0.5),
      );
      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(pointer.down(start));
      await tester.pump();
      await tester.sendEventToBinding(pointer.move(end));
      await tester.pump();
      await tester.sendEventToBinding(pointer.up());
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(output, isEmpty);
      final selection = controller.selection;
      expect(selection, isNotNull);
      if (selection != null) {
        expect(terminal.buffer.getText(selection), 'abcd');
      }
    });

    testWidgets('XTSHIFTESCAPE captures shift mouse reporting', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..write('abcdef');
      terminal.write('\x1b[?1002h\x1b[?1006h\x1b[>1s');

      final controller = TerminalController(
        pointerInputs: PointerInputs.all(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final cellSize = state.renderTerminal.cellSize;
      final position = state.renderTerminal.localToGlobal(
        Offset(cellSize.width * 0.5, cellSize.height * 0.5),
      );
      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(pointer.down(position));
      await tester.pump();
      await tester.sendEventToBinding(pointer.up());
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(output, contains('\x1b[<4;1;1M'));
      expect(controller.selection, isNull);
    });

    testWidgets('reports scroll at local terminal coordinates', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1049h\x1b[?1000h\x1b[?1006h');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 40, top: 30),
              child: TerminalView(terminal),
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(
        const Offset(2, 2),
      );

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(0, state.renderTerminal.lineHeight),
        ),
      );
      await tester.pump();

      expect(output, isNotEmpty);
      expect(output.last, '\x1b[<65;1;1M');
    });

    testWidgets('reports scroll from the main buffer', (tester) async {
      final output = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: output.add);
      final scrollController = ScrollController();
      terminal.write(List.generate(100, (index) => '$index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );

      terminal.write('\x1b[?1000h\x1b[?1006h');
      await tester.pump();

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      final scrollOffsetBefore = scrollController.offset;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(0, -state.renderTerminal.lineHeight),
        ),
      );
      await tester.pump();

      expect(output, contains('\x1b[<64;1;1M'));
      expect(scrollController.offset, scrollOffsetBefore);
    });

    testWidgets('shift scrolls main-buffer history during mouse reporting', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: output.add);
      final scrollController = ScrollController();
      terminal.write(List.generate(100, (index) => '$index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );

      terminal.write('\x1b[?1000h\x1b[?1006h');
      await tester.pump();

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      final scrollOffsetBefore = scrollController.offset;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(0, -state.renderTerminal.lineHeight),
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(output, isEmpty);
      expect(scrollController.offset, lessThan(scrollOffsetBefore));
    });

    testWidgets('XTSHIFTESCAPE captures shift scroll reporting', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: output.add);
      final scrollController = ScrollController();
      terminal.write(List.generate(100, (index) => '$index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );

      terminal.write('\x1b[?1000h\x1b[?1006h\x1b[>1s');
      await tester.pump();

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      final scrollOffsetBefore = scrollController.offset;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(0, -state.renderTerminal.lineHeight),
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(output, contains('\x1b[<68;1;1M'));
      expect(scrollController.offset, scrollOffsetBefore);
    });

    testWidgets('restores main-buffer scrollback after mouse reporting', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: output.add);
      final scrollController = ScrollController();
      terminal.write(List.generate(100, (index) => '$index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );

      terminal.write('\x1b[?1000h\x1b[?1006h');
      await tester.pump();
      terminal.write('\x1b[?1000l');
      await tester.pump();

      final scrollOffsetBefore = scrollController.offset;
      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(0, -state.renderTerminal.lineHeight),
        ),
      );
      await tester.pump();

      expect(scrollController.offset, lessThan(scrollOffsetBefore));
      expect(output, isEmpty);
    });

    testWidgets('accumulates precision scroll deltas', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1000h\x1b[?1006h');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      final partialDelta = state.renderTerminal.lineHeight * 0.6;
      for (var index = 0; index < 2; index++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: Offset(0, partialDelta),
          ),
        );
        await tester.pump();
      }

      expect(output, ['\x1b[<65;1;1M']);
    });

    testWidgets('reports horizontal wheel input to applications', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1000h\x1b[?1006h');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      final cellWidth = state.renderTerminal.cellSize.width;

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(cellWidth, 0),
        ),
      );
      await tester.pump();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: Offset(-cellWidth, 0),
        ),
      );
      await tester.pump();

      expect(output, ['\x1b[<67;1;1M', '\x1b[<66;1;1M']);
    });

    testWidgets('simulates horizontal wheel input in alternate screens', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1049h');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(terminal),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(const Offset(2, 2));
      final partialDelta = state.renderTerminal.cellSize.width * 0.6;
      for (var index = 0; index < 2; index++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: Offset(partialDelta, 0),
          ),
        );
        await tester.pump();
      }

      expect(output, ['\x1b[C']);
    });
  });

  group('TerminalView.autofocus', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('works in hardwareKeyboardOnly mode', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });
  });

  group('TerminalView.hardwareKeyboardOnly', () {
    testWidgets('works', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

      expect(output.join(), 'abc');
    });
  });

  group('TerminalView scrollback shortcuts', () {
    testWidgets('shift navigation scrolls the main buffer', (tester) async {
      final output = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: output.add)
        ..resize(20, 5);
      final scrollController = ScrollController();
      terminal.write(
        List.generate(40, (index) => 'line $index\r\n').join(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 120,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
                autoResize: false,
                autofocus: true,
              ),
            ),
          ),
        ),
      );

      final maxScrollExtent = scrollController.position.maxScrollExtent;
      expect(scrollController.offset, maxScrollExtent);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();

      expect(scrollController.offset, lessThan(maxScrollExtent));
      final pageUpOffset = scrollController.offset;

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      expect(scrollController.offset, greaterThan(pageUpOffset));

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();

      expect(
          scrollController.offset, scrollController.position.minScrollExtent);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(scrollController.offset, maxScrollExtent);
      expect(output, isEmpty);

      scrollController.dispose();
    });

    testWidgets('shift navigation remains available to alternate-screen apps', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1049h');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autoResize: false,
              autofocus: true,
            ),
          ),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(output, contains('\x1b[1;2A'));
    });

    testWidgets('semantic prompt navigation follows prompt history', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(maxLines: 100, onOutput: output.add)
        ..resize(20, 5);
      final scrollController = ScrollController();
      for (var prompt = 0; prompt < 5; prompt++) {
        terminal.write('\x1b]133;A\x1b\\prompt $prompt\r\n');
        for (var line = 0; line < 5; line++) {
          terminal.write('output $prompt.$line\r\n');
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 120,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
                autoResize: false,
                autofocus: true,
              ),
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final lineHeight = state.renderTerminal.lineHeight;
      final maxScrollExtent = scrollController.position.maxScrollExtent;
      final firstTopLine = (maxScrollExtent / lineHeight).floor();
      final firstTarget = terminal.semanticPromptLineBefore(firstTopLine);
      expect(firstTarget, isNotNull);

      await _sendPromptNavigationShortcut(
        tester,
        LogicalKeyboardKey.arrowUp,
      );
      await tester.pump();

      if (firstTarget != null) {
        expect(
          scrollController.offset,
          closeTo(firstTarget * lineHeight, 0.01),
        );
      }

      final secondTarget = terminal.semanticPromptLineBefore(firstTarget ?? 0);
      expect(secondTarget, isNotNull);

      await _sendPromptNavigationShortcut(
        tester,
        LogicalKeyboardKey.arrowUp,
      );
      await tester.pump();

      if (secondTarget != null) {
        expect(
          scrollController.offset,
          closeTo(secondTarget * lineHeight, 0.01),
        );
      }

      await _sendPromptNavigationShortcut(
        tester,
        LogicalKeyboardKey.arrowDown,
      );
      await tester.pump();

      if (firstTarget != null) {
        expect(
          scrollController.offset,
          closeTo(firstTarget * lineHeight, 0.01),
        );
      }
      expect(output, isEmpty);

      scrollController.dispose();
    });

    testWidgets('prompt shortcuts remain available to alternate-screen apps', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('\x1b[?1049h');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autoResize: false,
              autofocus: true,
            ),
          ),
        ),
      );

      await _sendPromptNavigationShortcut(
        tester,
        LogicalKeyboardKey.arrowUp,
      );
      await tester.pump();

      expect(output, isNotEmpty);
    });
  });

  group('TerminalView shortcuts', () {
    testWidgets('forwards Ctrl+A and Ctrl+V on non-Apple platforms', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TerminalView(
                terminal,
                autofocus: true,
                hardwareKeyboardOnly: true,
              ),
            ),
          ),
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      expect(output, ['\x01', '\x16']);
    });

    testWidgets('select all includes scrollback', (tester) async {
      final terminal = Terminal(maxLines: 10)..resize(4, 2);
      final controller = TerminalController();

      terminal.write('line1\r\nline2\r\nline3');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autofocus: true,
              shortcuts: {
                SingleActivator(LogicalKeyboardKey.keyA):
                    const SelectAllTextIntent(SelectionChangedCause.keyboard),
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

      expect(
        terminal.buffer.getText(controller.selection),
        startsWith('line1\nline2\nline3'),
      );

      controller.dispose();
    });

    testWidgets('copy selection trims trailing whitespace', (tester) async {
      final terminal = Terminal(maxLines: 10)..resize(5, 3);
      final controller = TerminalController();
      String? clipboardText;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final arguments = call.arguments;
              if (arguments is Map) {
                clipboardText = arguments['text'] as String?;
              }
              return null;
            case 'Clipboard.getData':
              return {'text': clipboardText};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      terminal.write('1AB  \r\n2EFGH');
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(3, 1),
      );

      late BuildContext actionContext;
      await tester.pumpWidget(
        MaterialApp(
          home: TerminalActions(
            terminal: terminal,
            controller: controller,
            getScrollPosition: () => null,
            getLineHeight: () => 1,
            child: Builder(
              builder: (context) {
                actionContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final result =
          Actions.invoke(actionContext, CopySelectionTextIntent.copy);
      if (result is Future) {
        await result;
      }

      expect(clipboardText, '1AB\n2EF');

      controller.dispose();
    });
  });

  group('TerminalView selection gestures', () {
    testWidgets('mouse-reporting apps own repeated clicks', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..write('clickable');
      terminal.write('\x1b[?1000h\x1b[?1006h');
      final controller = TerminalController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autoResize: false,
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final position = state.renderTerminal.localToGlobal(
        Offset(
          state.renderTerminal.cellSize.width * 1.5,
          state.renderTerminal.cellSize.height * 0.5,
        ),
      );

      await tester.tapAt(position);
      await tester.tapAt(position);
      await tester.tapAt(position);

      expect(output.where((value) => value.endsWith('M')), hasLength(3));
      expect(output.where((value) => value.endsWith('m')), hasLength(3));
      expect(controller.selection, isNull);

      controller.dispose();
    });

    testWidgets('mouse-reporting apps receive drag releases', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..write('drag target');
      terminal.write('\x1b[?1000h\x1b[?1006h');
      final controller = TerminalController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autoResize: false,
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final start = state.renderTerminal.localToGlobal(
        Offset(
          state.renderTerminal.cellSize.width * 0.5,
          state.renderTerminal.cellSize.height * 0.5,
        ),
      );
      final end = state.renderTerminal.localToGlobal(
        Offset(
          state.renderTerminal.cellSize.width * 5.5,
          state.renderTerminal.cellSize.height * 0.5,
        ),
      );
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );

      await gesture.down(start);
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final secondaryGesture = await tester.createGesture(
        pointer: 2,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await secondaryGesture.down(start);
      await secondaryGesture.moveTo(end);
      await tester.pump();
      await secondaryGesture.up();
      await tester.pump();

      final backGesture = await tester.createGesture(
        pointer: 3,
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await backGesture.down(start);
      await backGesture.moveTo(end);
      await tester.pump();
      await backGesture.up();
      await tester.pump();

      expect(output.where((value) => value.endsWith('M')), hasLength(3));
      expect(output.where((value) => value.endsWith('m')), hasLength(3));
      expect(output, contains(startsWith('\x1b[<0;')));
      expect(output, contains(startsWith('\x1b[<2;')));
      expect(output, contains(startsWith('\x1b[<128;')));
      expect(controller.selection, isNull);

      controller.dispose();
    });

    testWidgets('dragging beyond the viewport scrolls the selection', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100)..resize(20, 5);
      final controller = TerminalController();
      final scrollController = ScrollController();

      terminal.write(
        List.generate(40, (index) => 'line $index\r\n').join(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: TerminalView(
                terminal,
                controller: controller,
                scrollController: scrollController,
                autoResize: false,
              ),
            ),
          ),
        ),
      );

      scrollController.jumpTo(0);
      await tester.pump();

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final renderTerminal = state.renderTerminal;
      final start = renderTerminal.localToGlobal(
        Offset(renderTerminal.cellSize.width, renderTerminal.lineHeight),
      );
      final beyondBottom = renderTerminal.localToGlobal(
        Offset(
          renderTerminal.cellSize.width * 4,
          renderTerminal.size.height + renderTerminal.lineHeight * 2,
        ),
      );

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.down(start);
      await gesture.moveTo(beyondBottom);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(scrollController.offset, greaterThan(0));
      expect(controller.selection, isNotNull);
      // The rows the auto-scroller brought in extend the selection; they do
      // not move where it started.
      expect(controller.selection!.normalized.begin, const CellOffset(1, 1));

      await gesture.up();
      await tester.pumpAndSettle();
      final offsetAfterDrag = scrollController.offset;
      await tester.pump(const Duration(milliseconds: 200));

      expect(scrollController.offset, offsetAfterDrag);

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
      final offsetBeforeUpwardDrag = scrollController.offset;
      final upwardStart = renderTerminal.localToGlobal(
        Offset(
          renderTerminal.cellSize.width * 4,
          renderTerminal.size.height - renderTerminal.lineHeight,
        ),
      );
      final beyondTop = renderTerminal.localToGlobal(
        Offset(
          renderTerminal.cellSize.width,
          -renderTerminal.lineHeight * 2,
        ),
      );

      final upwardStartRow = renderTerminal
          .getCellOffset(renderTerminal.globalToLocal(upwardStart))
          .y;

      final upwardGesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await upwardGesture.down(upwardStart);
      await upwardGesture.moveTo(beyondTop);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(scrollController.offset, lessThan(offsetBeforeUpwardDrag));
      expect(controller.selection!.normalized.end.y, upwardStartRow);

      await upwardGesture.up();
      await tester.pumpAndSettle();

      controller.dispose();
      scrollController.dispose();
    });

    testWidgets(
      'dragging inside an offset terminal does not trigger upward auto scroll',
      (tester) async {
        final terminal = Terminal(maxLines: 100)..resize(20, 5);
        final controller = TerminalController();
        final scrollController = ScrollController();

        terminal.write(
          List.generate(40, (index) => 'line $index\r\n').join(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: SizedBox(
                  width: 400,
                  height: 120,
                  child: TerminalView(
                    terminal,
                    controller: controller,
                    scrollController: scrollController,
                    autoResize: false,
                  ),
                ),
              ),
            ),
          ),
        );

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();
        final initialOffset = scrollController.offset;
        expect(initialOffset, greaterThan(0));

        final state =
            tester.state<TerminalViewState>(find.byType(TerminalView));
        final renderTerminal = state.renderTerminal;

        // Position inside the terminal (line 2), well below the top edge.
        // Local y is lineHeight * 2 (approx 30px, while top padding is 100px).
        final dragStart = renderTerminal.localToGlobal(
          Offset(
            renderTerminal.cellSize.width * 2,
            renderTerminal.lineHeight * 2,
          ),
        );
        final dragMove = renderTerminal.localToGlobal(
          Offset(
            renderTerminal.cellSize.width * 3,
            renderTerminal.lineHeight * 2,
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.down(dragStart);
        await gesture.moveTo(dragMove);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        // Without the fix, localPosition (y < 100) is compared against globalRect.top (100),
        // incorrectly triggering upward auto-scroll.
        expect(scrollController.offset, equals(initialOffset));

        await gesture.up();
        await tester.pumpAndSettle();

        // Dragging beyond the top of the terminal (into the padding area) SHOULD trigger upward auto-scroll.
        final beyondTop = renderTerminal.localToGlobal(
          Offset(
            renderTerminal.cellSize.width * 2,
            -renderTerminal.lineHeight * 2,
          ),
        );
        final upwardGesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await upwardGesture.down(dragStart);
        await upwardGesture.moveTo(beyondTop);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        expect(scrollController.offset, lessThan(initialOffset));

        await upwardGesture.up();
        await tester.pumpAndSettle();

        controller.dispose();
        scrollController.dispose();
      },
    );

    testWidgets('scrolling during a drag keeps where the selection started', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100)..resize(20, 5);
      final controller = TerminalController();
      final scrollController = ScrollController();
      terminal.write(List.generate(40, (index) => 'line $index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: TerminalView(
                terminal,
                controller: controller,
                scrollController: scrollController,
                autoResize: false,
              ),
            ),
          ),
        ),
      );
      scrollController.jumpTo(0);
      await tester.pump();

      final renderTerminal = tester
          .state<TerminalViewState>(find.byType(TerminalView))
          .renderTerminal;
      final cell = renderTerminal.cellSize;
      final start = renderTerminal.localToGlobal(
        Offset(cell.width, renderTerminal.lineHeight * 1.5),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(start);
      await gesture.moveTo(start + Offset(cell.width * 3, cell.height));
      await tester.pump();
      expect(controller.selection!.normalized.begin, const CellOffset(1, 1));

      // What a wheel does while the button is held: the viewport moves and the
      // pointer stays where it is on screen.
      scrollController.jumpTo(renderTerminal.lineHeight * 10);
      await tester.pump();
      await gesture.moveTo(start + Offset(cell.width * 4, cell.height));
      await tester.pump();

      final selection = controller.selection!.normalized;
      expect(selection.begin, const CellOffset(1, 1));
      expect(selection.end.y, 12);

      await gesture.up();
      await tester.pumpAndSettle();
      controller.dispose();
      scrollController.dispose();
    });

    testWidgets('a drag keeps its start line when scrollback is trimmed', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 40)..resize(20, 5);
      final controller = TerminalController();
      terminal.write(List.generate(40, (index) => 'line $index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: TerminalView(
                terminal,
                controller: controller,
                autoResize: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final renderTerminal = tester
          .state<TerminalViewState>(find.byType(TerminalView))
          .renderTerminal;
      final cell = renderTerminal.cellSize;
      final localStart = Offset(cell.width, renderTerminal.lineHeight * 1.5);
      final startText = terminal
          .buffer.lines[renderTerminal.getCellOffset(localStart).y]
          .getText();
      final start = renderTerminal.localToGlobal(localStart);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(start);
      await gesture.moveTo(start + Offset(cell.width * 3, 0));
      await tester.pump();

      // The buffer is full, so every new line drops one off the top and
      // shifts the index of every line below it.
      terminal.write('more 0\r\nmore 1\r\nmore 2\r\n');
      await tester.pump();
      await gesture.moveTo(start + Offset(cell.width * 4, 0));
      await tester.pump();

      final selection = controller.selection!.normalized;
      expect(terminal.buffer.lines[selection.begin.y].getText(), startText);

      await gesture.up();
      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('scrolling during a long press keeps where it started', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100)..resize(20, 5);
      final controller = TerminalController();
      final scrollController = ScrollController();
      terminal.write(List.generate(40, (index) => 'line $index\r\n').join());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: TerminalView(
                terminal,
                controller: controller,
                scrollController: scrollController,
                autoResize: false,
              ),
            ),
          ),
        ),
      );
      scrollController.jumpTo(0);
      await tester.pump();

      final renderTerminal = tester
          .state<TerminalViewState>(find.byType(TerminalView))
          .renderTerminal;
      final cell = renderTerminal.cellSize;
      final start = renderTerminal.localToGlobal(
        Offset(cell.width, renderTerminal.lineHeight * 1.5),
      );

      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(controller.selection!.normalized.begin, const CellOffset(0, 1));

      scrollController.jumpTo(renderTerminal.lineHeight * 10);
      await tester.pump();
      await gesture.moveTo(start + Offset(cell.width * 4, cell.height));
      await tester.pump();

      final selection = controller.selection!.normalized;
      expect(selection.begin, const CellOffset(0, 1));
      expect(selection.end.y, 12);

      await gesture.up();
      await tester.pumpAndSettle();
      controller.dispose();
      scrollController.dispose();
    });

    testWidgets('alt drag creates a rectangular block selection', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 10)..resize(5, 3);
      final controller = TerminalController();

      terminal.write('abcde\r\nfghij');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autoResize: false,
              autofocus: true,
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final cellSize = state.renderTerminal.cellSize;
      final start = state.renderTerminal.localToGlobal(
        Offset(cellSize.width * 1.5, cellSize.height * 0.5),
      );
      final end = state.renderTerminal.localToGlobal(
        Offset(cellSize.width * 3.5, cellSize.height * 1.5),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(start);
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(controller.selection, isA<BufferRangeBlock>());
      expect(terminal.buffer.getText(controller.selection), 'bcd\nghi');

      controller.dispose();
    });

    testWidgets('triple click selects a soft-wrapped line', (tester) async {
      final terminal = Terminal(maxLines: 10)..resize(5, 4);
      final controller = TerminalController();

      terminal.write('old\r\nhelloworld\r\nafter');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              autoResize: false,
              autofocus: true,
            ),
          ),
        ),
      );

      final state = tester.state<TerminalViewState>(find.byType(TerminalView));
      final cellSize = state.renderTerminal.cellSize;
      final position = state.renderTerminal.localToGlobal(
        Offset(cellSize.width * 1.5, cellSize.height * 2.5),
      );

      await tester.tapAt(position);
      await tester.tapAt(position);
      await tester.tapAt(position);

      expect(
        terminal.buffer.getText(controller.selection),
        startsWith('helloworld'),
      );

      controller.dispose();
    });
  });

  group('TerminalView.textScaler', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();

      final textScaler = ValueNotifier(TextScaler.linear(1.0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<TextScaler>(
              valueListenable: textScaler,
              builder: (context, textScaler, child) {
                return TerminalView(
                  terminal,
                  textScaler: textScaler,
                );
              },
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@1x.png'),
      );

      textScaler.value = TextScaler.linear(2.0);
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });

    testWidgets('can obtain textScaler from parent', (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: TerminalView(
                terminal,
              ),
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });
  });

  group('TerminalView.inputHandler', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await tester.pumpAndSettle();

      expect(terminalOutput.join(), '\x04');
    });

    testWidgets('can convert text input to key events', (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) => 'AAA');

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('c');
      await binding.idle();

      await tester.pumpAndSettle();

      verify(inputHandler.call(any));
      expect(terminalOutput.join(), 'AAA');
    });

    testWidgets('forwards Kitty key release events', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.write('\x1b[=2u');

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);

      expect(terminalOutput, ['\x1b[A', '\x1b[1;1:3A']);
    });

    testWidgets('encodes unmapped text with Kitty associated text', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.write('\x1b[=24u');

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      binding.testTextInput.enterText('é');
      await binding.idle();

      binding.testTextInput.enterText('你好');
      await binding.idle();

      expect(terminalOutput, ['\x1b[233;;233u', '你好']);
    });

    testWidgets('falls back to shifted printable symbols', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.digit2,
        character: '',
        physicalKey: PhysicalKeyboardKey.digit2,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(terminalOutput, ['@']);
    });

    testWidgets('preserves macOS Option-composed text when Alt escape is off', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(
        onOutput: terminalOutput.add,
        platform: TerminalTargetPlatform.macos,
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyE,
        character: 'é',
        physicalKey: PhysicalKeyboardKey.keyE,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(terminalOutput, ['é']);
    });

    testWidgets('preserves AltGr-composed text on desktop platforms', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(
        onOutput: terminalOutput.add,
        platform: TerminalTargetPlatform.windows,
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.altRight,
        physicalKey: PhysicalKeyboardKey.altRight,
      );
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyQ,
        character: '@',
        physicalKey: PhysicalKeyboardKey.keyQ,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(terminalOutput, ['@']);
    });

    testWidgets('does not fall back to printable symbols for shortcuts', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.digit2,
        character: '',
        physicalKey: PhysicalKeyboardKey.digit2,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      expect(terminalOutput, isEmpty);
    });

    testWidgets('forwards the platform command modifier to Kitty input', (
      tester,
    ) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.write('\x1b[=1u');

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));
      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      expect(terminalOutput, contains('\x1b[50;9u'));
    });
  });

  group('TerminalView.simulateScroll', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, simulateScroll: true),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[B'));
    });

    testWidgets('does nothing when disabled', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, simulateScroll: false),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), isEmpty);
    });

    testWidgets('does nothing when read only', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(
          terminal,
          autofocus: true,
          readOnly: true,
          simulateScroll: true,
        ),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), isEmpty);
    });

    testWidgets('respects disabled scroll pointer input', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();
      final controller = TerminalController(
        pointerInputs: PointerInputs.none(),
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(
          terminal,
          autofocus: true,
          controller: controller,
          simulateScroll: true,
        ),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), isEmpty);
    });
  });
}

Future<void> _sendPromptNavigationShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
}
