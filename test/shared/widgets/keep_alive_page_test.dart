import 'package:aetherlink_flutter/shared/widgets/keep_alive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.label, required this.onInit});

  final String label;
  final VoidCallback onInit;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Center(child: Text(widget.label));
}

void main() {
  testWidgets('pages swiped out of the PageView viewport are not rebuilt '
      'from scratch when swiped back', (tester) async {
    var firstInits = 0;
    var secondInits = 0;
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PageView(
          controller: controller,
          children: [
            KeepAlivePage(
              child: _Probe(label: 'first', onInit: () => firstInits++),
            ),
            KeepAlivePage(
              child: _Probe(label: 'second', onInit: () => secondInits++),
            ),
          ],
        ),
      ),
    );
    expect(firstInits, 1);

    controller.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first', skipOffstage: false), findsOneWidget);

    controller.jumpToPage(0);
    await tester.pumpAndSettle();
    controller.jumpToPage(1);
    await tester.pumpAndSettle();

    expect(firstInits, 1);
    expect(secondInits, 1);
  });
}
