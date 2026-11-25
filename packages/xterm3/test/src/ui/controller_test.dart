import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  group('TerminalController', () {
    test('dispose releases selection anchors', () {
      final terminal = Terminal();
      final controller = TerminalController();
      final base = terminal.buffer.createAnchor(0, 0);
      final extent = terminal.buffer.createAnchor(2, 2);
      controller.setSelection(base, extent);

      controller.dispose();

      expect(base.attached, isFalse);
      expect(extent.attached, isFalse);
    });

    test('selection is limited to its buffer', () {
      final terminal = Terminal();
      final controller = TerminalController();
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 0),
      );

      expect(controller.selectionFor(terminal.buffer), isNotNull);

      terminal.write('\x1b[?1049h');

      expect(controller.selectionFor(terminal.buffer), isNull);

      terminal.write('\x1b[?1049l');

      expect(controller.selectionFor(terminal.buffer), isNotNull);
    });

    testWidgets('setSelectionRange works', (tester) async {
      final terminal = Terminal();
      final terminalView = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: terminalView,
          ),
        ),
      ));

      terminalView.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 2),
      );

      await tester.pump();

      expect(terminalView.selection, isNotNull);
    });

    testWidgets('setSelectionMode changes BufferRange type', (tester) async {
      final terminal = Terminal();
      final terminalView = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: terminalView,
          ),
        ),
      ));

      terminalView.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 2),
      );

      expect(terminalView.selection, isA<BufferRangeLine>());

      terminalView.setSelectionMode(SelectionMode.block);

      expect(terminalView.selection, isA<BufferRangeBlock>());
    });

    testWidgets('clearSelection works', (tester) async {
      final terminal = Terminal();
      final terminalView = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: terminalView,
          ),
        ),
      ));

      terminalView.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 2),
      );

      expect(terminalView.selection, isNotNull);

      terminalView.clearSelection();

      expect(terminalView.selection, isNull);
    });
  });

  group('TerminalController.highlight', () {
    test('dispose releases highlight anchors', () {
      final terminal = Terminal();
      final controller = TerminalController();
      final start = terminal.buffer.createAnchor(5, 5);
      final end = terminal.buffer.createAnchor(5, 10);
      controller.highlight(
        p1: start,
        p2: end,
        color: Colors.yellow,
      );

      controller.dispose();

      expect(start.attached, isFalse);
      expect(end.attached, isFalse);
      expect(controller.highlights, isEmpty);
    });

    test('highlight dispose releases owned anchors', () {
      final terminal = Terminal();
      final controller = TerminalController();
      final start = terminal.buffer.createAnchor(5, 5);
      final end = terminal.buffer.createAnchor(5, 10);
      final highlight = controller.highlight(
        p1: start,
        p2: end,
        color: Colors.yellow,
      );

      highlight.dispose();

      expect(start.attached, isFalse);
      expect(end.attached, isFalse);
    });

    test('works', () {
      final terminal = Terminal();
      final controller = TerminalController();

      final highlight = controller.highlight(
        p1: terminal.buffer.createAnchor(5, 5),
        p2: terminal.buffer.createAnchor(5, 10),
        color: Colors.yellow,
      );
      assert(controller.highlights.length == 1);

      highlight.dispose();
      assert(controller.highlights.isEmpty);
    });

    test('highlight and underline are limited to their buffer', () {
      final terminal = Terminal();
      final controller = TerminalController();
      final highlight = controller.highlight(
        p1: terminal.buffer.createAnchor(0, 0),
        p2: terminal.buffer.createAnchor(2, 0),
        color: Colors.yellow,
      );
      final underline = controller.underline(
        p1: terminal.buffer.createAnchor(0, 0),
        p2: terminal.buffer.createAnchor(2, 0),
        color: Colors.blue,
      );

      expect(highlight.rangeFor(terminal.buffer), isNotNull);
      expect(underline.rangeFor(terminal.buffer), isNotNull);

      terminal.write('\x1b[?1049h');

      expect(highlight.rangeFor(terminal.buffer), isNull);
      expect(underline.rangeFor(terminal.buffer), isNull);
    });
  });

  group('TerminalController search highlights', () {
    test('replaces highlights in one bounded set', () {
      final terminal = Terminal()..resize(20, 3);
      final controller = TerminalController();

      controller.setSearchHighlights(
        terminal.buffer,
        [
          BufferRangeLine(
            const CellOffset(0, 0),
            const CellOffset(4, 0),
          ),
          BufferRangeLine(
            const CellOffset(2, 1),
            const CellOffset(6, 1),
          ),
        ],
        currentIndex: 1,
      );

      expect(controller.searchHighlights, hasLength(2));
      expect(controller.currentSearchHighlight, 1);
      expect(
        controller.searchHighlights.first.rangeFor(terminal.buffer),
        BufferRangeLine(
          const CellOffset(0, 0),
          const CellOffset(4, 0),
        ),
      );
    });

    test('updates current match without replacing anchors', () {
      final terminal = Terminal()..resize(20, 3);
      final controller = TerminalController();
      controller.setSearchHighlights(
        terminal.buffer,
        [
          BufferRangeLine(
            const CellOffset(0, 0),
            const CellOffset(4, 0),
          ),
          BufferRangeLine(
            const CellOffset(2, 1),
            const CellOffset(6, 1),
          ),
        ],
      );
      final firstAnchor = controller.searchHighlights.first.p1;

      controller.setCurrentSearchHighlight(1);

      expect(controller.currentSearchHighlight, 1);
      expect(controller.searchHighlights.first.p1, same(firstAnchor));
    });

    test('clear and dispose release search anchors', () {
      final terminal = Terminal()..resize(20, 3);
      final controller = TerminalController();
      controller.setSearchHighlights(
        terminal.buffer,
        [
          BufferRangeLine(
            const CellOffset(0, 0),
            const CellOffset(4, 0),
          ),
        ],
      );
      final firstAnchor = controller.searchHighlights.first.p1;
      final secondAnchor = controller.searchHighlights.first.p2;

      controller.clearSearchHighlights();

      expect(firstAnchor.attached, isFalse);
      expect(secondAnchor.attached, isFalse);
      expect(controller.searchHighlights, isEmpty);
      expect(controller.currentSearchHighlight, -1);

      controller.setSearchHighlights(
        terminal.buffer,
        [
          BufferRangeLine(
            const CellOffset(0, 1),
            const CellOffset(4, 1),
          ),
        ],
      );
      final disposeAnchor = controller.searchHighlights.first.p1;

      controller.dispose();

      expect(disposeAnchor.attached, isFalse);
      expect(controller.searchHighlights, isEmpty);
    });

    test('search highlights are isolated to their buffer', () {
      final terminal = Terminal()..resize(20, 3);
      final controller = TerminalController();
      controller.setSearchHighlights(
        terminal.buffer,
        [
          BufferRangeLine(
            const CellOffset(0, 0),
            const CellOffset(4, 0),
          ),
        ],
      );

      terminal.write('\x1b[?1049h');

      expect(
        controller.searchHighlights.first.rangeFor(terminal.buffer),
        isNull,
      );
    });
  });
}
