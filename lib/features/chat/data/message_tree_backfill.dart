import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_tree_builder.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// PR-2 of the message-tree refactor (docs/design/message-tree-model-design.md
/// §5): in-place backfill of existing (flat) data into the tree shape. For each
/// topic it creates the content-less virtual root, runs [buildMessageTree] over
/// the chronologically-sorted messages to assign `parentId` / `siblingsGroupId`
/// (first-turn messages reparent to the root), and sets `topic.activeNodeId`
/// via [findActiveNodeId].
///
/// Properties:
/// - **Order-preserving**: it sorts with the same [compareMessagesChronologically]
///   the read path uses, so the linear path after migration matches what the
///   user saw before.
/// - **Idempotent**: topics that already own a virtual root are skipped, so a
///   re-run can't create a second root.
/// - **Non-destructive**: it only sets the new fields (and adds root rows); the
///   legacy `askId` / `foldSelected` / `messageIds` are left intact, so an older
///   app build can still read the database via the flat path (rollback-safe).
///
/// The read path is unchanged this PR: [MessageDao.getByTopicId] filters the
/// root out, so the flat list still renders exactly as before.
Future<void> backfillMessageTree(AppDatabase db) async {
  final topics = await db.topicDao.getAll();
  for (final topic in topics) {
    await _backfillTopic(db, topic);
  }
}

Future<void> _backfillTopic(AppDatabase db, Topic topic) async {
  // Idempotency: already migrated (has a virtual root) → nothing to do.
  if (await db.messageDao.getRootByTopicId(topic.id) != null) return;

  final messages = await db.messageDao.getByTopicId(topic.id)
    ..sort(compareMessagesChronologically);

  // Create the virtual root. Its createdAt sits at/just before the first
  // message so the existing chronological sort would order it first anyway.
  final rootId = generateId('root');
  await db.messageDao.upsert(
    Message(
      id: rootId,
      role: MessageRole.root,
      assistantId: topic.assistantId,
      topicId: topic.id,
      createdAt: messages.isEmpty ? topic.createdAt : messages.first.createdAt,
      status: MessageStatus.success,
    ),
  );

  if (messages.isNotEmpty) {
    final tree = buildMessageTree(messages);
    for (final message in messages) {
      final placement = tree[message.id]!;
      await db.messageDao.upsert(
        message.copyWith(
          // First-turn messages (null parent from the builder) hang off the root.
          parentId: placement.parentId ?? rootId,
          siblingsGroupId: placement.siblingsGroupId,
        ),
      );
    }
  }

  await db.topicDao.upsert(
    topic.copyWith(activeNodeId: findActiveNodeId(messages)),
  );
}
