import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/gesture/gesture_handler.dart';
import 'package:xterm3/src/ui/render.dart';
import 'package:xterm3/xterm.dart';

/// These tests target [TerminalGestureHandler] directly: they pump the
/// handler with their own stub callbacks and their own [TerminalController],
/// rather than going through the default wiring [TerminalView] installs for
/// itself.
///
/// [TerminalGestureHandler] requires a real, mounted [TerminalViewState] (it
/// reads `terminalView.renderTerminal` and `terminalView.widget.terminal`),
/// so each test still mounts a real [TerminalView] to obtain one. A [Column]
/// keeps that view and the handler-under-test as separate, same-tree
/// widgets: the [TerminalView] is mounted first (so its [GlobalKey] resolves
/// before the [Builder] below it runs), and the handler wraps its own
/// [ColoredBox] rather than the [TerminalView]'s content. Local positions fed
/// to the handler are plain pixel offsets scaled by `cellSize`, exactly like
/// `renderTerminal.getCellOffset` interprets them, so the handler's calls
/// into `renderTerminal` (selectWord, selectCharacters, mouseEvent) resolve
/// to predictable cells regardless of where the two widgets sit on screen.
void main() {
  late GlobalKey<TerminalViewState> viewKey;
  late GlobalKey overlayKey;

  setUp(() {
    viewKey = GlobalKey<TerminalViewState>();
    overlayKey = GlobalKey();
  });

  Widget harness({
    required Terminal terminal,
    required TerminalController controller,
    bool readOnly = false,
    GestureTapUpCallback? onTapUp,
    GestureTapUpCallback? onSingleTapUp,
    GestureTapDownCallback? onTapDown,
    GestureTapDownCallback? onSecondaryTapDown,
    GestureTapUpCallback? onSecondaryTapUp,
    GestureTapDownCallback? onTertiaryTapDown,
    GestureTapUpCallback? onTertiaryTapUp,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              height: 150,
              child: TerminalView(
                terminal,
                key: viewKey,
                controller: controller,
                autoResize: false,
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  return TerminalGestureHandler(
                    terminalView: viewKey.currentState!,
                    terminalController: controller,
                    readOnly: readOnly,
                    onTapUp: onTapUp,
                    onSingleTapUp: onSingleTapUp,
                    onTapDown: onTapDown,
                    onSecondaryTapDown: onSecondaryTapDown,
                    onSecondaryTapUp: onSecondaryTapUp,
                    onTertiaryTapDown: onTertiaryTapDown,
                    onTertiaryTapUp: onTertiaryTapUp,
                    child: SizedBox.expand(
                      child: ColoredBox(
                        key: overlayKey,
                        color: const Color(0xff101010),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset globalOf(WidgetTester tester, Offset local) {
    final box = tester.renderObject<RenderBox>(find.byKey(overlayKey));
    return box.localToGlobal(local);
  }

  // The center of buffer cell (col, row), expressed as a local offset that
  // `renderTerminal.getCellOffset`/`getViewportCellOffset` will map back to
  // that same cell. Going through `getOffset` (rather than multiplying
  // `cellSize` directly) keeps this correct regardless of the terminal's
  // current scroll position -- a fresh [Terminal] defaults to a large
  // scrollback (`maxLines: 1000`) and auto-scrolls to the bottom as content
  // is written, so "row 0 of the viewport" is not generally buffer row 0.
  Offset cellCenter(RenderTerminal rt, int col, int row) {
    final topLeft = rt.getOffset(CellOffset(col, row));
    return topLeft + Offset(rt.cellSize.width / 2, rt.cellSize.height / 2);
  }

  group('TerminalGestureHandler tap forwarding', () {
    testWidgets(
      'onTapDown always fires, even though the terminal does not report it',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        final controller = TerminalController();
        TapDownDetails? captured;

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          onTapDown: (details) => captured = details,
        ));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 1.5, cellSize.height * 0.5);
        await tester.tapAt(
          globalOf(tester, local),
          kind: PointerDeviceKind.mouse,
        );

        expect(captured, isNotNull);
        expect(captured!.localPosition, local);
        // Mouse mode is off, so the terminal never reports the click.
        expect(output, isEmpty);

        controller.dispose();
      },
    );

    testWidgets(
      'onTapDown still fires when the terminal DOES report the click '
      '(forceCallback)',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();
        TapDownDetails? captured;

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          onTapDown: (details) => captured = details,
        ));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 1.5, cellSize.height * 0.5);
        await tester.tapAt(
          globalOf(tester, local),
          kind: PointerDeviceKind.mouse,
        );

        expect(captured, isNotNull);
        expect(captured!.localPosition, local);
        // The down half of the click was reported to the application...
        expect(output, isNotEmpty);
        expect(output.first, contains('M'));

        controller.dispose();
      },
    );

    testWidgets(
      'onSingleTapUp fires when the terminal does not handle taps',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        final controller = TerminalController();
        TapUpDetails? captured;

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          onSingleTapUp: (details) => captured = details,
        ));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 2.5, cellSize.height * 0.5);
        await tester.tapAt(
          globalOf(tester, local),
          kind: PointerDeviceKind.mouse,
        );

        expect(captured, isNotNull);
        expect(captured!.localPosition, local);

        controller.dispose();
      },
    );

    testWidgets(
      'onSingleTapUp is suppressed once mouse-reporting mode is active',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();
        var called = false;

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          onSingleTapUp: (_) => called = true,
        ));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 2.5, cellSize.height * 0.5);
        await tester.tapAt(
          globalOf(tester, local),
          kind: PointerDeviceKind.mouse,
        );

        expect(called, isFalse);
        expect(output.where((v) => v.endsWith('M')), hasLength(1));
        expect(output.where((v) => v.endsWith('m')), hasLength(1));

        controller.dispose();
      },
    );

    testWidgets(
      'readOnly forces forwarding even while mouse-reporting mode is active',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();
        var called = false;

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          readOnly: true,
          onSingleTapUp: (_) => called = true,
        ));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 2.5, cellSize.height * 0.5);
        await tester.tapAt(
          globalOf(tester, local),
          kind: PointerDeviceKind.mouse,
        );

        expect(called, isTrue);
        // readOnly means the click was never reported to the terminal.
        expect(output, isEmpty);

        controller.dispose();
      },
    );

    testWidgets(
      'secondary taps report the right mouse button and forward the '
      'supplied callback when unhandled',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();
        TapDownDetails? downDetails;
        TapUpDetails? upDetails;

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          onSecondaryTapDown: (details) => downDetails = details,
          onSecondaryTapUp: (details) => upDetails = details,
        ));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 1.5, cellSize.height * 0.5);
        final global = globalOf(tester, local);
        final gesture = await tester.startGesture(
          global,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(output, contains(startsWith('\x1b[<2;')));
        // Down was reported, so the down callback is suppressed; up is not
        // suppressed for a mouse-kind event unless the terminal is actually
        // handling taps, which requires an active (non-none) mouse mode.
        expect(downDetails, isNull);
        expect(upDetails, isNull);

        controller.dispose();
      },
    );
  });

  group('TerminalGestureHandler double/triple tap word and line selection', () {
    testWidgets('double tap selects the word under the cursor', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 20)..resize(20, 5);
      terminal.write('hello world');
      final controller = TerminalController();

      await tester
          .pumpWidget(harness(terminal: terminal, controller: controller));
      await tester.pump();

      final rt = viewKey.currentState!.renderTerminal;
      final global = globalOf(tester, cellCenter(rt, 1, 0));

      await tester.tapAt(global, kind: PointerDeviceKind.mouse);
      await tester.tapAt(global, kind: PointerDeviceKind.mouse);

      expect(controller.selection, isNotNull);
      expect(terminal.buffer.getText(controller.selection), 'hello');

      controller.dispose();
    });

    testWidgets(
      'double tap is suppressed while the application handles taps',
      (tester) async {
        final terminal = Terminal(maxLines: 20)..resize(20, 5);
        terminal.write('hello world');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();

        await tester
            .pumpWidget(harness(terminal: terminal, controller: controller));
        await tester.pump();

        final rt = viewKey.currentState!.renderTerminal;
        final global = globalOf(tester, cellCenter(rt, 1, 0));

        await tester.tapAt(global, kind: PointerDeviceKind.mouse);
        await tester.tapAt(global, kind: PointerDeviceKind.mouse);

        expect(controller.selection, isNull);

        controller.dispose();
      },
    );

    testWidgets('triple tap selects the whole line', (tester) async {
      final terminal = Terminal(maxLines: 20)..resize(20, 5);
      terminal.write('hello world');
      final controller = TerminalController();

      await tester
          .pumpWidget(harness(terminal: terminal, controller: controller));
      await tester.pump();

      final rt = viewKey.currentState!.renderTerminal;
      final global = globalOf(tester, cellCenter(rt, 1, 0));

      await tester.tapAt(global, kind: PointerDeviceKind.mouse);
      await tester.tapAt(global, kind: PointerDeviceKind.mouse);
      await tester.tapAt(global, kind: PointerDeviceKind.mouse);

      expect(controller.selection, isNotNull);
      expect(
        terminal.buffer.getText(controller.selection),
        startsWith('hello world'),
      );

      controller.dispose();
    });
  });

  group('TerminalGestureHandler long press', () {
    testWidgets('long press start selects the word, move extends it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 20)..resize(20, 5);
      terminal.write('hello brave world');
      final controller = TerminalController();

      await tester
          .pumpWidget(harness(terminal: terminal, controller: controller));
      await tester.pump();

      final rt = viewKey.currentState!.renderTerminal;
      final start = cellCenter(rt, 1, 0);
      final end = cellCenter(rt, 14, 0);

      final gesture = await tester.startGesture(
        globalOf(tester, start),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      expect(
        terminal.buffer.getText(controller.selection),
        'hello',
      );

      await gesture.moveTo(globalOf(tester, end));
      await tester.pump();

      expect(
        terminal.buffer.getText(controller.selection),
        'hello brave world',
      );

      await gesture.up();
      controller.dispose();
    });

    testWidgets(
      'long press on blank space selects that cell and still extends',
      (tester) async {
        // Most of a full-screen editor is blank: short lines leave the right
        // of the window empty and everything past the end of the file is
        // filler. A long press there used to select nothing, and because
        // every move update re-read the same blank starting cell, the drag
        // could never grow a selection either.
        final terminal = Terminal(maxLines: 20)..resize(20, 5);
        terminal.write('hello world');
        final controller = TerminalController();

        await tester
            .pumpWidget(harness(terminal: terminal, controller: controller));
        await tester.pump();

        final rt = viewKey.currentState!.renderTerminal;
        final gesture = await tester.startGesture(
          globalOf(tester, cellCenter(rt, 15, 0)),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(
          kLongPressTimeout + const Duration(milliseconds: 50),
        );

        // The blank cell carries no text of its own, but it is a real
        // selection, which is what the drag below needs to grow from.
        expect(controller.selection, isNotNull);
        expect(terminal.buffer.getText(controller.selection), isEmpty);

        await gesture.moveTo(globalOf(tester, cellCenter(rt, 2, 0)));
        await tester.pump();

        expect(terminal.buffer.getText(controller.selection), 'hello world');

        await gesture.up();
        controller.dispose();
      },
    );
  });

  group('TerminalGestureHandler drag selection', () {
    testWidgets('drag start/update/end selects the dragged characters', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 20)..resize(20, 5);
      terminal.write('hello world');
      final controller = TerminalController();

      await tester
          .pumpWidget(harness(terminal: terminal, controller: controller));
      await tester.pump();

      final rt = viewKey.currentState!.renderTerminal;
      final start = cellCenter(rt, 0, 0);
      final end = cellCenter(rt, 4, 0);

      final gesture = await tester.startGesture(
        globalOf(tester, start),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(globalOf(tester, end));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.selection, isNotNull);
      expect(terminal.buffer.getText(controller.selection), 'hello');

      controller.dispose();
    });

    testWidgets('alt+drag selects a rectangular block', (tester) async {
      final terminal = Terminal(maxLines: 10)..resize(5, 3);
      terminal.write('abcde\r\nfghij');
      final controller = TerminalController();

      await tester
          .pumpWidget(harness(terminal: terminal, controller: controller));
      await tester.pump();

      final rt = viewKey.currentState!.renderTerminal;
      final start = cellCenter(rt, 1, 0);
      final end = cellCenter(rt, 3, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final gesture = await tester.startGesture(
        globalOf(tester, start),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(globalOf(tester, end));
      await tester.pump();
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(controller.selection, isA<BufferRangeBlock>());
      expect(terminal.buffer.getText(controller.selection), 'bcd\nghi');

      controller.dispose();
    });

    testWidgets(
      'drag is handed to the application (no selection) while it owns '
      'pointer input',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(maxLines: 20, onOutput: output.add)
          ..resize(20, 5);
        terminal.write('hello world');
        terminal.write('\x1b[?1002h\x1b[?1006h');
        final controller = TerminalController();

        await tester
            .pumpWidget(harness(terminal: terminal, controller: controller));
        await tester.pump();

        final rt = viewKey.currentState!.renderTerminal;
        final start = cellCenter(rt, 0, 0);
        final end = cellCenter(rt, 4, 0);

        final gesture = await tester.startGesture(
          globalOf(tester, start),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(globalOf(tester, end));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(controller.selection, isNull);
        expect(output, isNotEmpty);

        controller.dispose();
      },
    );
  });

  group('TerminalGestureHandler mouse-button state tracking', () {
    testWidgets(
      'a chord press (two buttons in one down event) reports both buttons, '
      'and releasing the pointer releases both in the same order',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();

        await tester
            .pumpWidget(harness(terminal: terminal, controller: controller));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 1.5, cellSize.height * 0.5);
        final global = globalOf(tester, local);

        // A single down event that already carries two simultaneous
        // buttons (e.g. a chord click) must report both, left before
        // right, matching the iteration order of the button table.
        final pointer = TestPointer(5, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.down(
            global,
            buttons: kPrimaryMouseButton | kSecondaryMouseButton,
          ),
        );
        await tester.pump();

        expect(output.where((v) => v.endsWith('M')), hasLength(2));
        expect(output[0], startsWith('\x1b[<0;'));
        expect(output[1], startsWith('\x1b[<2;'));

        // A single up event (buttons back to 0) must release exactly the
        // buttons that were pressed, in the same order, and nothing more.
        await tester.sendEventToBinding(pointer.up());
        await tester.pump();

        expect(output.where((v) => v.endsWith('m')), hasLength(2));
        expect(output[2], startsWith('\x1b[<0;'));
        expect(output[3], startsWith('\x1b[<2;'));
        expect(tester.takeException(), isNull);

        controller.dispose();
      },
    );

    testWidgets(
      'cancelling a press that was never reported does not corrupt state '
      'for the next press',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        final controller = TerminalController(
          pointerInputs: const PointerInputs.none(),
        );

        await tester
            .pumpWidget(harness(terminal: terminal, controller: controller));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 1.5, cellSize.height * 0.5);
        final global = globalOf(tester, local);

        final pointer = TestPointer(7, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.down(global, buttons: kPrimaryMouseButton),
        );
        await tester.pump();
        await tester.sendEventToBinding(pointer.cancel());
        await tester.pump();

        expect(output, isEmpty);
        expect(tester.takeException(), isNull);

        // Re-enable pointer input and press again: this must behave like a
        // fresh press, proving the cancelled press left no residue behind.
        controller.setPointerInputs(const PointerInputs.all());
        terminal.write('\x1b[?1000h\x1b[?1006h');
        await tester.sendEventToBinding(
          pointer.down(global, buttons: kPrimaryMouseButton),
        );
        await tester.pump();

        expect(output.where((v) => v.endsWith('M')), hasLength(1));

        await tester.sendEventToBinding(pointer.up());
        await tester.pump();
        expect(output.where((v) => v.endsWith('m')), hasLength(1));

        controller.dispose();
      },
    );

    testWidgets(
      'pointer cancel after a reported press releases the button, without '
      'throwing',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('hello');
        terminal.write('\x1b[?1000h\x1b[?1006h');
        final controller = TerminalController();

        await tester
            .pumpWidget(harness(terminal: terminal, controller: controller));
        await tester.pump();

        final cellSize = viewKey.currentState!.renderTerminal.cellSize;
        final local = Offset(cellSize.width * 1.5, cellSize.height * 0.5);
        final global = globalOf(tester, local);

        final pointer = TestPointer(9, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.down(global, buttons: kPrimaryMouseButton),
        );
        await tester.pump();
        expect(output.where((v) => v.endsWith('M')), hasLength(1));

        await tester.sendEventToBinding(pointer.cancel());
        await tester.pump();

        expect(output.where((v) => v.endsWith('m')), hasLength(1));
        expect(tester.takeException(), isNull);

        controller.dispose();
      },
    );
  });
}
