import 'package:json_annotation/json_annotation.dart';

/// Status of a whole [Message].
///
/// The original source splits this into `UserMessageStatus` and
/// `AssistantMessageStatus` (`Message.status` is their union). They are merged
/// here into one enum covering every wire value from both.
enum MessageStatus {
  @JsonValue('sending')
  sending,
  @JsonValue('pending')
  pending,
  @JsonValue('processing')
  processing,
  @JsonValue('searching')
  searching,
  @JsonValue('streaming')
  streaming,
  @JsonValue('success')
  success,
  @JsonValue('error')
  error,
  @JsonValue('paused')
  paused,
}
