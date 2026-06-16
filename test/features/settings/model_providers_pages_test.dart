import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/add_provider_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/advanced_api_config_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/edit_model_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/model_provider_detail_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Pumps the full app router and navigates to [location] (so `context.pop` /
  /// `context.push` and the path parameters resolve like in production).
  Future<void> pumpAt(WidgetTester tester, String location) async {
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

    router.go(location);
    await tester.pumpAndSettle();
  }

  group('AddProviderPage', () {
    testWidgets('renders the form and a disabled 下一步', (tester) async {
      await pumpAt(tester, AppRouter.addProviderPath);

      expect(find.byType(AddProviderPage), findsOneWidget);
      expect(find.text('添加提供商'), findsOneWidget);
      expect(find.text('提供商信息'), findsOneWidget);
      expect(find.text('提供商名称'), findsOneWidget);
      expect(find.text('提供商类型'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('下一步'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

      // 下一步 creates a provider (no data layer) — tapping it is a no-op.
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.byType(AddProviderPage), findsOneWidget);
    });

    testWidgets('typing the name drives the live preview', (tester) async {
      await pumpAt(tester, AppRouter.addProviderPath);

      expect(find.text('新提供商'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'My OpenAI');
      await tester.pump();

      expect(find.text('My OpenAI'), findsWidgets);
      expect(find.text('新提供商'), findsNothing);
    });
  });

  group('ModelProviderDetailPage', () {
    testWidgets('renders the API-config card and empty model list', (
      tester,
    ) async {
      await pumpAt(tester, AppRouter.modelProviderPath('p1'));

      expect(find.byType(ModelProviderDetailPage), findsOneWidget);
      expect(find.text('模型供应商'), findsOneWidget);
      expect(find.text('API配置'), findsOneWidget);
      expect(find.text('API密钥'), findsOneWidget);
      expect(find.text('基础URL (可选)'), findsOneWidget);
      expect(find.text('Responses API'), findsOneWidget);
      expect(find.text('配置高级参数'), findsOneWidget);
      expect(find.text('模型列表'), findsOneWidget);
      expect(find.text('尚未添加任何模型'), findsOneWidget);
      expect(find.text('获取'), findsOneWidget);

      // Data fields render disabled (greyed).
      final apiKeyField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(apiKeyField.enabled, isFalse);
    });

    testWidgets('配置高级参数 navigates to the advanced-config page', (tester) async {
      await pumpAt(tester, AppRouter.modelProviderPath('p1'));

      await tester.tap(find.text('配置高级参数'));
      await tester.pumpAndSettle();

      expect(find.byType(AdvancedApiConfigPage), findsOneWidget);
      expect(find.text('高级 API 配置'), findsOneWidget);
    });
  });

  group('EditModelPage', () {
    testWidgets('renders the form with disabled controls', (tester) async {
      await pumpAt(tester, AppRouter.editModelPath('p1'));

      expect(find.byType(EditModelPage), findsOneWidget);
      expect(find.text('编辑模型'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('模型头像'), findsOneWidget);
      expect(find.text('模型名称'), findsOneWidget);
      expect(find.text('提供商'), findsOneWidget);
      expect(find.text('模型ID'), findsOneWidget);
      expect(find.text('模型类型'), findsOneWidget);
      expect(find.text('自动检测'), findsOneWidget);
      // A capability chip from the 基础功能 group renders.
      expect(find.text('聊天'), findsOneWidget);

      // 保存 persists the model (no data layer) — it is disabled.
      final save = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(save.onPressed, isNull);
    });
  });

  group('AdvancedApiConfigPage', () {
    testWidgets('renders the Headers tab with its empty state', (tester) async {
      await pumpAt(tester, AppRouter.advancedApiPath('p1'));

      expect(find.byType(AdvancedApiConfigPage), findsOneWidget);
      expect(find.text('高级 API 配置'), findsOneWidget);
      expect(find.text('请求头 (Headers)'), findsOneWidget);
      expect(find.text('请求体 (Body)'), findsOneWidget);
      expect(find.text('快速操作'), findsOneWidget);
      expect(find.text('已配置 0 个请求头'), findsOneWidget);
      expect(find.text('提交'), findsOneWidget);
    });

    testWidgets('switching to the Body tab is pure UI', (tester) async {
      await pumpAt(tester, AppRouter.advancedApiPath('p1'));

      await tester.tap(find.text('请求体 (Body)'));
      await tester.pumpAndSettle();

      expect(find.text('已配置 0 个请求体参数'), findsOneWidget);
      expect(find.text('暂无自定义请求体参数，点击下方添加按钮添加参数'), findsOneWidget);
    });
  });
}
