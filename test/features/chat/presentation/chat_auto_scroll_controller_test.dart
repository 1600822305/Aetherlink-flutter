import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/presentation/controllers/chat_auto_scroll_controller.dart';

/// Reverse (bottom-anchored) message list harness: `messages` is newest-first
/// (list index 0 = visual bottom), rows keyed by message like the real list.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.controller,
    required this.messages,
    this.newestHeight = 100,
  });

  final ChatAutoFollowScrollController controller;
  final List<String> messages;

  /// Height of the newest row (list index 0) — grown to simulate streaming.
  final double newestHeight;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          reverse: true,
          controller: widget.controller,
          itemCount: widget.messages.length,
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey(widget.messages[index]),
            height: index == 0 ? widget.newestHeight : 100,
            child: Text(widget.messages[index]),
          ),
        ),
      ),
    );
  }
}

void main() {
  late ChatAutoFollowScrollController scroll;
  late ChatAutoScrollController auto;
  bool enabled = true;

  setUp(() {
    enabled = true;
    scroll = ChatAutoFollowScrollController();
    auto = ChatAutoScrollController(
      scrollController: scroll,
      isEnabled: () => enabled,
    );
  });

  tearDown(() {
    auto.dispose();
    scroll.dispose();
  });

  List<String> makeMessages(int n) =>
      [for (var i = n - 1; i >= 0; i--) 'msg $i'];

  testWidgets('starts stuck at the bottom (scroll offset origin)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(controller: scroll, messages: makeMessages(30)),
    );
    expect(auto.isSticking, isTrue);
    expect(scroll.position.pixels, scroll.position.minScrollExtent);
    // Newest message visible at the bottom.
    expect(find.text('msg 29'), findsOneWidget);
  });

  testWidgets('new message while stuck keeps the list at the bottom', (
    tester,
  ) async {
    final messages = makeMessages(30);
    await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
    messages.insert(0, 'msg 30');
    await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
    expect(scroll.position.pixels, scroll.position.minScrollExtent);
    expect(find.text('msg 30'), findsOneWidget);
    expect(auto.isSticking, isTrue);
  });

  testWidgets('user scrolling away from the bottom unsticks', (tester) async {
    await tester.pumpWidget(
      _Harness(controller: scroll, messages: makeMessages(30)),
    );
    // In a reverse list, dragging down reveals older content above
    // (pixels increase).
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(auto.isSticking, isFalse);
    expect(scroll.position.pixels, greaterThan(auto.threshold));
  });

  testWidgets('streaming growth while scrolled up does not move the viewport', (
    tester,
  ) async {
    final messages = makeMessages(30);
    await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    final anchor = tester.getTopLeft(find.text('msg 25'));

    // The newest row (scroll-start side, below the viewport) grows: visible
    // rows keep their cached layout offsets, so the reading position holds.
    await tester.pumpWidget(
      _Harness(controller: scroll, messages: messages, newestHeight: 250),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.text('msg 25')), anchor);
    expect(auto.isSticking, isFalse);
  });

  testWidgets('append + pinToBottom returns to the bottom from history', (
    tester,
  ) async {
    // Mirrors the host's didUpdateWidget policy: any append (the user
    // sending / a response row created) explicitly pins to the bottom.
    final messages = makeMessages(30);
    await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(auto.isSticking, isFalse);

    messages.insert(0, 'msg 30');
    auto.pinToBottom();
    await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, scroll.position.minScrollExtent);
    expect(find.text('msg 30'), findsOneWidget);
    expect(auto.isSticking, isTrue);
  });

  testWidgets('dragging back to the bottom re-sticks', (tester) async {
    await tester.pumpWidget(
      _Harness(controller: scroll, messages: makeMessages(30)),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(auto.isSticking, isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(auto.isSticking, isTrue);
    expect(scroll.position.pixels, scroll.position.minScrollExtent);
  });

  testWidgets('pinToBottom jumps back and re-sticks from anywhere', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(controller: scroll, messages: makeMessages(30)),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(auto.isSticking, isFalse);

    auto.pinToBottom();
    await tester.pumpAndSettle();
    expect(auto.isSticking, isTrue);
    expect(scroll.position.pixels, scroll.position.minScrollExtent);
  });

  testWidgets(
    'auto-follow disabled: new message while stuck still follows via stick',
    (tester) async {
      // isSticking is the single source of truth; the reverse orientation
      // keeps pixels at the origin structurally, so even with the setting
      // off the list stays at the bottom when it was already there.
      enabled = false;
      final messages = makeMessages(30);
      await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
      messages.insert(0, 'msg 30');
      await tester.pumpWidget(_Harness(controller: scroll, messages: messages));
      expect(scroll.position.pixels, scroll.position.minScrollExtent);
      expect(find.text('msg 30'), findsOneWidget);
    },
  );

  testWidgets('unstick() detaches so programmatic jumps are not overridden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(controller: scroll, messages: makeMessages(30)),
    );
    auto.unstick();
    scroll.jumpTo(500);
    await tester.pumpAndSettle();
    expect(auto.isSticking, isFalse);
    expect(scroll.position.pixels, 500);
  });
}
