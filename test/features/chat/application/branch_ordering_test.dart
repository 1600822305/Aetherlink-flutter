import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Regression test for 创建分支 cutting at the wrong message when a topic's
/// messages share a `createdAt` (common in long / imported histories). The fork
/// must include exactly the selected message and everything before it, in the
/// same deterministic order the chat view uses.
void main() {
  late AppDatabase db;
  late ChatRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  // All messages carry the *same* timestamp, so the fork must follow the tree
  // (parentId chain) rather than any (unstable) chronological/id sort.
  final tiedTime = DateTime.utc(2024, 1, 1, 12);

  Future<void> seedMessage(String id, String content, String parentId) async {
    final block = MessageBlock.mainText(
      id: 'blk-$id',
      messageId: id,
      status: MessageBlockStatus.success,
      createdAt: tiedTime,
      content: content,
    );
    await repo.saveMessageBlock(block);
    await repo.saveMessage(
      Message(
        id: id,
        role: MessageRole.user,
        assistantId: 'asst-1',
        topicId: 'topic-1',
        createdAt: tiedTime,
        status: MessageStatus.success,
        parentId: parentId,
        blocks: <String>[block.id],
      ),
    );
  }

  Future<String> branchContentOf(String clonedMessageId) async {
    final blocks = await repo.getMessageBlocksByMessageId(clonedMessageId);
    final block = blocks.single;
    return block is MainTextBlock ? block.content : '';
  }

  test('forks the tree path to the node when timestamps tie', () async {
    await repo.saveTopic(
      Topic(
        id: 'topic-1',
        assistantId: 'asst-1',
        name: 'Source',
        createdAt: tiedTime,
        updatedAt: tiedTime,
      ),
    );
    await repo.saveMessage(
      Message(
        id: 'root',
        role: MessageRole.root,
        assistantId: 'asst-1',
        topicId: 'topic-1',
        createdAt: tiedTime,
        status: MessageStatus.success,
      ),
    );
    // Explicit chain root → A → B → C, inserted out of id order to prove the
    // result follows the tree (parentId) and not insertion / id order.
    await seedMessage('msg-c', 'C', 'msg-b');
    await seedMessage('msg-a', 'A', 'root');
    await seedMessage('msg-b', 'B', 'msg-a');

    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Fork at the middle node (msg-b): clone its ancestors + itself = [A, B];
    // the descendant C is off-path and excluded.
    final branch =
        await container.read(topicsProvider.notifier).createBranch('msg-b');
    expect(branch, isNotNull);

    final cloned = await repo.getMessagesByTopicId(branch!.id);
    final contents = <String>[];
    for (final id in branch.messageIds) {
      contents.add(await branchContentOf(id));
    }

    expect(cloned.length, 2);
    expect(contents, ['A', 'B']);
  });
}
