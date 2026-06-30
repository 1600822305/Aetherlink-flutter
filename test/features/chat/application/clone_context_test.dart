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

/// Regression: 「另存为新话题」(createBranch) must clone the full conversation
/// path even when message timestamps tie. Clones write all rows at the same
/// instant, so cloning an imported topic or a clone-of-a-clone used to drop /
/// reorder messages (上下文丢失) because the prefix was a chronological slice.
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

  Future<Topic> seedTopic({required bool tied}) async {
    final t = DateTime.utc(2024, 1, 1, 12);
    await repo.saveTopic(
      Topic(
        id: 'src',
        assistantId: 'asst-1',
        name: 'Source',
        createdAt: t,
        updatedAt: t,
      ),
    );
    await repo.saveMessage(
      Message(
        id: 'root',
        role: MessageRole.root,
        assistantId: 'asst-1',
        topicId: 'src',
        createdAt: t,
        status: MessageStatus.success,
      ),
    );

    var seq = 0;
    Future<void> add(String id, MessageRole role, String parent, String text,
        {String? askId}) async {
      final ts = tied ? t : t.add(Duration(microseconds: seq++));
      final blk = MessageBlock.mainText(
        id: 'blk-$id',
        messageId: id,
        status: MessageBlockStatus.success,
        createdAt: ts,
        content: text,
      );
      await repo.saveMessageBlock(blk);
      await repo.saveMessage(
        Message(
          id: id,
          role: role,
          assistantId: 'asst-1',
          topicId: 'src',
          createdAt: ts,
          status: MessageStatus.success,
          parentId: parent,
          askId: askId,
          blocks: <String>[blk.id],
        ),
      );
    }

    await add('u1', MessageRole.user, 'root', 'hello');
    await add('a1', MessageRole.assistant, 'u1', 'hi there', askId: 'u1');
    await add('u2', MessageRole.user, 'a1', 'how are you');
    await add('a2', MessageRole.assistant, 'u2', 'fine', askId: 'u2');
    await repo.setActiveNode('src', 'a2');
    return (await repo.getTopic('src'))!;
  }

  Future<List<String>> projectedTexts(String topicId) async {
    final projected = await repo.getBranchMessages(topicId);
    final out = <String>[];
    for (final m in projected.where((m) => m.role != MessageRole.root)) {
      final blocks = await repo.getMessageBlocksByMessageId(m.id);
      out.add(blocks.first is MainTextBlock
          ? (blocks.first as MainTextBlock).content
          : '');
    }
    return out;
  }

  for (final tied in [false, true]) {
    test('clone keeps full context (tied timestamps = $tied)', () async {
      await seedTopic(tied: tied);
      final container = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final branch =
          await container.read(topicsProvider.notifier).createBranch('a2');
      expect(branch, isNotNull);

      // Whole path cloned, in order, with text intact — even when ts tie.
      expect(
        await projectedTexts(branch!.id),
        ['hello', 'hi there', 'how are you', 'fine'],
      );

      // The cloned rows themselves carry distinct, increasing timestamps so a
      // re-clone of this branch can never hit the tie hazard again.
      final cloned = await repo.getMessagesByTopicId(branch.id)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (var i = 1; i < cloned.length; i++) {
        expect(cloned[i].createdAt.isAfter(cloned[i - 1].createdAt), isTrue);
      }
    });
  }

  test('clone keeps full context for a flat legacy topic (旧版 web 迁移)',
      () async {
    // Simulate a topic imported from old AetherLink web: messages are flat
    // (no parentId, no virtual root), written in bulk. After 克隆补建虚拟 root,
    // such rows used to all dangle off the new root → the active path collapsed
    // to a single message (上下文丢失). The clone must re-chain them.
    final t = DateTime.utc(2024, 1, 1, 12);
    await repo.saveTopic(
      Topic(
        id: 'src',
        assistantId: 'asst-1',
        name: 'Legacy',
        createdAt: t,
        updatedAt: t,
      ),
    );
    final flat = <Message>[];
    final flatBlocks = <MessageBlock>[];
    var seq = 0;
    void addFlat(String id, MessageRole role, String text) {
      final ts = t.add(Duration(seconds: seq++));
      flatBlocks.add(MessageBlock.mainText(
        id: 'blk-$id',
        messageId: id,
        status: MessageBlockStatus.success,
        createdAt: ts,
        content: text,
      ));
      flat.add(Message(
        id: id,
        role: role,
        assistantId: 'asst-1',
        topicId: 'src',
        createdAt: ts,
        status: MessageStatus.success,
        // No parentId — the hallmark of legacy flat data.
        blocks: <String>['blk-$id'],
      ));
    }

    addFlat('m1', MessageRole.user, 'hello');
    addFlat('m2', MessageRole.assistant, 'hi there');
    addFlat('m3', MessageRole.user, 'how are you');
    addFlat('m4', MessageRole.assistant, 'fine');
    await repo.saveMessageBlocks(flatBlocks);
    await repo.saveMessages(flat); // bulk write, keeps rows flat

    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final branch =
        await container.read(topicsProvider.notifier).createBranch('m4');
    expect(branch, isNotNull);

    // Full conversation cloned in displayed order — not collapsed to one row.
    expect(
      await projectedTexts(branch!.id),
      ['hello', 'hi there', 'how are you', 'fine'],
    );

    // And the clone is now a connected chain (root → m1 → … → m4), not flat:
    // every cloned row except the first points at another cloned row.
    final cloned = await repo.getMessagesByTopicId(branch.id);
    final clonedIds = cloned.map((m) => m.id).toSet();
    final rooted = cloned.where((m) => !clonedIds.contains(m.parentId)).toList();
    expect(rooted.length, 1); // exactly one row hangs off the virtual root
  });
}
