import 'package:freezed_annotation/freezed_annotation.dart';

part 'composer_attachment.freezed.dart';

/// A pending composer attachment held in memory before the message is sent —
/// the port of the original `LongTextPasteService`'s converted `FileContent`
/// while it sits in the input box.
///
/// Currently only long pasted text is turned into one of these (a `.txt`
/// carrying the pasted [text]); on send each becomes a `FILE` message block.
/// It is a pure value object: no disk file is written for this slice, the text
/// rides along in memory and, on send, as the block's base64 data.
@freezed
abstract class ComposerAttachment with _$ComposerAttachment {
  const factory ComposerAttachment({
    required String id,
    required String name,
    required String mimeType,
    required int size,
    required String text,
  }) = _ComposerAttachment;
}
