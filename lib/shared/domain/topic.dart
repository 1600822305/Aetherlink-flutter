import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic.freezed.dart';
part 'topic.g.dart';

/// A chat topic (conversation). Cross-feature entity (chat, topics,
/// assistants), hence `shared/domain`. Translation of `ChatTopic`
/// (`src/shared/types/index.ts`).
///
/// Dropped per `docs/DOMAIN_MODEL.md` §5: the `@deprecated` `messages` /
/// `title` fields. `lastMessageTime` stays a [String] (a free-form persisted
/// preview timestamp, per the doc).
///
/// [prompt] is the topic-level system prompt (话题提示词). The web `ChatTopic`
/// marks it `@deprecated`, but the 系统提示词气泡 / 系统提示词设置 feature still
/// reads and writes it (assistant prompt + topic prompt are combined at
/// display time), so it is kept here. The whole topic persists as a JSON blob
/// (`TopicConverter`), so this needs no Drift schema bump.
@freezed
abstract class Topic with _$Topic {
  const factory Topic({
    required String id,
    required String assistantId,
    required String name,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() required DateTime updatedAt,
    @Default(false) bool isNameManuallyEdited,
    @Default(<String>[]) List<String> messageIds,
    // 消息树模型（见 docs/design/message-tree-model-design.md）：当前选中的叶子，
    // 读取路径从它沿父链走到（不含）虚拟根。空话题为 null。话题本就整体存 JSON
    // blob，故无需 Drift schema 变更。PR-1 仅引入字段，回填与读取在后续 PR。
    String? activeNodeId,
    String? lastMessageTime,
    String? lastMessagePreview,
    String? inputTemplate,
    String? prompt,
    int? messageCount,
    int? tokenCount,
    bool? isDefault,
    @Default(false) bool pinned,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}
