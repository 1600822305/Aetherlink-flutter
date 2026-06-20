import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_content_image.freezed.dart';

/// An image part attached to an [LlmMessage] for multimodal (vision) requests.
///
/// [base64Data] is the raw base64 of the image bytes (no `data:` URI prefix);
/// each adapter wraps it in its provider's shape — OpenAI `image_url` data URL,
/// Anthropic `image` `source`, Gemini `inlineData`.
@freezed
abstract class LlmContentImage with _$LlmContentImage {
  const factory LlmContentImage({
    required String mimeType,
    required String base64Data,
  }) = _LlmContentImage;
}
