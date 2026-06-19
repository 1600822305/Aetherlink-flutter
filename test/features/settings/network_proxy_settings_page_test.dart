import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/settings/application/network_proxy_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/network_proxy_settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  Future<ChatRepositoryImpl> pumpWithRepo(
    WidgetTester tester, {
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ChatRepositoryImpl(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          currentTopicProvider.overrideWith((ref) => null),
          chatMessagesProvider.overrideWith((ref) => const <Message>[]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(defaultThemeSpec),
          home: home ?? const NetworkProxySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('renders proxy form fields and default bypass rules', (
    tester,
  ) async {
    await pumpWithRepo(tester);

    expect(find.text('网络代理'), findsOneWidget);
    expect(find.text('代理设置'), findsOneWidget);
    expect(find.text('启用网络代理'), findsOneWidget);
    expect(find.text('代理类型'), findsOneWidget);
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('端口'), findsOneWidget);
    expect(find.text('绕过规则'), findsOneWidget);
    expect(find.text('连接测试'), findsOneWidget);
    expect(find.textContaining('localhost'), findsWidgets);
  });

  testWidgets('edits are persisted through the settings controller', (
    tester,
  ) async {
    final repo = await pumpWithRepo(tester);

    await tester.tap(find.byType(CustomSwitch));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '127.0.0.1');
    await tester.enterText(find.byType(TextField).at(1), '7890');
    await tester.enterText(find.byType(TextField).at(2), 'alice');
    await tester.pump();

    final stored = await repo.getSetting(kNetworkProxySettingsKey);
    expect(stored, isNotNull);
    final json = jsonDecode(stored!) as Map<String, dynamic>;
    expect(json['enabled'], isTrue);
    expect(json['host'], '127.0.0.1');
    expect(json['port'], '7890');
    expect(json['username'], 'alice');
  });

  testWidgets('hub network proxy row navigates to the proxy page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ChatRepositoryImpl(db);
    final router = AppRouter.create();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
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
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.text('网络代理'));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkProxySettingsPage), findsOneWidget);
    expect(find.text('代理设置'), findsOneWidget);
  });
}
