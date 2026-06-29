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
    await linkTopicMessageTree(db, topic);
  }
}

/// PR (v8→v9): repairs the tree so the single-root partial-unique index can be
/// created safely. For each topic it collapses any stray extra virtual roots to
/// one and re-attaches every content message whose `parentId` is still NULL
/// (legacy rows written by the pre-tree path), recomputing the whole topic's
/// tree via [buildMessageTree] when stragglers exist. Idempotent and
/// non-destructive (only sets fields / removes duplicate content-less roots).
Future<void> repairMessageTree(AppDatabase db) async {
  final topics = await db.topicDao.getAll();
  for (final topic in topics) {
    final roots = await db.messageDao.getRootsByTopicId(topic.id);
    final messages = await db.messageDao.getByTopicId(topic.id)
      ..sort(compareMessagesChronologically);

    // Topic has neither root nor content → nothing to repair (no first send yet).
    if (roots.isEmpty && messages.isEmpty) continue;

    // Ensure exactly one virtual root; drop any content-less duplicates.
    String rootId;
    if (roots.isEmpty) {
      rootId = generateId('root');
      await db.messageDao.upsert(
        Message(
          id: rootId,
          role: MessageRole.root,
          assistantId: topic.assistantId,
          topicId: topic.id,
          createdAt: messages.isEmpty
              ? topic.createdAt
              : messages.first.createdAt,
          status: MessageStatus.success,
        ),
      );
    } else {
      rootId = roots.first.id;
      for (final extra in roots.skip(1)) {
        await db.messageDao.deleteById(extra.id);
      }
    }

    // Re-attach any straggler with a NULL parent (recompute the whole topic so
    // siblings/orphans stay consistent; deterministic, stable for linear data).
    if (messages.any((m) => m.parentId == null)) {
      final tree = buildMessageTree(messages);
      for (final m in messages) {
        final placement = tree[m.id]!;
        final parentId = placement.parentId ?? rootId;
        if (m.parentId != parentId ||
            m.siblingsGroupId != placement.siblingsGroupId) {
          await db.messageDao.upsert(
            m.copyWith(
              parentId: parentId,
              siblingsGroupId: placement.siblingsGroupId,
            ),
          );
        }
      }
      if (topic.activeNodeId == null && messages.isNotEmpty) {
        await db.topicDao.upsert(
          topic.copyWith(activeNodeId: findActiveNodeId(messages)),
        );
      }
    }
  }
}

/// Backfills a single [topic]'s tree shape: creates its content-less virtual
/// root, runs [buildMessageTree] over its chronologically-sorted messages to
/// assign `parentId` / `siblingsGroupId` (first-turn messages reparent to the
/// root), and sets `topic.activeNodeId` via [findActiveNodeId]. Idempotent —
/// topics that already own a virtual root are skipped.
///
/// Used both by the bulk [backfillMessageTree] migration and by the
/// third-party importers (Cherry / Chatbox), which write flat messages and need
/// the same tree linkage so the branch graph and active path are correct.
Future<void> linkTopicMessageTree(AppDatabase db, Topic topic) async {
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
