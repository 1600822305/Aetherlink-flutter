import 'package:json_annotation/json_annotation.dart';

/// Author of a [Message]. Mirrors the `role` literal union on the original
/// `Message` type (`src/shared/types/newMessage.ts`).
///
/// [root] is the message-tree虚拟根哨兵（`role='root'`, 无内容, 不渲染）——每个
/// 话题恰好一个，所有真实消息挂在它下面。它不在原 web 类型里，是树模型重构新增的
/// （见 `docs/design/message-tree-model-design.md`）。
enum MessageRole {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('system')
  system,
  @JsonValue('root')
  root,
}
