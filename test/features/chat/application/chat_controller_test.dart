import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// A fake gateway that replays a fixed chunk script — no network, no key. It
/// records the request it was asked to stream so tests can assert the composed
/// [LlmChatRequest] (history, model, endpoint config).
class _FakeGateway implements LlmGateway {
  _FakeGateway(this.script);

  final List<LlmStreamChunk> script;
  LlmChatRequest? lastRequest;

  @override
  Stream<LlmStreamChunk> streamChat(LlmChatRequest request) async* {
    lastRequest = request;
    for (final chunk in script) {
      yield chunk;
    }
  }
}

/// A gateway that fails mid-stream (after emitting [before]) to exercise the
/// error path.
class _ThrowingGateway implements LlmGateway {
  _ThrowingGateway(this.before);

  final List<LlmStreamChunk> before;

  @override
  Stream<LlmStreamChunk> streamChat(LlmChatRequest request) async* {
    for (final chunk in before) {
      yield chunk;
    }
    throw StateError('boom');
  }
}

class _FakeFactory implements LlmGatewayFactory {
  _FakeFactory(this.gateway);

  final LlmGateway gateway;

  @override
  LlmGateway forModel(Model model) => gateway;
}

CurrentModel _currentModel() => const CurrentModel(
  provider: ModelProvider(
    id: 'p1',
    name: 'Test',
    avatar: 'T',
    color: '#000000',
    apiKey: 'sk-test',
    baseUrl: 'https://example.test',
    providerType: 'openai',
  ),
  model: Model(
    id: 'gpt-test',
    name: 'GPT Test',
    provider: 'Test',
    isDefault: true,
  ),
);

ProviderContainer _container({
  required LlmGateway gateway,
  required ChatRepositoryImpl repo,
  CurrentModel? current,
}) {
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      llmGatewayFactoryProvider.overrideWithValue(_FakeFactory(gateway)),
      currentTopicProvider.overrideWith((ref) async => null),
      appCurrentModelProvider.overrideWith((ref) async => current),
      // `_viewOf` reads this to resolve a message's provider name; override it
      // so the view build stays in-memory instead of opening the real store.
      appModelProvidersProvider.overrideWith(
        (ref) async => current == null
            ? const <ModelProvider>[]
            : <ModelProvider>[current.provider],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

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

  test(
    'send streams text + reasoning, updates state, and persists the loop',
    () async {
      final gateway = _FakeGateway(const [
        LlmStreamChunk.reasoningDelta('think '),
        LlmStreamChunk.reasoningDelta('hard'),
        LlmStreamChunk.textDelta('Hello'),
        LlmStreamChunk.textDelta(', world'),
        LlmStreamChunk.done(),
      ]);
      final container = _container(
        gateway: gateway,
        repo: repo,
        current: _currentModel(),
      );

      await container.read(chatControllerProvider.future);
      await container.read(chatControllerProvider.notifier).send('hi');

      final state = container.read(chatControllerProvider).requireValue;

      // View: user turn + finalized assistant turn, nothing streaming.
      expect(state.isStreaming, isFalse);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.role, MessageRole.user);
      expect(state.messages.first.text, 'hi');

      final assistant = state.messages.last;
      expect(assistant.role, MessageRole.assistant);
      expect(assistant.status, MessageStatus.success);
      expect(assistant.text, 'Hello, world');
      expect(assistant.thinking, 'think hard');

      // Request: built from the current model + history (user turn present, the
      // empty assistant placeholder excluded), with the provider endpoint config.
      final request = gateway.lastRequest!;
      expect(request.model.apiKey, 'sk-test');
      expect(request.model.baseUrl, 'https://example.test');
      expect(request.messages, hasLength(1));
      expect(request.messages.single.content, 'hi');
      expect(request.messages.single.role, MessageRole.user);

      // Persistence: a topic, two messages and their blocks landed in the repo.
      final topics = await repo.getRecentTopics();
      expect(topics, hasLength(1));
      final messages = await repo.getMessagesByTopicId(topics.single.id);
      expect(messages, hasLength(2));

      final assistantMsg = messages.firstWhere(
        (m) => m.role == MessageRole.assistant,
      );
      expect(assistantMsg.status, MessageStatus.success);
      final blocks = await repo.getMessageBlocksByMessageId(assistantMsg.id);
      final mainText = blocks.whereType<MainTextBlock>().single;
      final thinking = blocks.whereType<ThinkingBlock>().single;
      expect(mainText.content, 'Hello, world');
      expect(thinking.content, 'think hard');
    },
  );

  test(
    'a pasted-as-file attachment becomes a FILE block and feeds the model',
    () async {
      final gateway = _FakeGateway(const [
        LlmStreamChunk.textDelta('ok'),
        LlmStreamChunk.done(),
      ]);
      final container = _container(
        gateway: gateway,
        repo: repo,
        current: _currentModel(),
      );

      await container.read(chatControllerProvider.future);
      await container
          .read(chatControllerProvider.notifier)
          .send(
            'see file',
            attachments: const [
              ComposerAttachment(
                id: 'file_1',
                name: '粘贴的文本_20260620T061205.txt',
                mimeType: 'text/plain',
                size: 11,
                text: 'hello world',
              ),
            ],
          );

      // View: the user turn carries its main text plus a FILE block.
      final state = container.read(chatControllerProvider).requireValue;
      final user = state.messages.first;
      expect(user.role, MessageRole.user);
      expect(user.text, 'see file');
      final fileBlock = user.blocks.whereType<FileBlock>().single;
      expect(fileBlock.name, '粘贴的文本_20260620T061205.txt');
      expect(fileBlock.mimeType, 'text/plain');
      expect(fileBlock.file?.base64Data, startsWith('data:text/plain;base64,'));

      // Request: the model receives the typed text plus the file's decoded text.
      final request = gateway.lastRequest!;
      expect(request.messages.single.content, 'see file\n\nhello world');

      // Persistence: the FILE block landed in the repo.
      final topics = await repo.getRecentTopics();
      final messages = await repo.getMessagesByTopicId(topics.single.id);
      final userMsg = messages.firstWhere((m) => m.role == MessageRole.user);
      final blocks = await repo.getMessageBlocksByMessageId(userMsg.id);
      expect(blocks.whereType<FileBlock>(), hasLength(1));
    },
  );

  test('send with only an attachment (no typed text) still sends', () async {
    final gateway = _FakeGateway(const [
      LlmStreamChunk.textDelta('ok'),
      LlmStreamChunk.done(),
    ]);
    final container = _container(
      gateway: gateway,
      repo: repo,
      current: _currentModel(),
    );

    await container.read(chatControllerProvider.future);
    await container
        .read(chatControllerProvider.notifier)
        .send(
          '',
          attachments: const [
            ComposerAttachment(
              id: 'file_1',
              name: 'note.txt',
              mimeType: 'text/plain',
              size: 4,
              text: 'body',
            ),
          ],
        );

    final state = container.read(chatControllerProvider).requireValue;
    expect(state.messages, hasLength(2));
    final user = state.messages.first;
    expect(user.text, isEmpty);
    expect(user.blocks.whereType<FileBlock>(), hasLength(1));
    expect(user.blocks.whereType<MainTextBlock>(), isEmpty);

    final request = gateway.lastRequest!;
    expect(request.messages.single.content, 'body');
  });

  test('send with neither text nor attachments is a no-op', () async {
    final gateway = _FakeGateway(const [LlmStreamChunk.done()]);
    final container = _container(
      gateway: gateway,
      repo: repo,
      current: _currentModel(),
    );

    await container.read(chatControllerProvider.future);
    await container.read(chatControllerProvider.notifier).send('   ');

    final state = container.read(chatControllerProvider).requireValue;
    expect(state.messages, isEmpty);
    expect(await repo.getRecentTopics(), isEmpty);
  });

  test('send with no current model is a no-op', () async {
    final gateway = _FakeGateway(const [LlmStreamChunk.done()]);
    final container = _container(gateway: gateway, repo: repo, current: null);

    await container.read(chatControllerProvider.future);
    await container.read(chatControllerProvider.notifier).send('hi');

    final state = container.read(chatControllerProvider).requireValue;
    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect(await repo.getRecentTopics(), isEmpty);
  });

  test(
    'a stream error finalizes the assistant message in an error state',
    () async {
      final gateway = _ThrowingGateway(const [
        LlmStreamChunk.textDelta('partial'),
      ]);
      final container = _container(
        gateway: gateway,
        repo: repo,
        current: _currentModel(),
      );

      await container.read(chatControllerProvider.future);
      await container.read(chatControllerProvider.notifier).send('hi');

      final state = container.read(chatControllerProvider).requireValue;
      expect(state.isStreaming, isFalse);
      final assistant = state.messages.last;
      expect(assistant.status, MessageStatus.error);
      expect(assistant.errorText, isNotNull);

      final topics = await repo.getRecentTopics();
      final messages = await repo.getMessagesByTopicId(topics.single.id);
      final assistantMsg = messages.firstWhere(
        (m) => m.role == MessageRole.assistant,
      );
      expect(assistantMsg.status, MessageStatus.error);
      final blocks = await repo.getMessageBlocksByMessageId(assistantMsg.id);
      expect(blocks.whereType<ErrorBlock>(), isNotEmpty);
    },
  );
}
