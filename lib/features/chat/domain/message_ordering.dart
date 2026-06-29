import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';

/// Deterministic chronological ordering for a topic's messages.
///
/// Orders by [Message.createdAt], breaking ties with [Message.id] so the result
/// is **stable and reproducible**. `generateId` embeds a microsecond timestamp,
/// so the id tiebreak still roughly preserves creation order.
///
/// This matters because Dart's `List.sort` is *not* stable: sorting solely on
/// `createdAt` leaves messages that share a timestamp in an arbitrary, run-to-run
/// order. The chat view and 创建分支 each sort the topic's messages
/// independently, so on a timestamp tie they could disagree — and the branch
/// would then be cut at a different message than the one selected on screen
/// (most visible in long / imported histories, where many messages carry the
/// same timestamp). Sorting both through this comparator keeps them aligned.
int compareMessagesChronologically(Message a, Message b) {
  final byTime = a.createdAt.compareTo(b.createdAt);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}
