import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';

void main() {
  testWidgets(
    'ChatPage skeleton shows the empty state from an empty repository, with '
    'input enabled and send disabled',
    (tester) async {
      // Real pipeline, no mocks: an in-memory Drift database backs the real
      // chatRepositoryProvider / read providers. Empty database → empty list.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWith((ref) => db)],
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pumpAndSettle();

      // The shell renders: app bar + composer.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Empty database → empty state (text comes from empty data, not a mock).
      expect(find.text('对话开始了，请输入您的问题'), findsOneWidget);

      // No topic yet → the dynamic title is empty.
      expect(find.byType(ListView), findsNothing);

      // The field accepts input (local UI state)...
      await tester.enterText(find.byType(TextField), '你好');
      expect(find.text('你好'), findsOneWidget);

      // ...but sending is disabled this milestone (M4.2.2).
      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(sendButton.onPressed, isNull);
    },
  );
}
