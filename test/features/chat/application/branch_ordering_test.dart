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

  // All three messages carry the *same* timestamp, so ordering is decided by
  // the id tiebreak rather than an arbitrary (unstable) sort.
  final tiedTime = DateTime.utc(2024, 1, 1, 12);

  Future<void> seedMessage(String id, String content) async {
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
        blocks: <String>[block.id],
      ),
    );
  }

  Future<String> branchContentOf(String clonedMessageId) async {
    final blocks = await repo.getMessageBlocksByMessageId(clonedMessageId);
    final block = blocks.single;
    return block is MainTextBlock ? block.content : '';
  }

  test('branches at the selected message when timestamps tie', () async {
    await repo.saveTopic(
      Topic(
        id: 'topic-1',
        assistantId: 'asst-1',
        name: 'Source',
        createdAt: tiedTime,
        updatedAt: tiedTime,
      ),
    );
    // Insert out of id order to prove the result doesn't depend on insertion.
    await seedMessage('msg-c', 'C');
    await seedMessage('msg-a', 'A');
    await seedMessage('msg-b', 'B');

    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Fork at the middle message (msg-b): expect [A, B], never [..., C].
    final branch =
        await container.read(topicsProvider.notifier).createBranch('msg-b');
    expect(branch, isNotNull);

    final cloned = await repo.getMessagesByTopicId(branch!.id)
      ..sort((a, b) => a.id.compareTo(b.id));
    final contents = <String>[];
    for (final id in branch.messageIds) {
      contents.add(await branchContentOf(id));
    }

    expect(cloned.length, 2);
    expect(contents, ['A', 'B']);
  });
}
