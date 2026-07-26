import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';

/// replaceMessageBlocks：单事务内删旧块 + 写新块 + 更新 message，替换后
/// 数据库里恰好是新块集合，消息的 blocks 引用同步更新。
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

  MessageBlock text(String id, String messageId, String content) =>
      MessageBlock.mainText(
        id: id,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: DateTime.utc(2024, 3, 1),
        content: content,
      );

  test('replaces old blocks with new set and updates the message', () async {
    final message = Message(
      id: 'm1',
      role: MessageRole.assistant,
      assistantId: 'asst-1',
      topicId: 't1',
      parentId: 'root',
      createdAt: DateTime.utc(2024, 3, 1),
      status: MessageStatus.processing,
      blocks: const ['b1'],
    );
    await repo.saveMessage(message);
    await repo.saveMessageBlock(text('b1', 'm1', 'placeholder'));

    final newBlocks = [text('b2', 'm1', 'hello'), text('b3', 'm1', 'world')];
    await repo.replaceMessageBlocks(
      messageId: 'm1',
      blocks: newBlocks,
      message: message.copyWith(
        status: MessageStatus.success,
        blocks: ['b2', 'b3'],
      ),
    );

    expect(await repo.getMessageBlock('b1'), isNull);
    final stored = await repo.getMessageBlocksByMessageId('m1');
    expect(stored.map((b) => b.id).toSet(), {'b2', 'b3'});
    final saved = await repo.getMessage('m1');
    expect(saved!.status, MessageStatus.success);
    expect(saved.blocks, ['b2', 'b3']);
  });

  test(
    'upsertMessageBlocksAndSync never deletes blocks it was not given',
    () async {
      final message = Message(
        id: 'm1',
        role: MessageRole.assistant,
        assistantId: 'asst-1',
        topicId: 't1',
        parentId: 'root',
        createdAt: DateTime.utc(2024, 3, 1),
        status: MessageStatus.processing,
        blocks: const ['b1'],
      );
      await repo.saveMessage(message);
      await repo.saveMessageBlock(text('b1', 'm1', 'first half'));

      // A checkpoint that only reports the tail block must leave the earlier
      // content intact — this is what keeps a caller that under-reports its
      // block set (e.g. 继续生成 omitting the already-generated blocks) from
      // destroying data.
      await repo.upsertMessageBlocksAndSync(
        messageId: 'm1',
        blocks: [text('b2', 'm1', 'continuation')],
        message: message.copyWith(blocks: ['b1', 'b2']),
      );

      final stored = await repo.getMessageBlocksByMessageId('m1');
      expect(stored.map((b) => b.id).toSet(), {'b1', 'b2'});
      expect((await repo.getMessage('m1'))!.blocks, ['b1', 'b2']);
    },
  );

  test('pruneMessageBlocks drops only unreferenced blocks', () async {
    final message = Message(
      id: 'm1',
      role: MessageRole.assistant,
      assistantId: 'asst-1',
      topicId: 't1',
      parentId: 'root',
      createdAt: DateTime.utc(2024, 3, 1),
      status: MessageStatus.success,
      blocks: const ['b1', 'b2'],
    );
    await repo.saveMessage(message);
    await repo.saveMessageBlocks([
      text('b1', 'm1', 'kept'),
      text('b2', 'm1', 'kept too'),
      // Left over from an attempt that failed over and was retried.
      text('b3', 'm1', 'abandoned'),
    ]);

    await repo.pruneMessageBlocks(messageId: 'm1', keepIds: {'b1', 'b2'});

    final stored = await repo.getMessageBlocksByMessageId('m1');
    expect(stored.map((b) => b.id).toSet(), {'b1', 'b2'});
  });
}
