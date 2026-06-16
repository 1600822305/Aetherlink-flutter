import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

void main() {
  // Real pipeline, no mocks: an in-memory Drift database backs the real
  // chatRepositoryProvider / read providers. Empty database → empty list.
  //
  // The debug seed is overridden to a no-op here: `kDebugMode` is true under
  // `flutter test`, so the real seed would otherwise populate a conversation
  // and break the empty-state assertions. Tests that want data seed it
  // explicitly through the real repository (see the bubble test below).
  Future<void> pumpChatPage(
    WidgetTester tester, {
    AppDatabase? database,
  }) async {
    final db = database ?? AppDatabase(NativeDatabase.memory());
    if (database == null) {
      addTearDown(db.close);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          debugChatSeedProvider.overrideWith((ref) async {}),
          // No model configured: avoids opening the models DB (which needs a
          // platform path) and exercises the composer's disabled-send path.
          appCurrentModelProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: ChatPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ChatPage shows the empty state from an empty repository, with input '
    'enabled and send not yet sendable (no model)',
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

      // ...but with no model configured a tap surfaces the hint instead of
      // sending: the button handles taps but does not send.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
      await tester.pump();
      expect(find.text('请先配置模型'), findsOneWidget);
    },
  );

  testWidgets(
    'Top bar shows the model-selector placeholder, both it and settings now '
    'wired',
    (tester) async {
      await pumpChatPage(tester);

      // Model selector ("full" style) shows the "未配置模型" placeholder while no
      // model is configured — never a fabricated model name. It is now wired:
      // tapping it opens the model-settings page, so it is enabled.
      expect(find.text('未配置模型'), findsOneWidget);
      final modelSelector = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('未配置模型'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(modelSelector.onPressed, isNotNull);

      // Settings action is now wired (the settings hub exists) — it navigates
      // to `/settings`, so it is enabled.
      final settingsButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.settings),
      );
      expect(settingsButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Input button toolbar restores each feature button; placeholders disabled, '
    'send wired',
    (tester) async {
      await pumpChatPage(tester);

      // The feature buttons remain disabled placeholders (later slices).
      const placeholderIcons = <IconData>[
        Icons.public, // 网络搜索
        Icons.build, // MCP 工具
        Icons.menu_book, // 知识库
        Icons.image, // 图片
        Icons.mic, // 语音
        Icons.swap_horiz, // 多模型
      ];

      for (final icon in placeholderIcons) {
        final finder = find.widgetWithIcon(IconButton, icon);
        expect(finder, findsOneWidget, reason: 'missing toolbar icon $icon');
        expect(
          tester.widget<IconButton>(finder).onPressed,
          isNull,
          reason: 'toolbar icon $icon should be disabled',
        );
      }

      // Send is wired: with no model configured it stays greyed but a tap
      // surfaces the "configure a model first" hint, so it handles taps.
      final sendFinder = find.widgetWithIcon(IconButton, Icons.send);
      expect(sendFinder, findsOneWidget);
      expect(tester.widget<IconButton>(sendFinder).onPressed, isNotNull);
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

  testWidgets(
    'Stored main_text blocks render as bubbles, split left/right by role',
    (tester) async {
      // Seed through the REAL repository on the same in-memory database the
      // page reads from — no widget-level fake bubbles. The blocks flow back
      // out via getMessageBlocksByMessageId like any real conversation.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ChatRepositoryImpl(db);

      final now = DateTime.now();
      const topicId = 'topic-1';
      const userMessageId = 'msg-user';
      const assistantMessageId = 'msg-assistant';
      const userBlockId = 'block-user';
      const assistantBlockId = 'block-assistant';

      await repo.saveTopic(
        Topic(
          id: topicId,
          assistantId: 'assistant-1',
          name: '测试话题',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.saveMessage(
        Message(
          id: userMessageId,
          role: MessageRole.user,
          assistantId: 'assistant-1',
          topicId: topicId,
          createdAt: now,
          status: MessageStatus.success,
          blocks: const <String>[userBlockId],
        ),
      );
      await repo.saveMessageBlock(
        MessageBlock.mainText(
          id: userBlockId,
          messageId: userMessageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          content: '用户消息内容',
        ),
      );
      await repo.saveMessage(
        Message(
          id: assistantMessageId,
          role: MessageRole.assistant,
          assistantId: 'assistant-1',
          topicId: topicId,
          createdAt: now.add(const Duration(seconds: 1)),
          status: MessageStatus.success,
          blocks: const <String>[assistantBlockId],
        ),
      );
      await repo.saveMessageBlock(
        MessageBlock.mainText(
          id: assistantBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: now.add(const Duration(seconds: 1)),
          content: '助手回复内容',
        ),
      );

      await pumpChatPage(tester, database: db);

      // Both main_text blocks are painted as bubbles (no empty state, a list).
      expect(find.text('对话开始了，请输入您的问题'), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('用户消息内容'), findsOneWidget);
      expect(find.text('助手回复内容'), findsOneWidget);

      // Role split: the user bubble hugs the right, the assistant the left.
      final userAligns = tester.widgetList<Align>(
        find.ancestor(of: find.text('用户消息内容'), matching: find.byType(Align)),
      );
      expect(
        userAligns.any((a) => a.alignment == Alignment.centerRight),
        isTrue,
        reason: 'user bubble should be right-aligned',
      );
      final assistantAligns = tester.widgetList<Align>(
        find.ancestor(of: find.text('助手回复内容'), matching: find.byType(Align)),
      );
      expect(
        assistantAligns.any((a) => a.alignment == Alignment.centerLeft),
        isTrue,
        reason: 'assistant bubble should be left-aligned',
      );
      expect(
        tester.getCenter(find.text('用户消息内容')).dx,
        greaterThan(tester.getCenter(find.text('助手回复内容')).dx),
      );
    },
  );
}
