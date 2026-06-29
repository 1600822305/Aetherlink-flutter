import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Integration tests for [backfillMessageTree] (PR-2). Seeds flat messages into
/// an in-memory DB, runs the backfill, and asserts the resulting tree shape +
/// that the display path (getByTopicId) is unchanged (root excluded).
void main() {
  late AppDatabase db;
  var clock = DateTime.utc(2024, 1, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime.utc(2024, 1, 1);
  });

  tearDown(() async {
    await db.close();
  });

  Message msg(
    String id,
    String topicId, {
    MessageRole role = MessageRole.assistant,
    String? askId,
    bool? foldSelected,
  }) {
    clock = clock.add(const Duration(seconds: 1));
    return Message(
      id: id,
      role: role,
      assistantId: 'asst-1',
      topicId: topicId,
      createdAt: clock,
      status: MessageStatus.success,
      askId: askId,
      foldSelected: foldSelected,
    );
  }

  Topic topic(String id) => Topic(
    id: id,
    assistantId: 'asst-1',
    name: 'T $id',
    createdAt: DateTime.utc(2023, 12, 31),
    updatedAt: DateTime.utc(2023, 12, 31),
  );

  Future<int> rootCount(String topicId) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM message_rows "
          "WHERE topic_id = ? AND role = 'root'",
          variables: [Variable.withString(topicId)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  test('linear topic: builds a root, links parents, sets activeNodeId', () async {
    await db.topicDao.upsert(topic('t1'));
    final flat = [
      msg('u1', 't1', role: MessageRole.user),
      msg('a1', 't1'),
      msg('u2', 't1', role: MessageRole.user),
      msg('a2', 't1'),
    ];
    for (final m in flat) {
      await db.messageDao.upsert(m);
    }

    await backfillMessageTree(db);

    // Exactly one virtual root.
    expect(await rootCount('t1'), 1);
    final root = await db.messageDao.getRootByTopicId('t1');
    expect(root, isNotNull);
    expect(root!.role, MessageRole.root);

    // Display path unchanged: root excluded, same 4 content messages in order.
    final shown = await db.messageDao.getByTopicId('t1');
    expect(shown.map((m) => m.id), ['u1', 'a1', 'u2', 'a2']);

    // First turn hangs off the root; the rest chain linearly.
    final byId = {for (final m in shown) m.id: m};
    expect(byId['u1']!.parentId, root.id);
    expect(byId['a1']!.parentId, 'u1');
    expect(byId['u2']!.parentId, 'a1');
    expect(byId['a2']!.parentId, 'u2');

    // activeNodeId points at the last message.
    final t1 = await db.topicDao.getById('t1');
    expect(t1!.activeNodeId, 'a2');
  });

  test('multi-model topic: sibling group + activeNodeId = foldSelected', () async {
    await db.topicDao.upsert(topic('t2'));
    for (final m in [
      msg('u1', 't2', role: MessageRole.user),
      msg('a1', 't2', askId: 'u1'),
      msg('a2', 't2', askId: 'u1', foldSelected: true),
      msg('a3', 't2', askId: 'u1'),
    ]) {
      await db.messageDao.upsert(m);
    }

    await backfillMessageTree(db);

    final shown = await db.messageDao.getByTopicId('t2');
    final byId = {for (final m in shown) m.id: m};
    final root = await db.messageDao.getRootByTopicId('t2');

    expect(byId['u1']!.parentId, root!.id);
    // a1/a2/a3 are one sibling group under u1.
    expect(byId['a1']!.parentId, 'u1');
    expect(byId['a2']!.parentId, 'u1');
    expect(byId['a3']!.parentId, 'u1');
    expect(byId['a1']!.siblingsGroupId, greaterThan(0));
    expect(byId['a1']!.siblingsGroupId, byId['a2']!.siblingsGroupId);
    expect(byId['a2']!.siblingsGroupId, byId['a3']!.siblingsGroupId);

    final t2 = await db.topicDao.getById('t2');
    expect(t2!.activeNodeId, 'a2'); // the foldSelected reply
  });

  test('empty topic: gets a root, activeNodeId stays null', () async {
    await db.topicDao.upsert(topic('t3'));

    await backfillMessageTree(db);

    expect(await rootCount('t3'), 1);
    expect((await db.messageDao.getByTopicId('t3')), isEmpty);
    final t3 = await db.topicDao.getById('t3');
    expect(t3!.activeNodeId, isNull);
  });

  test('is idempotent: a second run does not create a second root', () async {
    await db.topicDao.upsert(topic('t4'));
    await db.messageDao.upsert(msg('u1', 't4', role: MessageRole.user));

    await backfillMessageTree(db);
    await backfillMessageTree(db);

    expect(await rootCount('t4'), 1);
    // Still resolvable as a single root (would throw if duplicated).
    expect(await db.messageDao.getRootByTopicId('t4'), isNotNull);
  });
}
