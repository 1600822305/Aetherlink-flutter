import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';

void main() {
  // Real pipeline, no mocks: an in-memory Drift database backs the real
  // chatRepositoryProvider / read providers. Empty database → empty list.
  Future<void> pumpChatPage(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
        child: const MaterialApp(home: ChatPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ChatPage shows the empty state from an empty repository, with input '
    'enabled and send disabled',
    (tester) async {
      await pumpChatPage(tester);

      // The shell renders: app bar + composer (the sidebar search field is not
      // built until the drawer opens, so exactly one TextField is on screen).
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Empty database → empty state (text comes from empty data, not a mock).
      expect(find.text('对话开始了，请输入您的问题'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      // The field accepts input (local UI state)...
      await tester.enterText(find.byType(TextField), '你好');
      expect(find.text('你好'), findsOneWidget);

      // ...but sending is disabled this milestone.
      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(sendButton.onPressed, isNull);
    },
  );

  testWidgets(
    'Top bar restores the model-selector placeholder and settings, both '
    'disabled (no model configured, no fabricated name)',
    (tester) async {
      await pumpChatPage(tester);

      // Model selector ("full" style) shows the disabled "未配置模型"
      // placeholder — never a fabricated model name.
      expect(find.text('未配置模型'), findsOneWidget);
      final modelSelector = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('未配置模型'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(modelSelector.onPressed, isNull);

      // Settings action is present but disabled (no settings page yet).
      final settingsButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.settings),
      );
      expect(settingsButton.onPressed, isNull);
    },
  );

  testWidgets(
    'Input button toolbar restores each feature button, all present and '
    'disabled',
    (tester) async {
      await pumpChatPage(tester);

      // The original default button set, restored as disabled placeholders.
      const toolbarIcons = <IconData>[
        Icons.public, // 网络搜索
        Icons.build, // MCP 工具
        Icons.menu_book, // 知识库
        Icons.image, // 图片
        Icons.mic, // 语音
        Icons.swap_horiz, // 多模型
        Icons.send, // 发送
      ];

      for (final icon in toolbarIcons) {
        final finder = find.widgetWithIcon(IconButton, icon);
        expect(finder, findsOneWidget, reason: 'missing toolbar icon $icon');
        expect(
          tester.widget<IconButton>(finder).onPressed,
          isNull,
          reason: 'toolbar icon $icon should be disabled',
        );
      }
    },
  );

  testWidgets(
    'Opening the drawer reveals the sidebar shell: tabs + disabled search',
    (tester) async {
      await pumpChatPage(tester);

      // The menu button is the one wired control — it opens the drawer.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.menu));
      await tester.pumpAndSettle();

      // Tab shell (助手 / 话题 / 设置).
      expect(find.text('助手'), findsOneWidget);
      expect(find.text('话题'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      // Search box restored as a disabled shell.
      final searchField = tester.widget<TextField>(
        find.widgetWithText(TextField, '搜索话题...').first,
      );
      expect(searchField.enabled, isFalse);
    },
  );
}
