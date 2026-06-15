import 'package:json_annotation/json_annotation.dart';

/// Author of a [Message]. Mirrors the `role` literal union on the original
/// `Message` type (`src/shared/types/newMessage.ts`).
enum MessageRole {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('system')
  system,
}
