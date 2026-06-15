import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant_chat_background.freezed.dart';
part 'assistant_chat_background.g.dart';

/// Per-assistant chat wallpaper override. Mirrors the inline `chatBackground`
/// object on `Assistant` (`src/shared/types/Assistant.ts`).
@freezed
abstract class AssistantChatBackground with _$AssistantChatBackground {
  const factory AssistantChatBackground({
    required bool enabled,
    required String imageUrl,
    double? opacity,
    String? size,
    String? position,
    String? repeat,
    bool? showOverlay,
  }) = _AssistantChatBackground;

  factory AssistantChatBackground.fromJson(Map<String, dynamic> json) =>
      _$AssistantChatBackgroundFromJson(json);
}
