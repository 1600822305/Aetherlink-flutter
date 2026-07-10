import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// v8→v9: the single-root partial-unique index + the repair pass that lets it
/// be created safely.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Message root(String id, String topicId) => Message(
    id: id,
    role: MessageRole.root,
    assistantId: 'a',
    topicId: topicId,
    createdAt: DateTime.utc(2024),
    status: MessageStatus.success,
  );

  test('schemaVersion is 16', () => expect(db.schemaVersion, 16));

  test('the single-root partial unique index exists on a fresh DB', () async {
    final rows = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='index' "
          "AND name='message_topic_root_uniq'",
        )
        .get();
    expect(rows, hasLength(1));
  });

  test('a second virtual root for the same topic is rejected', () async {
    await db.messageDao.upsert(root('r1', 't1'));
    expect(
      () => db.messageDao.upsert(root('r2', 't1')),
      throwsA(anything), // UNIQUE constraint on message_topic_root_uniq
    );
  });

  test('different topics may each have their own root', () async {
    await db.messageDao.upsert(root('r1', 't1'));
    await db.messageDao.upsert(root('r2', 't2')); // no throw
    expect(await db.messageDao.getRootByTopicId('t2'), isNotNull);
  });

  test('repair attaches legacy NULL-parent messages and creates a root', () async {
    await db.topicDao.upsert(
      Topic(
        id: 't1',
        assistantId: 'a',
        name: 't1',
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    );
    // Simulate legacy rows: content messages with NULL parentId, no root.
    var clock = DateTime.utc(2024, 1, 1);
    for (final spec in [('u1', MessageRole.user), ('a1', MessageRole.assistant)]) {
      clock = clock.add(const Duration(seconds: 1));
      await db.messageDao.upsert(
        Message(
          id: spec.$1,
          role: spec.$2,
          assistantId: 'a',
          topicId: 't1',
          createdAt: clock,
          status: MessageStatus.success,
          askId: spec.$1 == 'a1' ? 'u1' : null,
        ),
      );
    }

    await repairMessageTree(db);

    final r = await db.messageDao.getRootByTopicId('t1');
    expect(r, isNotNull);
    final u1 = await db.messageDao.getById('u1');
    final a1 = await db.messageDao.getById('a1');
    expect(u1!.parentId, r!.id); // first turn attached to the root
    expect(a1!.parentId, 'u1');

    // No NULL-parent content rows remain (so the index would hold).
    final nulls = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM message_rows "
          "WHERE topic_id=? AND role!='root' AND parent_id IS NULL",
          variables: [Variable.withString('t1')],
        )
        .getSingle();
    expect(nulls.read<int>('c'), 0);
  });
}
