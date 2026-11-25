part of 'terminal.dart';

/// Paste-payload safety checks and sanitization.
///
/// These are library-level functions rather than [Terminal] members because
/// they are pure string transforms: none of them read or write terminal
/// state. [Terminal.paste] and [Terminal.isPasteSafe] are the public entry
/// points.

const _pasteControlReplacements = {
  0x00, // NUL
  0x03, // VINTR / Ctrl+C
  0x04, // EOT
  0x05, // ENQ
  0x08, // BS
  0x0f, // VDISCARD / Ctrl+O
  0x11, // VSTART / Ctrl+Q
  0x12, // VREPRINT / Ctrl+R
  0x13, // VSTOP / Ctrl+S
  0x15, // VKILL / Ctrl+U
  0x16, // VLNEXT / Ctrl+V
  0x17, // VWERASE / Ctrl+W
  0x1a, // VSUSP / Ctrl+Z
  0x1b, // ESC
  0x1c, // VQUIT / Ctrl+\
  0x7f, // DEL
};

final _pasteLineBreak = RegExp(r'\r\n?|\n');

bool _isPasteSafe(String text) {
  if (text.contains('\n') || text.contains('\r')) return false;
  if (text.contains('\x1b[201~')) return false;
  for (final codePoint in text.runes) {
    if (codePoint == 0x09) continue;
    if (codePoint < 0x20) return false;
    if (codePoint == 0x7f) return false;
    if (codePoint >= 0x80 && codePoint <= 0x9f) return false;
  }
  return true;
}

String _sanitizePasteText(String text) {
  if (!_pasteNeedsSanitization(text)) return text;

  final sanitized = StringBuffer();
  var copyStart = 0;
  var index = 0;
  while (index < text.length) {
    final codeUnit = text.codeUnitAt(index);
    if (codeUnit == 0x1b) {
      sanitized.write(text.substring(copyStart, index));
      index = _skipPastedEscapeSequence(text, index) + 1;
      copyStart = index;
      continue;
    }
    if (_shouldReplacePastedControl(codeUnit)) {
      sanitized.write(text.substring(copyStart, index));
      sanitized.writeCharCode(0x20);
      index++;
      copyStart = index;
      continue;
    }
    index++;
  }

  sanitized.write(text.substring(copyStart));
  return sanitized.toString();
}

bool _pasteNeedsSanitization(String text) {
  for (final codeUnit in text.codeUnits) {
    if (_shouldReplacePastedControl(codeUnit)) return true;
  }
  return false;
}

bool _shouldReplacePastedControl(int codePoint) {
  if (_pasteControlReplacements.contains(codePoint)) return true;
  return codePoint >= 0x80 && codePoint <= 0x9f;
}

int _skipPastedEscapeSequence(String text, int escapeIndex) {
  final nextIndex = escapeIndex + 1;
  if (nextIndex >= text.length) return escapeIndex;

  final next = text.codeUnitAt(nextIndex);
  if (next == 0x5b) {
    return _skipPastedCsiSequence(text, nextIndex);
  }
  if (next == 0x5d) {
    return _skipPastedOscSequence(text, nextIndex);
  }
  if (next == 0x50 || next == 0x5e || next == 0x5f) {
    return _skipPastedStringControl(text, nextIndex);
  }
  if (_isHighSurrogate(next) &&
      nextIndex + 1 < text.length &&
      _isLowSurrogate(text.codeUnitAt(nextIndex + 1))) {
    return nextIndex + 1;
  }

  return nextIndex;
}

bool _isHighSurrogate(int codeUnit) {
  return codeUnit >= 0xd800 && codeUnit <= 0xdbff;
}

bool _isLowSurrogate(int codeUnit) {
  return codeUnit >= 0xdc00 && codeUnit <= 0xdfff;
}

int _skipPastedCsiSequence(String text, int csiIndex) {
  for (var index = csiIndex + 1; index < text.length; index++) {
    final codeUnit = text.codeUnitAt(index);
    if (codeUnit >= 0x40 && codeUnit <= 0x7e) return index;
  }
  return text.length - 1;
}

int _skipPastedOscSequence(String text, int oscIndex) {
  for (var index = oscIndex + 1; index < text.length; index++) {
    final codeUnit = text.codeUnitAt(index);
    if (codeUnit == 0x07) return index;
    if (codeUnit == 0x1b &&
        index + 1 < text.length &&
        text.codeUnitAt(index + 1) == 0x5c) {
      return index + 1;
    }
  }
  return text.length - 1;
}

int _skipPastedStringControl(String text, int controlIndex) {
  for (var index = controlIndex + 1; index < text.length; index++) {
    if (text.codeUnitAt(index) == 0x1b &&
        index + 1 < text.length &&
        text.codeUnitAt(index + 1) == 0x5c) {
      return index + 1;
    }
  }
  return text.length - 1;
}
