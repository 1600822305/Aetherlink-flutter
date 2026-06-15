import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// A chat message. One-to-one translation of `Message`
/// (`src/shared/types/newMessage.ts`). `blocks` holds block ids in order; the
/// blocks themselves live in their own store. `status` merges the original
/// user/assistant status unions into [MessageStatus].
@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    required MessageRole role,
    required String assistantId,
    required String topicId,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    required MessageStatus status,
    String? modelId,
    Model? model,
    String? type,
    bool? isPreset,
    bool? useful,
    String? askId,
    List<Model>? mentions,
    Usage? usage,
    Metrics? metrics,
    @Default(<String>[]) List<String> blocks,
    List<MessageVersion>? versions,
    String? currentVersionId,
    Map<String, dynamic>? metadata,
    MultiModelMessageStyle? multiModelMessageStyle,
    bool? foldSelected,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
