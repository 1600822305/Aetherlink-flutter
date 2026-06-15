import 'package:json_annotation/json_annotation.dart';

/// Lifecycle status of a single message block. Wire values mirror the original
/// `MessageBlockStatus` (`src/shared/types/newMessage.ts`).
enum MessageBlockStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('processing')
  processing,
  @JsonValue('streaming')
  streaming,
  @JsonValue('success')
  success,
  @JsonValue('error')
  error,
  @JsonValue('paused')
  paused,
}

/// Terminal statuses: once a stream ends a block must land in one of these
/// (the "finalization invariant" / timer-freeze rule). Mirrors
/// `TERMINAL_BLOCK_STATUSES` in the original source.
const Set<MessageBlockStatus> kTerminalBlockStatuses = {
  MessageBlockStatus.success,
  MessageBlockStatus.error,
  MessageBlockStatus.paused,
};
