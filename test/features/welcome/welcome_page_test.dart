import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';
import 'package:aetherlink_flutter/features/welcome/application/onboarding_controller.dart';
import 'package:aetherlink_flutter/features/welcome/presentation/mobile/welcome_page.dart';

void main() {
  testWidgets('Welcome page renders title, subtitle and start button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomePage())),
    );

    expect(find.text('AetherLink'), findsOneWidget);
    expect(find.text('开始您的 AI 对话之旅'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
  });

  testWidgets('tapping start marks onboarding done and navigates to chat home', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = AppRouter.create(startAtWelcome: true);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          darkTheme: AppTheme.dark(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    // Precondition: first-time user lands on the welcome page, onboarding pending.
    expect(find.text('开始使用'), findsOneWidget);
    expect(container.read(onboardingControllerProvider), isTrue);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // markStarted() ran (in-memory seam flipped) and we navigated to the chat home.
    expect(container.read(onboardingControllerProvider), isFalse);
    expect(find.text('Chat'), findsOneWidget);
  });
}
