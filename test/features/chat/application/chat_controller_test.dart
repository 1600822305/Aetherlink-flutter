import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/multi_model_mentions_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// A fake gateway that replays a fixed chunk script — no network, no key. It
/// records the request it was asked to stream so tests can assert the composed
/// [LlmChatRequest] (history, model, endpoint config).
class _FakeGateway implements LlmGateway {
  _FakeGateway(this.script);

  final List<LlmStreamChunk> script;
  LlmChatRequest? lastRequest;

  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
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
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
    for (final chunk in before) {
      yield chunk;
    }
    throw StateError('boom');
  }
}

/// A gateway that streams [before], signals [started], then blocks until its
/// [LlmCancelToken] is cancelled and throws — simulating a real adapter whose
/// HTTP request is aborted mid-stream (dio surfaces the cancel as a stream
/// error). Lets a test drive [ChatController.stopStreaming] deterministically.
class _CancellableGateway implements LlmGateway {
  _CancellableGateway(this.before, this.started);

  final List<LlmStreamChunk> before;
  final Completer<void> started;

  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
    for (final chunk in before) {
      yield chunk;
    }
    if (!started.isCompleted) started.complete();
    await cancelToken!.whenCancelled;
    throw StateError('aborted');
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

  test('stopStreaming aborts the reply and keeps the partial output', () async {
    final started = Completer<void>();
    final gateway = _CancellableGateway(const [
      LlmStreamChunk.reasoningDelta('thinking'),
      LlmStreamChunk.textDelta('Partial'),
    ], started);
    final container = _container(
      gateway: gateway,
      repo: repo,
      current: _currentModel(),
    );

    await container.read(chatControllerProvider.future);
    final sending = container.read(chatControllerProvider.notifier).send('hi');

    // Wait until the partial chunks have streamed, then stop mid-flight.
    await started.future;
    container.read(chatControllerProvider.notifier).stopStreaming();
    await sending;

    final state = container.read(chatControllerProvider).requireValue;
    expect(state.isStreaming, isFalse);

    // The aborted turn is kept as a normal (success) reply with what streamed.
    final assistant = state.messages.last;
    expect(assistant.role, MessageRole.assistant);
    expect(assistant.status, MessageStatus.success);
    expect(assistant.text, 'Partial');
    expect(assistant.thinking, 'thinking');

    final topics = await repo.getRecentTopics();
    final messages = await repo.getMessagesByTopicId(topics.single.id);
    final assistantMsg = messages.firstWhere(
      (m) => m.role == MessageRole.assistant,
    );
    expect(assistantMsg.status, MessageStatus.success);
    final blocks = await repo.getMessageBlocksByMessageId(assistantMsg.id);
    expect(blocks.whereType<MainTextBlock>().single.content, 'Partial');
    expect(blocks.whereType<ThinkingBlock>().single.content, 'thinking');
    // No error block: a user-initiated stop is not a failure.
    expect(blocks.whereType<ErrorBlock>(), isEmpty);
  });

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
                kind: ComposerAttachmentKind.text,
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
              kind: ComposerAttachmentKind.text,
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

  test(
    'send with an image attachment stages an IMAGE block + image part',
    () async {
      final gateway = _FakeGateway(const [
        LlmStreamChunk.textDelta('a cat'),
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
            'what is this?',
            attachments: const [
              ComposerAttachment(
                id: 'img_1',
                name: 'cat.png',
                mimeType: 'image/png',
                size: 3,
                kind: ComposerAttachmentKind.image,
                base64Data: 'AAAA',
              ),
            ],
          );

      final state = container.read(chatControllerProvider).requireValue;
      final user = state.messages.first;
      final imageBlock = user.blocks.whereType<ImageBlock>().single;
      expect(imageBlock.mimeType, 'image/png');
      expect(imageBlock.base64Data, 'AAAA');

      final request = gateway.lastRequest!;
      final message = request.messages.single;
      expect(message.content, 'what is this?');
      expect(message.images, hasLength(1));
      expect(message.images!.single.mimeType, 'image/png');
      expect(message.images!.single.base64Data, 'AAAA');
    },
  );

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

  // A second model under the same provider, for multi-model fan-out tests.
  CurrentModel modelB() => const CurrentModel(
    provider: ModelProvider(
      id: 'p1',
      name: 'Test',
      avatar: 'T',
      color: '#000000',
      apiKey: 'sk-test',
      baseUrl: 'https://example.test',
      providerType: 'openai',
    ),
    model: Model(id: 'gpt-test-2', name: 'GPT Test 2', provider: 'Test'),
  );

  test(
    'sendMultiModel builds one sibling group and streams every model',
    () async {
      final gateway = _FakeGateway(const [
        LlmStreamChunk.textDelta('Hello'),
        LlmStreamChunk.textDelta(' world'),
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
          .sendMultiModel('hi', [_currentModel(), modelB()]);

      final state = container.read(chatControllerProvider).requireValue;
      expect(state.isStreaming, isFalse);

      // View: user turn + two assistant siblings, both finalized.
      expect(state.messages, hasLength(3));
      expect(state.messages.first.role, MessageRole.user);
      final assistants = state.messages
          .where((m) => m.role == MessageRole.assistant)
          .toList();
      expect(assistants, hasLength(2));
      for (final a in assistants) {
        expect(a.status, MessageStatus.success);
        expect(a.text, 'Hello world');
        expect(a.siblingsGroupId, greaterThan(0));
      }
      // The two siblings share one group id and the first is the selected one.
      expect(
        assistants[0].siblingsGroupId,
        assistants[1].siblingsGroupId,
      );
      expect(assistants[0].foldSelected, isTrue);
      expect(assistants[1].foldSelected, isFalse);
      expect(assistants.map((a) => a.modelName), ['GPT Test', 'GPT Test 2']);

      // Persistence: user message records the mentions; both siblings share its
      // askId and the topic's active leaf is the first sibling.
      final topics = await repo.getRecentTopics();
      final topic = topics.single;
      final messages = await repo.getMessagesByTopicId(topic.id);
      expect(messages, hasLength(3));
      final userMsg = messages.firstWhere((m) => m.role == MessageRole.user);
      expect(userMsg.mentions, hasLength(2));
      final siblings = messages
          .where((m) => m.role == MessageRole.assistant)
          .toList();
      for (final s in siblings) {
        expect(s.askId, userMsg.id);
        expect(s.parentId, userMsg.id);
        expect(s.siblingsGroupId, greaterThan(0));
      }
      final reloaded = await repo.getTopic(topic.id);
      expect(reloaded!.activeNodeId, assistants.first.id);

      // The display projection inlines the whole group after the user message.
      final branch = await repo.getBranchMessages(topic.id);
      expect(branch.map((m) => m.role), [
        MessageRole.user,
        MessageRole.assistant,
        MessageRole.assistant,
      ]);
    },
  );

  test('send routes to multi-model when mentions are staged', () async {
    final gateway = _FakeGateway(const [
      LlmStreamChunk.textDelta('Hi'),
      LlmStreamChunk.done(),
    ]);
    final container = _container(
      gateway: gateway,
      repo: repo,
      current: _currentModel(),
    );

    await container.read(chatControllerProvider.future);
    container
        .read(multiModelMentionsProvider.notifier)
        .set([_currentModel(), modelB()]);
    await container.read(chatControllerProvider.notifier).send('hello');

    final state = container.read(chatControllerProvider).requireValue;
    expect(state.messages, hasLength(3)); // user + 2 siblings
    expect(
      state.messages.where((m) => m.role == MessageRole.assistant),
      hasLength(2),
    );
    // The one-shot mentions are consumed after sending.
    expect(container.read(multiModelMentionsProvider), isEmpty);
  });

  test('selectSibling moves the active leaf and fold flag', () async {
    final gateway = _FakeGateway(const [
      LlmStreamChunk.textDelta('Hi'),
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
        .sendMultiModel('hi', [_currentModel(), modelB()]);

    final topic = (await repo.getRecentTopics()).single;
    var messages = await repo.getMessagesByTopicId(topic.id);
    final second = messages.firstWhere((m) => m.model?.id == 'gpt-test-2');
    expect(second.foldSelected ?? false, isFalse);

    await container.read(chatControllerProvider.notifier).selectSibling(second.id);

    final reloaded = await repo.getTopic(topic.id);
    expect(reloaded!.activeNodeId, second.id);
    messages = await repo.getMessagesByTopicId(topic.id);
    final first = messages.firstWhere((m) => m.model?.id == 'gpt-test');
    expect(
      messages.firstWhere((m) => m.id == second.id).foldSelected,
      isTrue,
    );
    expect(first.foldSelected, isFalse);
  });

  test(
    'branch fork: switcher data appears and switchActiveBranch crosses branches',
    () async {
      final gateway = _FakeGateway(const [
        LlmStreamChunk.textDelta('a'),
        LlmStreamChunk.done(),
      ]);
      // A real current topic (not the null override) so the controller's
      // _topicId survives the refresh that switchToBranch triggers.
      final now = DateTime.now();
      final topic = Topic(
        id: 'topic-fork',
        assistantId: 'default-assistant',
        name: '分叉',
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveTopic(topic);
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          llmGatewayFactoryProvider.overrideWithValue(_FakeFactory(gateway)),
          currentTopicProvider.overrideWith((ref) async => topic),
          appCurrentModelProvider.overrideWith((ref) async => _currentModel()),
          appModelProvidersProvider.overrideWith(
            (ref) async => <ModelProvider>[_currentModel().provider],
          ),
        ],
      );
      addTearDown(container.dispose);
      final ctrl = container.read(chatControllerProvider.notifier);
      await container.read(chatControllerProvider.future);

      await ctrl.send('q1'); // U1 → A1 (active A1)
      await ctrl.send('q2'); // U2(child of A1) → A2 (active A2)

      final all = await repo.getMessagesByTopicId(topic.id)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final u1 = all.firstWhere((m) => m.role == MessageRole.user);
      final a1 = all.firstWhere(
        (m) => m.role == MessageRole.assistant && m.askId == u1.id,
      );

      // Go back to A1 and ask a different follow-up → a fork at A1.
      await ctrl.switchToBranch(a1.id);
      await ctrl.send('q3'); // U3(child of A1) → A3 (active A3)

      // A1 now has two regular branch children (U2, U3).
      final children =
          (await repo.getMessagesByTopicId(topic.id))
              .where((m) => m.parentId == a1.id && m.siblingsGroupId == 0)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(children, hasLength(2));
      final u2Id = children.first.id;
      final u3Id = children.last.id;

      // Displayed (active) path is U1 → A1 → U3 → A3; U3 carries the switcher
      // data for both branch siblings. Branch info is computed in build()/_load,
      // so reload (as a topic switch / refresh would) before asserting it.
      container.invalidate(chatControllerProvider);
      var state = await container.read(chatControllerProvider.future);
      final u3View = state.messages.firstWhere((v) => v.id == u3Id);
      expect(u3View.branchSiblingIds, containsAll(<String>[u2Id, u3Id]));
      expect(u3View.branchSiblingIds, hasLength(2));
      expect(state.messages.any((v) => v.id == u2Id), isFalse);

      // Switch to the other branch → active path becomes U1 → A1 → U2 → A2.
      await ctrl.switchActiveBranch(u2Id);
      container.invalidate(chatControllerProvider);
      state = await container.read(chatControllerProvider.future);
      expect(state.messages.any((v) => v.id == u2Id), isTrue);
      expect(state.messages.any((v) => v.id == u3Id), isFalse);
      expect(state.messages.last.role, MessageRole.assistant);
    },
  );
}
