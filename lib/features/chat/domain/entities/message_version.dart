import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_version.freezed.dart';
part 'message_version.g.dart';

/// A saved version of a message (regenerate / edit history). Mirrors
/// `MessageVersion` (`src/shared/types/newMessage.ts`). `blocks` holds block
/// ids in display order.
@freezed
abstract class MessageVersion with _$MessageVersion {
  const factory MessageVersion({
    required String id,
    required String messageId,
    @Default(<String>[]) List<String> blocks,
    @IsoDateTimeConverter() required DateTime createdAt,
    String? modelId,
    Model? model,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) = _MessageVersion;

  factory MessageVersion.fromJson(Map<String, dynamic> json) =>
      _$MessageVersionFromJson(json);
}
