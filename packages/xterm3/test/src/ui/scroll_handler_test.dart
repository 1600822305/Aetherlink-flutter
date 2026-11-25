import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/infinite_scroll_view.dart';
import 'package:xterm3/src/ui/scroll_handler.dart';
import 'package:xterm3/xterm.dart';

/// These tests target [TerminalScrollGestureHandler] directly: unlike
/// [TerminalGestureHandler], its constructor takes only plain values and
/// callbacks (no [TerminalViewState] dependency), so it can be pumped
/// stand-alone with stub `sendMouseEvent`/`getScrollPosition` functions.
const _childKey = ValueKey('scroll-handler-test-child');

void main() {
  Widget harness({
    required Terminal terminal,
    required TerminalController controller,
    required TerminalMouseEventCallback sendMouseEvent,
    ScrollPosition? Function()? getScrollPosition,
    double lineHeight = 20,
    double cellWidth = 10,
    bool simulateScroll = true,
    bool readOnly = false,
    Widget? child,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TerminalScrollGestureHandler(
          terminal: terminal,
          terminalController: controller,
          sendMouseEvent: sendMouseEvent,
          getScrollPosition: getScrollPosition ?? () => null,
          getLineHeight: () => lineHeight,
          getCellWidth: () => cellWidth,
          simulateScroll: simulateScroll,
          readOnly: readOnly,
          child: child ??
              const ColoredBox(
                key: _childKey,
                color: Color(0xff222222),
                child: SizedBox(width: 200, height: 200),
              ),
        ),
      ),
    );
  }

  bool neverHandles(
    TerminalMouseButton button,
    TerminalMouseButtonState state,
    Offset offset, {
    required TerminalMouseModifiers modifiers,
  }) =>
      false;

  group('TerminalScrollGestureHandler wrapping', () {
    testWidgets(
      'does not intercept scrolling when the terminal is on the main '
      'buffer with no scroll-reporting mouse mode',
      (tester) async {
        final terminal = Terminal();
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          sendMouseEvent: neverHandles,
        ));

        expect(find.byType(InfiniteScrollView), findsNothing);

        controller.dispose();
      },
    );

    testWidgets(
      'intercepts scrolling once a scroll-reporting mouse mode is enabled',
      (tester) async {
        final terminal = Terminal()..write('\x1b[?1000h');
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          sendMouseEvent: neverHandles,
        ));

        expect(find.byType(InfiniteScrollView), findsOneWidget);

        controller.dispose();
      },
    );

    testWidgets(
      'intercepts scrolling on the alt-screen buffer even without a '
      'scroll-reporting mouse mode',
      (tester) async {
        final terminal = Terminal()..write('\x1b[?1049h');
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          sendMouseEvent: neverHandles,
        ));

        expect(find.byType(InfiniteScrollView), findsOneWidget);

        controller.dispose();
      },
    );

    testWidgets(
      'reacts to the terminal mode changing after the widget is built',
      (tester) async {
        final terminal = Terminal();
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          sendMouseEvent: neverHandles,
        ));
        expect(find.byType(InfiniteScrollView), findsNothing);

        terminal.write('\x1b[?1000h');
        await tester.pump();
        expect(find.byType(InfiniteScrollView), findsOneWidget);

        terminal.write('\x1b[?1000l');
        await tester.pump();
        expect(find.byType(InfiniteScrollView), findsNothing);

        controller.dispose();
      },
    );
  });

  group('TerminalScrollGestureHandler vertical scroll reporting', () {
    testWidgets(
      'reports one wheel event per full line, accumulating fractional '
      'deltas, and picks direction from the sign of the scroll',
      (tester) async {
        final calls = <(TerminalMouseButton, TerminalMouseButtonState)>[];
        final terminal = Terminal()..write('\x1b[?1000h');
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          lineHeight: 20,
          sendMouseEvent: (button, state, offset, {required modifiers}) {
            calls.add((button, state));
            return true;
          },
        ));

        final position = tester.getCenter(find.byKey(_childKey));

        // Two partial deltas below the line-height threshold...
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 12),
          ),
        );
        await tester.pump();
        expect(calls, isEmpty);

        // ...crossing it on the second one reports exactly one wheel-down.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 12),
          ),
        );
        await tester.pump();
        expect(calls, hasLength(1));
        expect(calls.single.$1, TerminalMouseButton.wheelDown);
        expect(calls.single.$2, TerminalMouseButtonState.down);

        // Scrolling back up by a full line reports wheel-up.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, -20),
          ),
        );
        await tester.pump();
        expect(calls, hasLength(2));
        expect(calls.last.$1, TerminalMouseButton.wheelUp);

        controller.dispose();
      },
    );

    testWidgets(
      'falls back to scrolling the main buffer when the application does '
      'not handle the wheel event',
      (tester) async {
        final terminal = Terminal()..write('\x1b[?1000h');
        final controller = TerminalController();
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: const SizedBox(height: 2000),
                    ),
                  ),
                  Expanded(
                    child: harness(
                      terminal: terminal,
                      controller: controller,
                      sendMouseEvent: neverHandles,
                      getScrollPosition: () => scrollController.position,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final position = tester.getCenter(find.byKey(_childKey));
        final before = scrollController.offset;

        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 20),
          ),
        );
        await tester.pump();

        expect(scrollController.offset, greaterThan(before));

        controller.dispose();
      },
    );

    testWidgets(
      'readOnly bypasses the application entirely and still scrolls the '
      'main buffer',
      (tester) async {
        final terminal = Terminal()..write('\x1b[?1000h');
        final controller = TerminalController();
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        var callCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: const SizedBox(height: 2000),
                    ),
                  ),
                  Expanded(
                    child: harness(
                      terminal: terminal,
                      controller: controller,
                      readOnly: true,
                      getScrollPosition: () => scrollController.position,
                      sendMouseEvent: (
                        button,
                        state,
                        offset, {
                        required modifiers,
                      }) {
                        callCount++;
                        return true;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final position = tester.getCenter(find.byKey(_childKey));
        final before = scrollController.offset;

        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 20),
          ),
        );
        await tester.pump();

        expect(callCount, 0);
        expect(scrollController.offset, greaterThan(before));

        controller.dispose();
      },
    );

    testWidgets(
      'on the alt-screen buffer, an unhandled wheel event simulates arrow '
      'keys only when simulateScroll is enabled',
      (tester) async {
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add)..write('\x1b[?1049h');
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          simulateScroll: false,
          sendMouseEvent: neverHandles,
        ));

        final position = tester.getCenter(find.byKey(_childKey));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 20),
          ),
        );
        await tester.pump();
        expect(output, isEmpty);

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          sendMouseEvent: neverHandles,
        ));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 20),
          ),
        );
        await tester.pump();
        expect(output, isNotEmpty);

        controller.dispose();
      },
    );
  });

  group('TerminalScrollGestureHandler horizontal scroll reporting', () {
    testWidgets(
      'reports one wheel event per full cell width, direction matching '
      'the sign of the horizontal delta',
      (tester) async {
        final calls = <TerminalMouseButton>[];
        final terminal = Terminal()..write('\x1b[?1000h');
        final controller = TerminalController();

        await tester.pumpWidget(harness(
          terminal: terminal,
          controller: controller,
          cellWidth: 10,
          sendMouseEvent: (button, state, offset, {required modifiers}) {
            calls.add(button);
            return true;
          },
        ));

        final position = tester.getCenter(find.byKey(_childKey));

        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(25, 0),
          ),
        );
        await tester.pump();

        expect(calls, [
          TerminalMouseButton.wheelRight,
          TerminalMouseButton.wheelRight,
        ]);

        calls.clear();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(-15, 0),
          ),
        );
        await tester.pump();

        expect(calls, [TerminalMouseButton.wheelLeft]);

        controller.dispose();
      },
    );
  });
}
