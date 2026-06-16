import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/models/application/model_providers.dart';
import 'package:aetherlink_flutter/features/models/data/repositories/model_repository_impl.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/add_provider_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/advanced_api_config_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/edit_model_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/model_provider_detail_page.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

void main() {
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Pumps the full app router and navigates to [location] (so `context.pop` /
  /// `context.push` and the path parameters resolve like in production). The
  /// model store is backed by a real in-memory Drift repository (no mocks),
  /// optionally seeded with [providers] so the detail / edit / advanced pages
  /// have a provider to render.
  Future<ModelRepositoryImpl> pumpAt(
    WidgetTester tester,
    String location, {
    List<ModelProvider> providers = const <ModelProvider>[],
  }) async {
    useTallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ModelRepositoryImpl(db);
    for (final provider in providers) {
      await repo.saveProvider(provider);
    }

    final router = AppRouter.create();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTopicProvider.overrideWith((ref) => null),
          chatMessagesProvider.overrideWith((ref) => const <Message>[]),
          modelRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    router.go(location);
    await tester.pumpAndSettle();
    return repo;
  }

  ModelProvider providerP1({List<Model> models = const <Model>[]}) =>
      ModelProvider(
        id: 'p1',
        name: '测试供应商',
        avatar: 'T',
        color: '#10a37f',
        isEnabled: true,
        providerType: 'openai',
        models: models,
      );

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

      // 下一步 is disabled until a name + type are entered — tapping is a no-op.
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
      await pumpAt(
        tester,
        AppRouter.modelProviderPath('p1'),
        providers: [providerP1()],
      );

      expect(find.byType(ModelProviderDetailPage), findsOneWidget);
      expect(find.text('模型供应商'), findsOneWidget);
      expect(find.text('API配置'), findsOneWidget);
      expect(find.text('API密钥'), findsOneWidget);
      expect(find.text('基础URL (可选)'), findsOneWidget);
      expect(find.text('配置高级参数'), findsOneWidget);
      expect(find.text('模型列表'), findsOneWidget);
      expect(find.text('尚未添加任何模型'), findsOneWidget);

      // Data fields are now editable (wired to the repository).
      final apiKeyField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(apiKeyField.enabled, isTrue);
    });

    testWidgets('renders the provider models and the current-model marker', (
      tester,
    ) async {
      await pumpAt(
        tester,
        AppRouter.modelProviderPath('p1'),
        providers: [
          providerP1(
            models: const [
              Model(
                id: 'gpt-4o',
                name: 'GPT-4o',
                provider: '测试供应商',
                isDefault: true,
              ),
              Model(id: 'gpt-4o-mini', name: 'GPT-4o mini', provider: '测试供应商'),
            ],
          ),
        ],
      );

      expect(find.text('尚未添加任何模型'), findsNothing);
      expect(find.text('GPT-4o'), findsOneWidget);
      expect(find.text('GPT-4o mini'), findsOneWidget);
    });

    testWidgets('配置高级参数 navigates to the advanced-config page', (tester) async {
      await pumpAt(
        tester,
        AppRouter.modelProviderPath('p1'),
        providers: [providerP1()],
      );

      await tester.tap(find.text('配置高级参数'));
      await tester.pumpAndSettle();

      expect(find.byType(AdvancedApiConfigPage), findsOneWidget);
      expect(find.text('高级 API 配置'), findsOneWidget);
    });

    testWidgets('saving the API key persists it through the repository', (
      tester,
    ) async {
      final repo = await pumpAt(
        tester,
        AppRouter.modelProviderPath('p1'),
        providers: [providerP1()],
      );

      await tester.enterText(find.byType(TextField).first, 'sk-secret');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final saved = await repo.getProvider('p1');
      expect(saved?.apiKey, 'sk-secret');
    });
  });

  group('EditModelPage', () {
    testWidgets('renders the form with the save button disabled until filled', (
      tester,
    ) async {
      await pumpAt(
        tester,
        AppRouter.editModelPath('p1'),
        providers: [providerP1()],
      );

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

      // 保存 is disabled until the name + model id are filled.
      final save = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(save.onPressed, isNull);
    });

    testWidgets('filling the form writes the model back to the provider', (
      tester,
    ) async {
      final repo = await pumpAt(
        tester,
        AppRouter.editModelPath('p1'),
        providers: [providerP1()],
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'GPT-4o');
      await tester.enterText(fields.at(1), 'gpt-4o');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final saved = await repo.getProvider('p1');
      expect(saved?.models.map((m) => m.id), contains('gpt-4o'));
      expect(saved?.models.single.name, 'GPT-4o');
    });
  });

  group('AdvancedApiConfigPage', () {
    testWidgets('renders the Headers tab with its empty state', (tester) async {
      await pumpAt(
        tester,
        AppRouter.advancedApiPath('p1'),
        providers: [providerP1()],
      );

      expect(find.byType(AdvancedApiConfigPage), findsOneWidget);
      expect(find.text('高级 API 配置'), findsOneWidget);
      expect(find.text('请求头 (Headers)'), findsOneWidget);
      expect(find.text('请求体 (Body)'), findsOneWidget);
      expect(find.text('快速操作'), findsOneWidget);
      expect(find.text('已配置 0 个请求头'), findsOneWidget);
      expect(find.text('提交'), findsOneWidget);
    });

    testWidgets('switching to the Body tab shows the body empty state', (
      tester,
    ) async {
      await pumpAt(
        tester,
        AppRouter.advancedApiPath('p1'),
        providers: [providerP1()],
      );

      await tester.tap(find.text('请求体 (Body)'));
      await tester.pumpAndSettle();

      expect(find.text('已配置 0 个请求体参数'), findsOneWidget);
      expect(find.text('暂无自定义请求体参数，点击下方添加按钮添加参数'), findsOneWidget);
    });
  });
}
