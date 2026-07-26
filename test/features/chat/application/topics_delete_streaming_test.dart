import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/streaming_registry.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Regression: deleting / clearing a topic that is streaming in the background
/// used to leave the stream running, so its 2s checkpoints and terminal
/// persistence would write the deleted topic's messages straight back into the
/// DB (orphan data + a stale "generating" dot). [Topics.delete] /
/// [Topics.clearMessages] must cancel the stream first and only proceed once
/// the registry reports the topic as settled — the registry only drops a topic
/// after every bound cancel token has been released, which the stream binder
/// does *after* terminal persistence.
///
/// Also covers: [Topics.delete] must drop the id from the owning assistant's
/// `topicIds` (mirrors [Topics.move]) instead of leaving it dangling forever.
void main() {
  late AppDatabase db;
  late ChatRepositoryImpl repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
    container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    final t = DateTime.utc(2024, 1, 1, 12);
    await repo.saveAssistant(
      const Assistant(id: 'asst-1', name: 'A', topicIds: <String>['topic-1']),
    );
    await repo.saveTopic(
      Topic(
        id: 'topic-1',
        assistantId: 'asst-1',
        name: 'T',
        createdAt: t,
        updatedAt: t,
      ),
    );
    await repo.saveMessage(
      Message(
        id: 'root',
        role: MessageRole.root,
        assistantId: 'asst-1',
        topicId: 'topic-1',
        createdAt: t,
        status: MessageStatus.success,
      ),
    );
  }

  /// Simulates a background stream bound to `topic-1` the way the turn stream
  /// binder does: a cancel token bound in the registry, live views recorded,
  /// and — on cancellation — a final "checkpoint" DB write *before* the token
  /// is released and the topic's streaming state torn down. If delete/clear
  /// does not wait for settle, that write lands after the destructive
  /// operation and resurrects the topic's content.
  LlmCancelToken bindFakeStream() {
    final registry = container.read(streamingRegistryProvider.notifier);
    final token = LlmCancelToken();
    registry.bindToken('topic-1', token);
    registry.update('topic-1', const []);
    unawaited(
      token.whenCancelled.then((_) async {
        // Terminal persistence of the interrupted turn (partial output).
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await repo.saveMessage(
          Message(
            id: 'late-checkpoint',
            role: MessageRole.assistant,
            assistantId: 'asst-1',
            topicId: 'topic-1',
            createdAt: DateTime.utc(2024, 1, 1, 12, 1),
            status: MessageStatus.success,
            parentId: 'root',
          ),
        );
        registry.releaseToken('topic-1', token);
        registry.finish('topic-1');
      }),
    );
    return token;
  }

  test('delete cancels the background stream and settles before deleting',
      () async {
    await seed();
    final token = bindFakeStream();
    expect(
      container.read(streamingRegistryProvider).isStreaming('topic-1'),
      isTrue,
    );

    await container.read(topicsProvider.notifier).delete('topic-1');

    // The stream was cancelled and had fully settled before the delete ran.
    expect(token.isCancelled, isTrue);
    expect(
      container.read(streamingRegistryProvider).isStreaming('topic-1'),
      isFalse,
    );
    // Topic gone and — crucially — its late checkpoint write did not
    // resurrect any messages (it landed before deleteTopic wiped the topic).
    expect(await repo.getTopic('topic-1'), isNull);
    expect(await repo.getMessagesByTopicId('topic-1'), isEmpty);
  });

  test('delete removes the id from the owning assistant topicIds', () async {
    await seed();

    await container.read(topicsProvider.notifier).delete('topic-1');

    final assistant = await repo.getAssistant('asst-1');
    expect(assistant, isNotNull);
    expect(assistant!.topicIds, isNot(contains('topic-1')));
  });

  test('clearMessages cancels the background stream and settles first',
      () async {
    await seed();
    final token = bindFakeStream();

    await container.read(topicsProvider.notifier).clearMessages('topic-1');

    expect(token.isCancelled, isTrue);
    expect(
      container.read(streamingRegistryProvider).isStreaming('topic-1'),
      isFalse,
    );
    // The late checkpoint landed before the clear, so nothing but the virtual
    // root survives — the stream cannot re-write the cleared conversation.
    final remaining = await repo.getMessagesByTopicId('topic-1');
    expect(remaining.where((m) => m.role != MessageRole.root), isEmpty);
  });

  test('delete of a non-streaming topic is unaffected', () async {
    await seed();
    await container.read(topicsProvider.notifier).delete('topic-1');
    expect(await repo.getTopic('topic-1'), isNull);
  });
}
