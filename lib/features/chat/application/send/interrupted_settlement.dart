import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

/// Makes [blocks] the block set of [messageId] (in order) and stamps the
/// message [status]. Any block previously persisted for this message but no
/// longer referenced is pruned, so the persisted set is exactly what was
/// streamed — the block-order projection appends unreferenced blocks, so stale
/// ones would otherwise leak into the rendered order.
///
/// Terminal path only. During streaming use [checkpointMessageBlocks], which
/// writes incrementally and never deletes.
Future<void> persistMessageBlocks(
  ChatRepository repo, {
  required String messageId,
  required MessageStatus status,
  required List<MessageBlock> blocks,
  Usage? usage,
  Metrics? metrics,
}) async {
  await repo.replaceMessageBlocks(
    messageId: messageId,
    blocks: blocks,
    message: await _syncedMessage(
      repo,
      messageId: messageId,
      status: status,
      blocks: blocks,
      usage: usage,
      metrics: metrics,
    ),
  );
}

/// Streaming checkpoint: upserts only [changedBlocks] and re-points the
/// message's `blocks` list at [blockIds], **deleting nothing**.
///
/// Completed blocks (finished tool rounds, earlier prose) are written once when
/// they finish rather than rewritten on every checkpoint, so a long reply no
/// longer re-serializes its whole history — including bulky tool output — every
/// couple of seconds. Because nothing is deleted, a caller that under-reports
/// its block set degrades to "the message under-references a block" (fixable,
/// and recoverable by id) instead of destroying persisted content.
Future<void> checkpointMessageBlocks(
  ChatRepository repo, {
  required String messageId,
  required MessageStatus status,
  required List<MessageBlock> changedBlocks,
  required List<String> blockIds,
}) async {
  await repo.upsertMessageBlocksAndSync(
    messageId: messageId,
    blocks: changedBlocks,
    message: await _syncedMessage(
      repo,
      messageId: messageId,
      status: status,
      blockIds: blockIds,
    ),
  );
}

Future<Message?> _syncedMessage(
  ChatRepository repo, {
  required String messageId,
  required MessageStatus status,
  List<MessageBlock>? blocks,
  List<String>? blockIds,
  Usage? usage,
  Metrics? metrics,
}) async {
  final message = await repo.getMessage(messageId);
  return message?.copyWith(
    status: status,
    updatedAt: DateTime.now(),
    blocks: blockIds ?? [for (final block in blocks!) block.id],
    usage: usage ?? message.usage,
    metrics: metrics ?? message.metrics,
  );
}

/// 崩溃恢复：把 [topicId] 里上次运行遗留在 streaming 状态的消息落定（对齐
/// Cherry Studio 启动时的 `reconcileStalePendingMessages`）。检查点持久化让
/// 闪退前的正文/思考/工具块都已在库里：有内容就按 success 保留（对话不丢），
/// 一点内容都没有才标记 error；块级的 streaming/processing 状态一并落定，
/// 其中未完成的工具块标记为 error（结果已随进程一起丢失），避免重启后出现
/// 永远转圈的气泡。仅在该话题没有活跃流时调用。
Future<void> settleInterruptedMessages(
  ChatRepository repo,
  String topicId,
) async {
  try {
    final messages = await repo.getMessagesByTopicId(topicId);
    for (final message in messages) {
      if (message.status != MessageStatus.streaming) continue;
      final blocks = await repo.getMessageBlocksByMessageId(message.id);
      final settled = <MessageBlock>[
        for (final block in blocks)
          switch (block) {
            ToolBlock(status: MessageBlockStatus.processing) => block.copyWith(
              status: MessageBlockStatus.error,
              updatedAt: DateTime.now(),
              content: '应用在工具执行期间退出，本次调用的结果已丢失',
            ),
            _
                when block.status == MessageBlockStatus.streaming ||
                    block.status == MessageBlockStatus.processing ||
                    block.status == MessageBlockStatus.pending =>
              block.copyWith(
                status: MessageBlockStatus.success,
                updatedAt: DateTime.now(),
              ),
            _ => block,
          },
      ];
      final hasContent = settled.any(
        (b) =>
            (b is MainTextBlock && b.content.trim().isNotEmpty) ||
            (b is ThinkingBlock && b.content.trim().isNotEmpty) ||
            b is ToolBlock,
      );
      await persistMessageBlocks(
        repo,
        messageId: message.id,
        status: hasContent ? MessageStatus.success : MessageStatus.error,
        blocks: [
          for (final b in settled)
            if (b is! MainTextBlock || b.content.trim().isNotEmpty) b,
          if (!hasContent)
            MessageBlock.error(
              id: generateId('block'),
              messageId: message.id,
              status: MessageBlockStatus.error,
              createdAt: DateTime.now(),
              content: '',
              message: '回复在应用退出时被中断',
            ),
        ],
      );
    }
  } on Object catch (_) {
    // Recovery is best-effort; never block loading the conversation.
  }
}
