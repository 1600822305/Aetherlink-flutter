import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'chat_providers.g.dart';

/// Application-layer DI seam + read view-models that back the M4.2.0 ChatPage
/// skeleton.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] and never imports `data` (Rule 1). Everything below
/// is the composition that makes those reads real — the M1 persistence stack
/// (Drift [AppDatabase] → [ChatRepositoryImpl]) wired up behind the
/// [ChatRepository] port, with no mocks. An empty database yields an empty
/// list, which the page renders as its empty state.
///
/// Sending, streaming, block rendering and topic selection are later slices
/// (M4.2.1+); this file intentionally exposes only `Future` reads.

/// The single app-wide Drift database (composition root in `core/database`).
/// Kept alive for the app's lifetime and closed when the container disposes.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

/// The chat persistence port, backed by Drift. Upper layers depend on the
/// [ChatRepository] interface; this provider is the one place the `data`
/// implementation is wired in.
@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) =>
    ChatRepositoryImpl(ref.watch(appDatabaseProvider));

/// The topic whose conversation the page shows. The skeleton has no topic
/// selection yet (M4.2.x), so it surfaces the most recent topic, or `null`
/// when the database is empty — which it is on a fresh install.
@riverpod
Future<Topic?> currentTopic(Ref ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final topics = await repo.getRecentTopics(limit: 1);
  return topics.isEmpty ? null : topics.first;
}

/// Messages for the [currentTopic], as stored. No current topic (empty
/// database) → an empty list → the page's empty state. This is the ChatPage's
/// "About-page moment": proof the presentation → application → repository →
/// Drift pipeline is connected, even with nothing to show yet.
@riverpod
Future<List<Message>> chatMessages(Ref ref) async {
  final topic = await ref.watch(currentTopicProvider.future);
  if (topic == null) {
    return const <Message>[];
  }
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getMessagesByTopicId(topic.id);
}
