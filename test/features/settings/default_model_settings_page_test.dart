import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/default_model_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/add_provider_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    useTallSurface(tester);
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

    // 模型服务商 card.
    expect(find.text('模型服务商'), findsOneWidget);
    expect(find.text('您可以配置多个模型服务商，点击对应的服务商进行设置和管理'), findsOneWidget);

    // 推荐操作 card: subheader + the three rows.
    expect(find.text('推荐操作'), findsOneWidget);
    expect(find.text('辅助模型设置'), findsOneWidget);
    expect(find.text('模型选择器样式'), findsOneWidget);
    expect(find.text('添加模型服务商'), findsOneWidget);

    // Header actions render with their lucide icons.
    expect(find.text('批量删除'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
    expect(find.byIcon(LucideIcons.bot), findsOneWidget);
    expect(find.byIcon(LucideIcons.list), findsOneWidget);
    // plus is used twice: the toolbar 添加 action + the 添加模型服务商 row.
    expect(find.byIcon(LucideIcons.plus), findsNWidgets(2));
    // The 辅助模型设置 and 添加模型服务商 rows each end with a chevron; the
    // 模型选择器样式 (toggle) row has none.
    expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(2));
  });

  testWidgets('provider list is empty (no fabricated rows)', (tester) async {
    await pumpPage(tester);

    // No provider rows are fabricated: no drag handles are drawn.
    expect(find.byIcon(LucideIcons.gripVertical), findsNothing);
  });

  testWidgets('the add-provider entries carry tap handlers', (tester) async {
    await pumpPage(tester);

    // Still-unwired rows render at full visual fidelity but carry no handler
    // this milestone (their destinations / toggles don't exist yet).
    for (final label in const ['辅助模型设置', '模型选择器样式']) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        findsNothing,
        reason: '$label should not be tappable',
      );
    }

    // The wired entries are ink-tappable: 批量删除 enters the batch-delete flow,
    // and both 添加 (toolbar) and 添加模型服务商 navigate to AddProviderPage.
    for (final label in const ['批量删除', '添加', '添加模型服务商']) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        findsOneWidget,
        reason: '$label should be tappable',
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

  testWidgets('添加模型服务商 row navigates to AddProviderPage', (tester) async {
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

    await tester.tap(find.text('添加模型服务商'));
    await tester.pumpAndSettle();

    expect(find.byType(AddProviderPage), findsOneWidget);
    expect(find.text('添加提供商'), findsOneWidget);
  });
}
