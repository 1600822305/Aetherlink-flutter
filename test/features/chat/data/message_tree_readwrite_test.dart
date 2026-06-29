import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// PR-3: tree maintenance on writes (ChatRepositoryImpl.saveMessage) and the
/// tree-ordered read (getBranchMessages).
void main() {
  late AppDatabase db;
  late ChatRepositoryImpl repo;
  var clock = DateTime.utc(2024, 3, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
    clock = DateTime.utc(2024, 3, 1);
  });

  tearDown(() async {
    await db.close();
  });

  DateTime tick() => clock = clock.add(const Duration(seconds: 1));

  Message userMsg(String id, String topicId) => Message(
    id: id,
    role: MessageRole.user,
    assistantId: 'asst-1',
    topicId: topicId,
    createdAt: tick(),
    status: MessageStatus.success,
  );

  Message assistantMsg(String id, String topicId, String askId) => Message(
    id: id,
    role: MessageRole.assistant,
    assistantId: 'asst-1',
    topicId: topicId,
    createdAt: tick(),
    status: MessageStatus.success,
    askId: askId,
  );

  Future<void> seedTopic(String id) => repo.saveTopic(
    Topic(
      id: id,
      assistantId: 'asst-1',
      name: id,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    ),
  );

  test('first send on a new topic lazily creates the virtual root', () async {
    await seedTopic('t1');
    await repo.saveMessage(userMsg('u1', 't1'));

    final root = await db.messageDao.getRootByTopicId('t1');
    expect(root, isNotNull);
    expect(root!.role, MessageRole.root);

    final u1 = await repo.getMessage('u1');
    expect(u1!.parentId, root.id); // first turn hangs off the root
    final t1 = await repo.getTopic('t1');
    expect(t1!.activeNodeId, 'u1'); // active leaf advanced to the user message
  });

  test('a user→assistant turn chains the tree and advances activeNodeId', () async {
    await seedTopic('t2');
    await repo.saveMessage(userMsg('u1', 't2'));
    await repo.saveMessage(assistantMsg('a1', 't2', 'u1'));

    final a1 = await repo.getMessage('a1');
    expect(a1!.parentId, 'u1'); // assistant hangs off the user message (askId)
    final t2 = await repo.getTopic('t2');
    expect(t2!.activeNodeId, 'a1'); // leaf is now the assistant reply

    // Second turn chains off the previous assistant.
    await repo.saveMessage(userMsg('u2', 't2'));
    final u2 = await repo.getMessage('u2');
    expect(u2!.parentId, 'a1');
    await repo.saveMessage(assistantMsg('a2', 't2', 'u2'));
    final t2b = await repo.getTopic('t2');
    expect(t2b!.activeNodeId, 'a2');

    // getBranchMessages returns the linear conversation (root excluded).
    final shown = await repo.getBranchMessages('t2');
    expect(shown.map((m) => m.id), ['u1', 'a1', 'u2', 'a2']);
  });

  test('only one virtual root is ever created for a topic', () async {
    await seedTopic('t3');
    await repo.saveMessage(userMsg('u1', 't3'));
    await repo.saveMessage(assistantMsg('a1', 't3', 'u1'));
    await repo.saveMessage(userMsg('u2', 't3'));

    final roots = (await db.messageDao.getAll())
        .where((m) => m.topicId == 't3' && m.role == MessageRole.root)
        .toList();
    expect(roots, hasLength(1));
  });

  test('updates (copyWith) keep their parentId — no re-attach', () async {
    await seedTopic('t4');
    await repo.saveMessage(userMsg('u1', 't4'));
    await repo.saveMessage(assistantMsg('a1', 't4', 'u1'));

    final a1 = await repo.getMessage('a1');
    // Simulate a streaming status update like the controller does.
    await repo.saveMessage(a1!.copyWith(status: MessageStatus.success));
    final reloaded = await repo.getMessage('a1');
    expect(reloaded!.parentId, 'u1'); // unchanged
    final t4 = await repo.getTopic('t4');
    expect(t4!.activeNodeId, 'a1'); // not knocked backwards
  });

  test('getBranchMessages on an empty topic returns empty', () async {
    await seedTopic('t5');
    expect(await repo.getBranchMessages('t5'), isEmpty);
  });
}
