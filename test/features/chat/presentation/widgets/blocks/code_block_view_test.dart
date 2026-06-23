import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block_view.dart';

void main() {
  const sampleCode = 'final answer = 42;\nprint(answer);';

  Future<void> pumpCodeBlock(
    WidgetTester tester, {
    SidebarSettings settings = const SidebarSettings(),
    String code = sampleCode,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sidebarSettingsControllerProvider.overrideWithValue(settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: CodeBlockView(language: 'dart', code: code),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder codeText() =>
      find.textContaining('final answer = 42;', findRichText: true);

  testWidgets(
    'renders language label, line numbers and copy action by default',
    (tester) async {
      await pumpCodeBlock(tester);

      expect(find.text('<DART>'), findsOneWidget);
      expect(find.text('1\n2'), findsOneWidget);
      expect(codeText(), findsOneWidget);
      expect(find.byTooltip('复制代码'), findsOneWidget);
    },
  );

  testWidgets('renders syntax-highlighted selectable spans', (tester) async {
    await pumpCodeBlock(tester);

    final selectable = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .firstWhere((w) => w.textSpan != null);
    final spans = <TextSpan>[];
    void collect(InlineSpan span) {
      if (span is! TextSpan) return;
      spans.add(span);
      final children = span.children;
      if (children == null) return;
      for (final child in children) {
        collect(child);
      }
    }

    collect(selectable.textSpan!);

    expect(spans.any((s) => s.text == 'final'), isTrue);
    expect(spans.any((s) => s.text != null && s.style?.color != null), isTrue);
  });

  testWidgets('honors hidden line numbers and non-copyable settings', (
    tester,
  ) async {
    await pumpCodeBlock(
      tester,
      settings: const SidebarSettings(
        copyableCodeBlocks: false,
        codeShowLineNumbers: false,
      ),
    );

    expect(find.text('1\n2'), findsNothing);
    expect(codeText(), findsOneWidget);
    expect(find.byTooltip('复制代码'), findsNothing);
  });

  testWidgets('uses horizontal scrolling when wrapping is disabled', (
    tester,
  ) async {
    await pumpCodeBlock(
      tester,
      settings: const SidebarSettings(codeWrappable: false),
      code: 'final veryLongIdentifierName = "${List.filled(120, "x").join()}";',
    );

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });

  testWidgets('default-collapsed blocks expand from the header', (
    tester,
  ) async {
    await pumpCodeBlock(
      tester,
      settings: const SidebarSettings(codeDefaultCollapsed: true),
    );

    expect(find.byTooltip('展开代码块'), findsOneWidget);
    expect(codeText(), findsNothing);

    await tester.tap(find.byTooltip('展开代码块'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('折叠代码块'), findsOneWidget);
    expect(codeText(), findsOneWidget);
  });

  testWidgets(
    'non-collapsible blocks stay expanded even with default collapsed',
    (tester) async {
      await pumpCodeBlock(
        tester,
        settings: const SidebarSettings(
          codeCollapsible: false,
          codeDefaultCollapsed: true,
        ),
      );

      expect(find.byTooltip('展开代码块'), findsNothing);
      expect(find.byTooltip('折叠代码块'), findsNothing);
      expect(codeText(), findsOneWidget);
    },
  );
}
