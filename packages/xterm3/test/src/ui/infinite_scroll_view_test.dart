import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/infinite_scroll_view.dart';

void main() {
  testWidgets('keeps reporting after Flutter replaces the scroll position', (
    tester,
  ) async {
    final offsets = <double>[];
    late StateSetter updatePhysics;
    var useBouncingPhysics = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updatePhysics = setState;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ScrollConfiguration(
              behavior: _TestScrollBehavior(
                switch (useBouncingPhysics) {
                  true => const BouncingScrollPhysics(),
                  false => const ClampingScrollPhysics(),
                },
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: InfiniteScrollView(
                  onScroll: offsets.add,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      ),
    );

    final firstPosition =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    updatePhysics(() => useBouncingPhysics = true);
    await tester.pump();
    final secondPosition =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;

    expect(secondPosition, isNot(same(firstPosition)));

    secondPosition.jumpTo(24);
    await tester.pump();

    expect(offsets, contains(24));
  });
}

class _TestScrollBehavior extends ScrollBehavior {
  const _TestScrollBehavior(this.physics);

  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;

  @override
  bool shouldNotify(covariant _TestScrollBehavior oldDelegate) {
    return physics.runtimeType != oldDelegate.physics.runtimeType;
  }
}
