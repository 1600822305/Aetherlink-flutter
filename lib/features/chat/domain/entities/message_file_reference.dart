import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_file_reference.freezed.dart';
part 'message_file_reference.g.dart';

/// The inline `file?` object that the original image / video / file blocks each
/// repeated identically (`src/shared/types/newMessage.ts`). Extracted into a
/// single shared value object instead of being duplicated per block.
@freezed
abstract class MessageFileReference with _$MessageFileReference {
  const factory MessageFileReference({
    required String id,
    required String name,
    @JsonKey(name: 'origin_name') required String originName,
    required int size,
    required String mimeType,
    String? base64Data,
    String? type,
  }) = _MessageFileReference;

  factory MessageFileReference.fromJson(Map<String, dynamic> json) =>
      _$MessageFileReferenceFromJson(json);
}
