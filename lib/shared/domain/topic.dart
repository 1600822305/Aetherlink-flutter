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
