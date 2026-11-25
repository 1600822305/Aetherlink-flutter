import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Records every request so tests can assert what each model was sent.
class _RecordingGateway implements LlmGateway {
  final List<LlmChatRequest> requests = [];

  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
    requests.add(request);
    yield const LlmStreamChunk.textDelta('ok');
    yield const LlmStreamChunk.done();
  }
}

class _Factory implements LlmGatewayFactory {
  _Factory(this.gateway);

  final LlmGateway gateway;

  @override
  LlmGateway forModel(Model model) => gateway;
}

const _provider = ModelProvider(
  id: 'p1',
  name: 'Test',
  avatar: 'T',
  color: '#000000',
  apiKey: 'sk-test',
  baseUrl: 'https://example.test',
  providerType: 'openai',
);

const _modelA = CurrentModel(
  provider: _provider,
  model: Model(id: 'gpt-a', name: 'GPT A', provider: 'Test', isDefault: true),
);

const _modelB = CurrentModel(
  provider: _provider,
  model: Model(id: 'gpt-b', name: 'GPT B', provider: 'Test'),
);

const _assistantId = 'default-assistant';
final _ts = DateTime.utc(2026, 11, 1);

/// One book: a sticky (2) keyword entry injected before the system prompt,
/// with a placeholder to prove substitution happens inside the builder.
const _book = WorldBook(
  id: 'wb',
  name: 'Lore',
  entries: [
    WorldBookEntry(
      id: 'dragon',
      name: 'Dragon',
      content: 'DRAGON-LORE for {model_name}',
      keywords: ['dragon'],
      scanDepth: 1,
      sticky: 2,
      position: WorldBookInjectionPosition.beforeSystemPrompt,
    ),
  ],
);

Future<ProviderContainer> _setUp(
  AppDatabase db,
  ChatRepositoryImpl repo,
  _RecordingGateway gateway, {
  Topic? topic,
}) async {
  await repo.saveAssistant(
    const Assistant(
      id: _assistantId,
      name: 'A',
      systemPrompt: 'PERSONA',
      worldBookIds: ['wb'],
    ),
  );
  await WorldBookRepositoryImpl(db.worldBookDao).save(_book);
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      llmGatewayFactoryProvider.overrideWithValue(_Factory(gateway)),
      currentTopicProvider.overrideWith((ref) async => topic),
      appCurrentModelProvider.overrideWith((ref) async => _modelA),
      appModelProvidersProvider.overrideWith(
        (ref) async => const <ModelProvider>[_provider],
      ),
      worldBookRepositoryProvider.overrideWithValue(
        WorldBookRepositoryImpl(db.worldBookDao),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(chatControllerProvider.future);
  return container;
}

Future<List<WorldBookActivationState>> _userStates(
  ChatRepositoryImpl repo,
) async {
  final topic = (await repo.getRecentTopics()).single;
  final messages = await repo.getMessagesByTopicId(topic.id)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return [
    for (final m in messages)
      if (m.role == MessageRole.user)
        WorldBookActivationState.fromMetadata(m.metadata) ??
            WorldBookActivationState.empty,
  ];
}

void main() {
  late AppDatabase db;
  late ChatRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
  });
  tearDown(() => db.close());

  test('send injects inside the system prompt with placeholders resolved, '
      'records state on the user message, and sticky carries', () async {
    final gateway = _RecordingGateway();
    final container = await _setUp(db, repo, gateway);
    final chat = container.read(chatControllerProvider.notifier);

    await chat.send('a dragon appears');
    final system = gateway.requests.last.system!;
    expect(system, startsWith('DRAGON-LORE for GPT A\nPERSONA'));

    await chat.send('nothing here');
    expect(gateway.requests.last.system, contains('DRAGON-LORE'));
    await chat.send('still nothing');
    expect(gateway.requests.last.system, contains('DRAGON-LORE'));
    await chat.send('and again');
    expect(gateway.requests.last.system, isNot(contains('DRAGON-LORE')));

    final states = await _userStates(repo);
    expect([for (final s in states) s.turn], [1, 2, 3, 4]);
    expect(states.first.effects, hasLength(1));

    final assistant = container
        .read(chatControllerProvider)
        .requireValue
        .messages
        .firstWhere((m) => m.role == MessageRole.assistant);
    final block = assistant.blocks.whereType<WorldBookInjectionBlock>().single;
    expect(block.count, 1);
    expect(block.entries, ['Dragon']);
    expect(block.estimatedTokens, greaterThan(0));
  });

  test('regenerate re-evaluates the same turn without advancing it', () async {
    final gateway = _RecordingGateway();
    final container = await _setUp(db, repo, gateway);
    final chat = container.read(chatControllerProvider.notifier);
    await chat.send('a dragon appears');
    final reply = container
        .read(chatControllerProvider)
        .requireValue
        .messages
        .last;
    await chat.regenerate(reply.id);
    expect(gateway.requests.last.system, contains('DRAGON-LORE'));
    expect([for (final s in await _userStates(repo)) s.turn], [1]);
  });

  test('multi-model evaluates once and every sibling gets the same lore',
      () async {
    final gateway = _RecordingGateway();
    final container = await _setUp(db, repo, gateway);
    await container
        .read(chatControllerProvider.notifier)
        .sendMultiModel('a dragon appears', const [_modelA, _modelB]);

    expect(gateway.requests, hasLength(2));
    for (final r in gateway.requests) {
      expect(r.system, contains('DRAGON-LORE'));
    }
    // Each sibling's own model name is substituted, the entry set is shared.
    expect(gateway.requests.map((r) => r.system!.split('\n').first).toSet(), {
      'DRAGON-LORE for GPT A',
      'DRAGON-LORE for GPT B',
    });
    final states = await _userStates(repo);
    expect(states.single.turn, 1, reason: 'one tick for the shared user turn');
  });

  test('continue now sends a system prompt with world book lore', () async {
    final gateway = _RecordingGateway();
    final topic = Topic(
      id: 't-cont',
      assistantId: _assistantId,
      name: 'c',
      createdAt: _ts,
      updatedAt: _ts,
    );
    await repo.saveTopic(topic);
    await repo.saveMessage(
      Message(
        id: 'u1',
        role: MessageRole.user,
        assistantId: _assistantId,
        topicId: topic.id,
        createdAt: _ts,
        status: MessageStatus.success,
        blocks: const ['bu1'],
      ),
    );
    await repo.saveMessageBlock(
      MessageBlock.mainText(
        id: 'bu1',
        messageId: 'u1',
        status: MessageBlockStatus.success,
        createdAt: _ts,
        content: 'tell me of the dragon',
      ),
    );
    await repo.saveMessage(
      Message(
        id: 'a1',
        role: MessageRole.assistant,
        assistantId: _assistantId,
        topicId: topic.id,
        createdAt: _ts.add(const Duration(seconds: 1)),
        status: MessageStatus.success,
        model: _modelA.model,
        askId: 'u1',
        blocks: const ['ba1'],
      ),
    );
    await repo.saveMessageBlock(
      MessageBlock.mainText(
        id: 'ba1',
        messageId: 'a1',
        status: MessageBlockStatus.success,
        createdAt: _ts,
        content: 'Once upon',
      ),
    );
    final container = await _setUp(
      db,
      repo,
      gateway,
      topic: await repo.getTopic(topic.id),
    );
    await container.read(chatControllerProvider.notifier).continueGenerating('a1');

    final request = gateway.requests.last;
    expect(request.system, contains('PERSONA'));
    expect(request.system, contains('DRAGON-LORE'));
    expect(request.messages.last.role, MessageRole.assistant);
    expect(request.messages.last.content, 'Once upon');
  });

  test('legacy kelivo activation metadata on an ancestor is read safely',
      () async {
    final gateway = _RecordingGateway();
    final container = await _setUp(db, repo, gateway);
    final chat = container.read(chatControllerProvider.notifier);
    await chat.send('hello');
    final topic = (await repo.getRecentTopics()).single;
    final user = (await repo.getMessagesByTopicId(topic.id))
        .firstWhere((m) => m.role == MessageRole.user);
    await repo.saveMessage(
      user.copyWith(
        metadata: {
          kWorldBookActivationMetadataKey: {
            'messageCount': 'garbage',
            'historyHash': 1,
            'effects': [1, 2],
          },
        },
      ),
    );
    await chat.send('a dragon');
    expect(gateway.requests.last.system, contains('DRAGON-LORE'));
  });
}
