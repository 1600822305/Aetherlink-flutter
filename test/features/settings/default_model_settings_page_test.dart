import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/default_model_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(defaultThemeSpec),
          home: const DefaultModelSettingsPage(),
        ),
      ),
    );
  }

  testWidgets('renders the header and the 模型服务商 card', (tester) async {
    await pumpPage(tester);

    expect(find.text('模型设置'), findsOneWidget);
    expect(find.text('模型服务商'), findsOneWidget);
    expect(find.text('您可以配置多个模型服务商，点击对应的服务商进行设置和管理'), findsOneWidget);
    // Header actions render with their lucide icons.
    expect(find.text('批量删除'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
  });

  testWidgets('provider list is empty (no fabricated rows)', (tester) async {
    await pumpPage(tester);

    // Only the card's header/divider exist — no provider rows, so nothing is
    // tappable inside the body and no chevron/grip handles are drawn.
    expect(find.byType(InkWell), findsNothing);
    expect(find.byIcon(LucideIcons.gripVertical), findsNothing);
    expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
  });

  testWidgets('the 批量删除 / 添加 actions are disabled placeholders', (
    tester,
  ) async {
    await pumpPage(tester);

    // Both header actions render at half opacity (the app's disabled
    // convention) and carry no tap handler.
    final disabled = tester
        .widgetList<Opacity>(
          find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5),
        )
        .toList();
    expect(disabled, hasLength(2));

    // Neither action has a tappable ancestor (no InkWell / button wiring).
    for (final label in const ['批量删除', '添加']) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        findsNothing,
        reason: '$label should not be tappable',
      );
    }
  });

  testWidgets('back button returns to the settings hub', (tester) async {
    useTallSurface(tester);
    final router = AppRouter.create();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTopicProvider.overrideWith((ref) => null),
          chatMessagesProvider.overrideWith((ref) => const <Message>[]),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    router.go(AppRouter.defaultModelPath);
    await tester.pumpAndSettle();
    expect(find.byType(DefaultModelSettingsPage), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('hub "配置模型" row navigates to this page', (tester) async {
    useTallSurface(tester);
    final router = AppRouter.create();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTopicProvider.overrideWith((ref) => null),
          chatMessagesProvider.overrideWith((ref) => const <Message>[]),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    router.go(AppRouter.settingsPath);
    await tester.pumpAndSettle();

    await tester.tap(find.text('配置模型'));
    await tester.pumpAndSettle();

    expect(find.byType(DefaultModelSettingsPage), findsOneWidget);
    expect(find.text('模型设置'), findsOneWidget);
  });
}
