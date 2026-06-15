import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  testWidgets('About page renders app name, version and links', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AboutPage())),
    );

    expect(find.text('AetherLink'), findsOneWidget);
    expect(find.text('v0.6.5'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('反馈'), findsOneWidget);
  });

  testWidgets('theme -> go_router -> Scaffold pipeline reaches /about', (
    tester,
  ) async {
    final router = AppRouter.create();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          darkTheme: AppTheme.dark(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    // Home route renders the kept ChatPage placeholder.
    expect(find.text('Chat'), findsOneWidget);

    router.go(AppRouter.aboutPath);
    await tester.pumpAndSettle();

    // The About page is reachable and themed (Scaffold from the route table).
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('AetherLink'), findsOneWidget);
  });
}
