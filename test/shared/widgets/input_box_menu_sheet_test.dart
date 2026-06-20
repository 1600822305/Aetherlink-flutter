import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_actions.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(InputBoxMenu menu) => MaterialApp(
  home: Scaffold(
    body: InputBoxMenuSheet(menu: menu, actions: const NoInputBoxActions()),
  ),
);

void main() {
  group('添加内容 (upload) menu', () {
    testWidgets('renders the three core upload items in a single Row, not as '
        'list tiles', (tester) async {
      await tester.pumpWidget(_host(InputBoxMenu.upload));

      // The three core cells use short labels and are not ListTiles.
      for (final label in const ['相册', '拍照', '文件']) {
        expect(find.text(label), findsOneWidget);
        expect(find.widgetWithText(ListTile, label), findsNothing);
      }

      // All three share one Row.
      final row = find.ancestor(
        of: find.text('相册'),
        matching: find.byType(Row),
      );
      expect(row, findsWidgets);
      final rowFinder = row.first;
      expect(
        find.descendant(of: rowFinder, matching: find.text('拍照')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rowFinder, matching: find.text('文件')),
        findsOneWidget,
      );
    });

    testWidgets('optional items below the divider stay as list rows', (
      tester,
    ) async {
      await tester.pumpWidget(_host(InputBoxMenu.upload));

      expect(find.widgetWithText(ListTile, '添加笔记'), findsOneWidget);
    });

    testWidgets('tapping a core item pops the chosen action', (tester) async {
      late InputBoxAction? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<InputBoxAction>(
                    context: context,
                    builder: (_) => const InputBoxMenuSheet(
                      menu: InputBoxMenu.upload,
                      actions: NoInputBoxActions(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();

      expect(result, InputBoxAction.camera);
    });
  });

  group('扩展 (tools) menu', () {
    testWidgets('keeps the list layout (no core row)', (tester) async {
      await tester.pumpWidget(_host(InputBoxMenu.tools));

      // No core short labels exist in the tools menu.
      expect(find.text('相册'), findsNothing);
      // Tools items remain ListTiles.
      expect(find.byType(ListTile), findsWidgets);
    });
  });
}
