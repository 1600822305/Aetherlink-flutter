import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  setUp(() {
    // The About page reads its version from package_info_plus at runtime
    // (single source of truth: pubspec.yaml's `version`).
    PackageInfo.setMockInitialValues(
      appName: 'AetherLink',
      packageName: 'com.example.aetherlink_flutter',
      version: '0.7.0',
      buildNumber: '70',
      buildSignature: '',
    );
  });

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

    await tester.pumpAndSettle();

    // Header + info card.
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('AetherLink'), findsOneWidget);
    expect(find.text('一个强大的AI助手应用，支持多种大语言模型，帮助您更高效地完成工作。'), findsOneWidget);
    expect(find.text('v0.7.0'), findsOneWidget);

    // Links card: all four rows in order.
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('官方群组'), findsOneWidget);
    expect(find.text('反馈'), findsOneWidget);
    expect(find.text('开发者工具'), findsOneWidget);
  });

  testWidgets(
    'all link rows are tappable — 开发者工具 now targets the in-app /devtools page',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(defaultThemeSpec),
            home: const AboutPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The three external rows and the in-app devtools row are all wired.
      for (final label in const ['GitHub', '官方群组', '反馈', '开发者工具']) {
        expect(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          findsOneWidget,
          reason: '$label should be tappable',
        );
      }

      // No row renders disabled (half opacity) anymore.
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5),
        findsNothing,
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
