import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';
import 'package:aetherlink_flutter/features/welcome/application/onboarding_controller.dart';
import 'package:aetherlink_flutter/features/welcome/presentation/mobile/welcome_page.dart';

/// In-memory KV store standing in for the Drift-backed settings repository:
/// only the two KV methods the onboarding controller touches are implemented.
class _FakeKvStore implements ChatRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> saveSetting(String key, String value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

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
    // The chat home now binds real read providers; stub them empty so this
    // navigation test stays hermetic (no database access). The onboarding
    // controller hydrates from the KV store, so that seam is faked in memory.
    final store = _FakeKvStore();
    final container = ProviderContainer(
      overrides: [
        currentTopicProvider.overrideWith((ref) => null),
        chatMessagesProvider.overrideWith((ref) => const <Message>[]),
        appSettingsStoreProvider.overrideWithValue(store),
      ],
    );
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

    // Precondition: first-time user lands on the welcome page; the controller
    // hydrates async from the (empty) KV store → still needs onboarding.
    expect(find.text('开始使用'), findsOneWidget);
    final needsOnboarding = await tester.runAsync(
      () => container.read(onboardingControllerProvider.future),
    );
    expect(needsOnboarding, isTrue);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // markStarted() ran: the flag flipped, persisted to the KV store, and we
    // navigated to the chat home.
    expect(container.read(onboardingControllerProvider).value, isFalse);
    expect(store.values[kFirstTimeUserSettingKey], 'false');
    expect(find.byType(ChatPage), findsOneWidget);
  });
}
