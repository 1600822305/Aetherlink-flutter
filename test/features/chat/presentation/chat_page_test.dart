import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      // sending: the button handles taps but does not send. The send glyph is
      // a lucide icon, so the button is matched by its tooltip.
      await tester.tap(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '发送消息'),
      );
      await tester.pump();
      expect(find.text('请先配置模型'), findsOneWidget);
    },
  );

  testWidgets(
    'Top bar shows the model-selector placeholder, both it and settings now '
    'wired',
    (tester) async {
      await pumpChatPage(tester);

      // The default (icon-style) model selector carries the "未配置模型"
      // placeholder as its tooltip while no model is configured — never a
      // fabricated model name. It is now wired: tapping it opens the picker /
      // model settings, so it is enabled.
      final modelSelector = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '未配置模型'),
      );
      expect(modelSelector.onPressed, isNotNull);

      // Settings action is now wired (the settings hub exists) — it navigates
      // to `/settings`, so it is enabled.
      final settingsButton = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '设置'),
      );
      expect(settingsButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Input button toolbar renders the default buttons; placeholders disabled, '
    'send wired',
    (tester) async {
      await pumpChatPage(tester);

      // The default toolbar layout (InputBoxSettings defaults): left
      // tools/clear/search, right upload/voice/send. The feature buttons are
      // disabled placeholders (later slices). They are matched by tooltip
      // because several glyphs are bespoke SVGs, not Material/lucide icons.
      const placeholderTooltips = <String>[
        '扩展', // tools
        '清空内容', // clear
        '网络搜索', // search
        '添加内容', // upload
        '切换到语音输入模式', // voice
      ];

      for (final tooltip in placeholderTooltips) {
        final finder = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == tooltip,
        );
        expect(
          finder,
          findsOneWidget,
          reason: 'missing toolbar button $tooltip',
        );
        expect(
          tester.widget<IconButton>(finder).onPressed,
          isNull,
          reason: 'toolbar button $tooltip should be disabled',
        );
      }

      // Send is wired: with no model configured it stays greyed but a tap
      // surfaces the "configure a model first" hint, so it handles taps.
      final sendFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == '发送消息',
      );
      expect(sendFinder, findsOneWidget);
      expect(tester.widget<IconButton>(sendFinder).onPressed, isNotNull);
    },
  );

  testWidgets(
    'Opening the drawer reveals the functional sidebar: tabs, 助手 header '
    'actions, and a working search toggle',
    (tester) async {
      await pumpChatPage(tester);

      // The menu button (a non-lucide SVG glyph) opens the drawer; find it by
      // its tooltip rather than an icon.
      await tester.tap(find.byTooltip('打开侧边栏'));
      await tester.pumpAndSettle();

      // Tab shell (助手 / 话题 / 设置).
      expect(find.text('助手'), findsOneWidget);
      expect(find.text('话题'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      // 助手 tab is shown first, wired with its real header + actions.
      expect(find.text('所有助手'), findsOneWidget);
      expect(find.text('创建分组'), findsOneWidget);
      expect(find.text('添加助手'), findsOneWidget);

      // Search is a toggle now: the field is built only after tapping the
      // header search button, and it is enabled (not a disabled shell).
      expect(find.widgetWithText(TextField, '搜索助手...'), findsNothing);
      await tester.tap(find.widgetWithIcon(IconButton, LucideIcons.search));
      await tester.pumpAndSettle();
      final searchField = tester.widget<TextField>(
        find.widgetWithText(TextField, '搜索助手...'),
      );
      expect(searchField.enabled ?? true, isTrue);
    },
  );

  testWidgets(
    'Per-assistant overflow menu opens and lists its actions (regression for '
    'the empty-menu bug where PopupMenuButton.constraints clipped the menu)',
    (tester) async {
      await pumpChatPage(tester);

      await tester.tap(find.byTooltip('打开侧边栏'));
      await tester.pumpAndSettle();

      // Each seeded assistant row carries a ⋮ overflow button. Opening one must
      // actually reveal its menu items: the regressed code passed
      // `constraints` to PopupMenuButton, which sizes the *menu* (not the
      // button) and shrank it to a 16px box that clipped every item away.
      final overflow = find.byIcon(LucideIcons.moreVertical);
      expect(overflow, findsWidgets);
      await tester.tap(overflow.first);
      await tester.pumpAndSettle();

      expect(find.text('添加到分组'), findsOneWidget);
      expect(find.text('复制助手'), findsOneWidget);
      expect(find.text('清空话题'), findsOneWidget);
      expect(find.text('删除助手'), findsOneWidget);
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
