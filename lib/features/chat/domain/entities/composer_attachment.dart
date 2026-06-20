import 'package:freezed_annotation/freezed_annotation.dart';

part 'composer_attachment.freezed.dart';

/// What a pending [ComposerAttachment] carries, which decides how it is sent:
/// - [text] — text content (pasted long text or a decoded text file); sent as a
///   `text/plain` FILE block and its text appended to the request.
/// - [image] — image bytes; sent as an `IMAGE` block and as a vision image part.
/// - [file] — non-text binary bytes; sent as a FILE block (model does not read
///   its content).
enum ComposerAttachmentKind { text, image, file }

/// A pending composer attachment held in memory before the message is sent —
/// the port of the original input box's staged `FileContent`.
///
/// Created from long pasted text, a picked file, or a picked/captured image; on
/// send each becomes a `FILE` or `IMAGE` message block. It is a pure value
/// object: no disk file is written, the payload rides in memory ([text] for
/// text kinds, [base64Data] — raw base64 of the bytes — for image/file kinds)
/// and, on send, as the block's inline data.
@freezed
abstract class ComposerAttachment with _$ComposerAttachment {
  const factory ComposerAttachment({
    required String id,
    required String name,
    required String mimeType,
    required int size,
    required ComposerAttachmentKind kind,
    String? text,
    String? base64Data,
  }) = _ComposerAttachment;
}
