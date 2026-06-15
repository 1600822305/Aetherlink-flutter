import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic.freezed.dart';
part 'topic.g.dart';

/// A chat topic (conversation). Cross-feature entity (chat, topics,
/// assistants), hence `shared/domain`. Translation of `ChatTopic`
/// (`src/shared/types/index.ts`).
///
/// Dropped per `docs/DOMAIN_MODEL.md` §5: the `@deprecated` `messages` /
/// `title` / `prompt` fields. `lastMessageTime` stays a [String] (a free-form
/// persisted preview timestamp, per the doc).
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
    int? messageCount,
    int? tokenCount,
    bool? isDefault,
    @Default(false) bool pinned,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}
