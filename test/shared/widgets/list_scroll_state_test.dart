import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/widgets/deferred_content.dart';
import 'package:aetherlink_flutter/shared/widgets/list_scroll_state.dart';

void main() {
  final scheduler = DeferredContentScheduler.instance;
  final monitor = PerfMonitor.instance;

  tearDown(resetHostScrolling);

  Widget host({required Widget child}) => MaterialApp(
        home: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            reportHostScrolling(n);
            return false;
          },
          child: child,
        ),
      );

  testWidgets('nested horizontal scroll does not flip the list state',
      (tester) async {
    final inner = ScrollController();
    addTearDown(inner.dispose);
    await tester.pumpWidget(host(
      child: ListView(
        children: [
          SizedBox(
            height: 100,
            child: ListView(
              controller: inner,
              scrollDirection: Axis.horizontal,
              children: const [SizedBox(width: 2000)],
            ),
          ),
          const SizedBox(height: 2000),
        ],
      ),
    ));

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    expect(scheduler.isScrolling, isTrue);
    expect(monitor.context.scrolling, isTrue);

    inner.jumpTo(300);
    await tester.pump();
    expect(scheduler.isScrolling, isTrue);
    expect(monitor.context.scrolling, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scheduler.isScrolling, isFalse);
    expect(monitor.context.scrolling, isFalse);
  });

  test('resetHostScrolling clears a scroll that never ended', () {
    scheduler.setScrolling(true);
    monitor.setScrolling(true);
    resetHostScrolling();
    expect(scheduler.isScrolling, isFalse);
    expect(monitor.context.scrolling, isFalse);
  });
}
