part of 'terminal.dart';

/// Accumulates text for an in-progress iTerm2 clipboard capture (the
/// `OSC 1337 CopyToClipboard=<selector>` / `OSC 1337 EndCopy` pair), bounded
/// by [_maxLength].
///
/// A capture is "overflowed" once the accumulated text would exceed
/// [_maxLength]; from that point on, further characters/text ranges are
/// silently dropped and [end] reports nothing to store, matching the
/// original inline behavior on [Terminal].
class _ClipboardCapture {
  static const _maxLength = 10 * 1024 * 1024;

  String? _selector;
  StringBuffer? _buffer;
  bool _overflowed = false;

  void start(String selector) {
    _selector = _resolveITerm2ClipboardSelector(selector);
    _buffer = StringBuffer();
    _overflowed = false;
  }

  /// Ends the capture and returns the selector/text to store, or `null` if
  /// there is nothing to store (no capture was active, or it overflowed).
  ({String selector, String text})? end() {
    final selector = _selector;
    final buffer = _buffer;
    final overflowed = _overflowed;
    _selector = null;
    _buffer = null;
    _overflowed = false;

    if (selector == null || buffer == null || overflowed) return null;
    return (selector: selector, text: buffer.toString());
  }

  void captureChar(int codePoint) {
    final buffer = _buffer;
    if (buffer == null || _overflowed) return;

    final length = switch (codePoint > 0xffff) {
      true => 2,
      false => 1,
    };
    if (buffer.length + length > _maxLength) {
      _buffer = null;
      _overflowed = true;
      return;
    }
    buffer.writeCharCode(codePoint);
  }

  void captureTextRange(String text, int start, int end) {
    final buffer = _buffer;
    if (buffer == null || _overflowed) return;

    if (buffer.length + end - start > _maxLength) {
      _buffer = null;
      _overflowed = true;
      return;
    }

    if (start == 0 && end == text.length) {
      buffer.write(text);
      return;
    }
    buffer.write(text.substring(start, end));
  }

  /// Discards any in-progress capture without storing it. Used by
  /// [Terminal.reset], [Terminal.dispose], and similar.
  void reset() {
    _selector = null;
    _buffer = null;
    _overflowed = false;
  }
}
