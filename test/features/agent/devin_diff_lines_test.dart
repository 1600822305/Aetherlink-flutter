import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/presentation/mobile/devin_diff_lines.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';

void main() {
  // 回归：diff 行在 ListView 的无界高度约束里必须能正常布局渲染
  // （曾因 gutter stretch 触发 infinite height 异常导致只显示第一行）。
  testWidgets('DevinDiffLinesLazy 在无界高度列表里渲染全部行', (tester) async {
    final rows = <DiffLine>[
      for (var i = 1; i <= 40; i++)
        DiffLine(DiffLineKind.added, 'final x$i = $i;', newLine: i),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: DevinDiffLinesLazy(rows: rows)),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('final x1 = 1;'), findsOneWidget);
    expect(find.text('final x20 = 20;'), findsOneWidget);
  });

  testWidgets('DevinDiffLines 在可滚动 Column 里渲染全部行', (tester) async {
    final rows = <DiffLine>[
      const DiffLine(DiffLineKind.removed, 'old line', oldLine: 1),
      const DiffLine(DiffLineKind.added, 'new line', newLine: 1),
      const DiffLine(DiffLineKind.skip, ''),
      const DiffLine(DiffLineKind.context, 'ctx', oldLine: 5, newLine: 5),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DevinDiffLines(rows: rows)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('old line'), findsOneWidget);
    expect(find.text('new line'), findsOneWidget);
    expect(find.text('ctx'), findsOneWidget);
  });
}
