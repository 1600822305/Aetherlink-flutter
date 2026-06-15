import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_metadata.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_file_reference.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/custom_parameter.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);

  late AppDatabase db;
  late ChatRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  // A message that exercises several block types + nested value objects, so the
  // round-trip proves the JSON blob keeps every field (no silent loss).
  List<MessageBlock> blocksFor(String messageId) => [
    MessageBlock.mainText(
      id: 'b-main',
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      content: 'hello world',
    ),
    MessageBlock.thinking(
      id: 'b-think',
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      content: 'reasoning',
      thinkingMillsec: 1200,
      thinkingStartTime: 1700000000000,
    ),
    MessageBlock.code(
      id: 'b-code',
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      content: 'print(1);',
      language: 'dart',
    ),
    MessageBlock.image(
      id: 'b-img',
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      url: 'https://example.com/a.png',
      mimeType: 'image/png',
      file: const MessageFileReference(
        id: 'f1',
        name: 'stored.png',
        originName: 'photo.png',
        size: 1024,
        mimeType: 'image/png',
      ),
    ),
    MessageBlock.tool(
      id: 'b-tool',
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      toolId: 't1',
      toolName: 'search',
      arguments: const {'query': 'dart', 'limit': 5},
      content: 'tool output text',
    ),
    MessageBlock.knowledgeReference(
      id: 'b-kref',
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      content: 'referenced snippet',
      knowledgeBaseId: 'kb-1',
      source: 'doc.md',
      similarity: 0.91,
      metadata: const KnowledgeReferenceMetadata(
        fileName: 'doc.md',
        fileId: 'file-1',
        knowledgeDocumentId: 'kdoc-1',
        searchQuery: 'dart drift',
        isCombined: true,
        resultCount: 1,
        results: [
          KnowledgeReferenceMetadataResult(
            index: 0,
            content: 'snippet body',
            similarity: 0.91,
            documentId: 'kdoc-1',
          ),
        ],
      ),
    ),
  ];

  Message messageWith(List<String> blockIds) => Message(
    id: 'msg-1',
    role: MessageRole.assistant,
    assistantId: 'asst-1',
    topicId: 'topic-1',
    createdAt: createdAt,
    status: MessageStatus.success,
    modelId: 'gpt-4o',
    usage: const Usage(promptTokens: 10, completionTokens: 20, totalTokens: 30),
    metrics: const Metrics(latency: 123, firstTokenLatency: 45),
    blocks: blockIds,
  );

  group('MessageDao + MessageBlockDao round-trip (in-memory Drift)', () {
    test(
      'a full message with several block types survives store→load',
      () async {
        final blocks = blocksFor('msg-1');
        final message = messageWith(blocks.map((b) => b.id).toList());

        await db.messageDao.upsert(message);
        await db.messageBlockDao.upsertAll(blocks);

        final loadedMessage = await db.messageDao.getById('msg-1');
        final loadedBlocks = await db.messageBlockDao.getByIds(message.blocks);

        expect(loadedMessage, message);
        expect(loadedBlocks, blocks);
      },
    );

    test('blocks are indexed by messageId', () async {
      final blocks = blocksFor('msg-1');
      await db.messageBlockDao.upsertAll(blocks);

      final byMessage = await db.messageBlockDao.getByMessageId('msg-1');
      expect(byMessage.toSet(), blocks.toSet());
    });

    test('upsert overwrites an existing row (same id)', () async {
      final original = MessageBlock.mainText(
        id: 'b-main',
        messageId: 'msg-1',
        status: MessageBlockStatus.streaming,
        createdAt: createdAt,
        content: 'partial',
      );
      await db.messageBlockDao.upsert(original);

      final updated = MessageBlock.mainText(
        id: 'b-main',
        messageId: 'msg-1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: 'final answer',
      );
      await db.messageBlockDao.upsert(updated);

      expect(await db.messageBlockDao.getById('b-main'), updated);
    });
  });

  group('Topic persistence + ordering', () {
    Topic topic(String id, {String? lastMessageTime}) => Topic(
      id: id,
      assistantId: 'asst-1',
      name: 'Topic $id',
      createdAt: createdAt,
      updatedAt: createdAt,
      lastMessageTime: lastMessageTime,
    );

    test('round-trips through the repository', () async {
      final t = topic('topic-1', lastMessageTime: '2024-03-01T00:00:00.000Z');
      await repo.saveTopic(t);
      expect(await repo.getTopic('topic-1'), t);
    });

    test('getRecentTopics orders by lastMessageTime, newest first', () async {
      await repo.saveTopic(
        topic('old', lastMessageTime: '2024-01-01T00:00:00.000Z'),
      );
      await repo.saveTopic(
        topic('new', lastMessageTime: '2024-06-01T00:00:00.000Z'),
      );
      await repo.saveTopic(
        topic('mid', lastMessageTime: '2024-03-01T00:00:00.000Z'),
      );

      final recent = await repo.getRecentTopics();
      expect(recent.map((t) => t.id).toList(), ['new', 'mid', 'old']);
    });

    test('deleteTopic cascades to its messages and their blocks', () async {
      final blocks = blocksFor('msg-1');
      await repo.saveTopic(topic('topic-1'));
      await repo.saveMessage(messageWith(blocks.map((b) => b.id).toList()));
      await repo.saveMessageBlocks(blocks);

      await repo.deleteTopic('topic-1');

      expect(await repo.getTopic('topic-1'), isNull);
      expect(await repo.getMessagesByTopicId('topic-1'), isEmpty);
      expect(await repo.getMessageBlocksByMessageId('msg-1'), isEmpty);
    });
  });

  group('Assistant persistence', () {
    test('round-trips, keeping pinned snake_case keys', () async {
      const assistant = Assistant(
        id: 'asst-1',
        name: 'Helper',
        toolChoice: 'auto',
        fileIds: ['f1', 'f2'],
        customParameters: [
          CustomParameter(
            name: 'top_k',
            value: 40,
            type: CustomParameterType.number,
          ),
        ],
      );

      await repo.saveAssistant(assistant);
      expect(await repo.getAssistant('asst-1'), assistant);
      expect(await repo.getAllAssistants(), [assistant]);

      await repo.deleteAssistant('asst-1');
      expect(await repo.getAssistant('asst-1'), isNull);
    });
  });
}
