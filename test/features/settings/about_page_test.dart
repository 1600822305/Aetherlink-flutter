import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  testWidgets('About page renders the info card and all link rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(defaultThemeSpec),
          home: const AboutPage(),
        ),
      ),
    );

    // Header + info card.
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('AetherLink'), findsOneWidget);
    expect(find.text('一个强大的AI助手应用，支持多种大语言模型，帮助您更高效地完成工作。'), findsOneWidget);
    expect(find.text('v0.6.5'), findsOneWidget);

    // Links card: all four rows in order.
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('官方群组'), findsOneWidget);
    expect(find.text('反馈'), findsOneWidget);
    expect(find.text('开发者工具'), findsOneWidget);
  });

  testWidgets(
    'external link rows are tappable; 开发者工具 (no Flutter page yet) is disabled',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(defaultThemeSpec),
            home: const AboutPage(),
          ),
        ),
      );

      // The three external rows are wired (InkWell), the devtools row is not.
      final githubRow = find.ancestor(
        of: find.text('GitHub'),
        matching: find.byType(InkWell),
      );
      expect(githubRow, findsOneWidget);

      // Exactly one row is disabled — rendered at half opacity (开发者工具).
      final disabled = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 0.5,
      );
      expect(disabled, findsOneWidget);
      expect(
        find.descendant(of: disabled, matching: find.text('开发者工具')),
        findsOneWidget,
      );
    },
  );

  testWidgets('theme -> go_router -> Scaffold pipeline reaches /about', (
    tester,
  ) async {
    final router = AppRouter.create();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        // The chat home now binds real read providers; stub them empty so this
        // routing test stays hermetic (no database access).
        overrides: [
          currentTopicProvider.overrideWith((ref) => null),
          chatMessagesProvider.overrideWith((ref) => const <Message>[]),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          darkTheme: AppTheme.dark(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    // Home route renders the chat home (ChatPage skeleton).
    expect(find.byType(ChatPage), findsOneWidget);

    router.go(AppRouter.aboutPath);
    await tester.pumpAndSettle();

    // The About page is reachable and themed (Scaffold from the route table).
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('AetherLink'), findsOneWidget);
  });
}
