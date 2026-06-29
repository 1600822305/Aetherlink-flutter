import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';

/// PR-1 of the message-tree refactor (docs/design/message-tree-model-design.md):
/// the schema bumps to v7, promoting parentId / role / siblingsGroupId /
/// createdAt to real columns on `message_rows` (alongside the JSON blob). These
/// tests prove a fresh (onCreate) v7 DB has the new columns, that the entity
/// fields round-trip through the blob, and that the promoted columns are
/// actually populated by the DAO write.
void main() {
  final createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Message buildMessage({
    String id = 'msg-tree-1',
    MessageRole role = MessageRole.assistant,
    String? parentId,
    int siblingsGroupId = 0,
  }) => Message(
    id: id,
    role: role,
    assistantId: 'asst-1',
    topicId: 'topic-1',
    createdAt: createdAt,
    status: MessageStatus.success,
    parentId: parentId,
    siblingsGroupId: siblingsGroupId,
  );

  test('schemaVersion is 7', () {
    expect(db.schemaVersion, 7);
  });

  test('parentId / siblingsGroupId round-trip through the entity blob', () async {
    final message = buildMessage(parentId: 'parent-1', siblingsGroupId: 3);
    await db.messageDao.upsert(message);

    final loaded = await db.messageDao.getById('msg-tree-1');
    expect(loaded, message);
    expect(loaded!.parentId, 'parent-1');
    expect(loaded.siblingsGroupId, 3);
  });

  test('defaults: missing parentId is null, siblingsGroupId is 0', () async {
    await db.messageDao.upsert(buildMessage());

    final loaded = await db.messageDao.getById('msg-tree-1');
    expect(loaded!.parentId, isNull);
    expect(loaded.siblingsGroupId, 0);
  });

  test('promoted real columns are populated by the DAO write', () async {
    await db.messageDao.upsert(
      buildMessage(
        role: MessageRole.user,
        parentId: 'parent-9',
        siblingsGroupId: 2,
      ),
    );

    final row = await db
        .customSelect(
          'SELECT parent_id, role, siblings_group_id, created_at '
          'FROM message_rows WHERE id = ?',
          variables: [Variable.withString('msg-tree-1')],
        )
        .getSingle();

    expect(row.read<String?>('parent_id'), 'parent-9');
    expect(row.read<String?>('role'), 'user');
    expect(row.read<int>('siblings_group_id'), 2);
    // dateTime column is non-null when the entity carries a createdAt. Drift
    // stores it as a unix timestamp and reads it back in local time, so compare
    // the instant rather than the (UTC-flagged) DateTime objects directly.
    expect(row.read<DateTime>('created_at').toUtc(), createdAt);
  });

  test('the new MessageRole.root value round-trips', () async {
    final root = buildMessage(id: 'root-1', role: MessageRole.root);
    await db.messageDao.upsert(root);

    final loaded = await db.messageDao.getById('root-1');
    expect(loaded!.role, MessageRole.root);

    final row = await db
        .customSelect(
          'SELECT role FROM message_rows WHERE id = ?',
          variables: [Variable.withString('root-1')],
        )
        .getSingle();
    expect(row.read<String?>('role'), 'root');
  });

  test('the parentId lookup index exists on a fresh v7 DB', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'idx_messages_parent_id'",
        )
        .get();
    expect(rows, hasLength(1));
  });
}
