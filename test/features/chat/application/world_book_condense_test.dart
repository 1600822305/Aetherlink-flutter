import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/auxiliary_model_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/context_condense_service.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

class _SummaryGateway implements LlmGateway {
  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
    yield const LlmStreamChunk.textDelta('SUMMARY');
    yield const LlmStreamChunk.done();
  }
}

const _provider = ModelProvider(
  id: 'p1',
  name: 'Test',
  avatar: 'T',
  color: '#000000',
  apiKey: 'sk',
  models: [Model(id: 'm', name: 'M', provider: 'p1', isDefault: true)],
);

void main() {
  late AppDatabase db;
  late ChatRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<Topic> seed() async {
    final t0 = DateTime.utc(2026, 11, 1);
    final topic = Topic(
      id: 't',
      assistantId: 'a',
      name: 'n',
      createdAt: t0,
      updatedAt: t0,
    );
    await repo.saveTopic(topic);
    for (var i = 0; i < 6; i++) {
      final isUser = i.isEven;
      final id = 'm$i';
      final turn = i ~/ 2 + 1;
      await repo.saveMessage(
        Message(
          id: id,
          role: isUser ? MessageRole.user : MessageRole.assistant,
          assistantId: 'a',
          topicId: topic.id,
          createdAt: t0.add(Duration(minutes: i)),
          status: MessageStatus.success,
          blocks: ['b$i'],
          metadata: isUser
              ? WorldBookActivationState(
                  turn: turn,
                  effects: {
                    'k': WorldBookEffect(activatedAt: turn, signature: 's'),
                  },
                ).writeTo(null)
              : null,
        ),
      );
      await repo.saveMessageBlock(
        MessageBlock.mainText(
          id: 'b$i',
          messageId: id,
          status: MessageBlockStatus.success,
          createdAt: t0,
          content: 'text $i',
        ),
      );
    }
    return (await repo.getTopic(topic.id))!;
  }

  test('compression carries the newest compressed timer state to the summary',
      () async {
    final topic = await seed();
    final service = ContextCondenseService(
      repo: repo,
      readCurrentTopic: () async => topic,
      readIsStreaming: () => false,
      readAuxState: () => const AuxiliaryModelState(),
      readProviders: () async => const [_provider],
      buildGateway: (_) => _SummaryGateway(),
      refreshChat: () {},
    );

    final result = await service.compress(
      options: const CondenseOptions(keepRecentMessages: 2),
    );
    expect(result.success, isTrue, reason: result.error);

    final messages = await repo.getMessagesByTopicId(topic.id);
    final summary = messages.singleWhere(
      (m) => m.metadata?['isSummary'] == true,
    );
    final carried = WorldBookActivationState.fromMetadata(summary.metadata)!;
    // m0..m3 compressed: the newest compressed user turn is m2 (turn 2).
    expect(carried.turn, 2);
    expect(carried.effects['k']!.activatedAt, 2);
    // The kept user turn still owns its own state.
    final kept = messages.firstWhere((m) => m.id == 'm4');
    expect(WorldBookActivationState.fromMetadata(kept.metadata)!.turn, 3);
  });

  test('without any timer state the summary metadata is unchanged', () async {
    final topic = await seed();
    for (final m in await repo.getMessagesByTopicId(topic.id)) {
      await repo.saveMessage(m.copyWith(metadata: null));
    }
    final service = ContextCondenseService(
      repo: repo,
      readCurrentTopic: () async => topic,
      readIsStreaming: () => false,
      readAuxState: () => const AuxiliaryModelState(),
      readProviders: () async => const [_provider],
      buildGateway: (_) => _SummaryGateway(),
      refreshChat: () {},
    );
    await service.compress(
      options: const CondenseOptions(keepRecentMessages: 2),
    );
    final summary = (await repo.getMessagesByTopicId(topic.id)).singleWhere(
      (m) => m.metadata?['isSummary'] == true,
    );
    expect(summary.metadata, {'isSummary': true});
  });
}
