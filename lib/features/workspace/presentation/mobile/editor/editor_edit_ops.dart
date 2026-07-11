// 编辑态输入的纯逻辑：多行缩进/反缩进、括号引号自动闭合、括号匹配查找。
// 只依赖 flutter/services（TextEditingValue/TextInputFormatter），不含任何
// 移动端 UI，桌面端编辑器可直接复用。

import 'package:flutter/services.dart';

/// Spaces inserted per indent level (matches the Tab key / auto-indent unit).
const String kIndentUnit = '  ';

/// Indents (or dedents) every line touched by the selection by [kIndentUnit],
/// preserving the selection over the same text. A dedent removes up to one
/// indent unit (or a single leading tab) per line. Collapsed selections
/// operate on the caret's line.
TextEditingValue indentLines(TextEditingValue value, {bool dedent = false}) {
  final text = value.text;
  final sel = value.selection;
  if (!sel.isValid) return value;
  final selStart = sel.start;
  final selEnd = sel.end;
  // A selection ending exactly at a line start doesn't include that line.
  final effEnd =
      (selEnd > selStart && selEnd > 0 && text.codeUnitAt(selEnd - 1) == 0x0A)
          ? selEnd - 1
          : selEnd;
  final regionStart =
      selStart == 0 ? 0 : text.lastIndexOf('\n', selStart - 1) + 1;
  final endNl = effEnd < text.length ? text.indexOf('\n', effEnd) : -1;
  final regionEnd = endNl < 0 ? text.length : endNl;

  final buf = StringBuffer();
  var newStart = selStart;
  var newEnd = selEnd;
  var lineStart = regionStart;
  while (true) {
    final lineNl = text.indexOf('\n', lineStart);
    final lineEnd = (lineNl < 0 || lineNl > regionEnd) ? regionEnd : lineNl;
    final line = text.substring(lineStart, lineEnd);
    if (dedent) {
      var remove = 0;
      if (line.startsWith('\t')) {
        remove = 1;
      } else {
        while (remove < kIndentUnit.length &&
            remove < line.length &&
            line[remove] == ' ') {
          remove++;
        }
      }
      buf.write(line.substring(remove));
      if (remove > 0) {
        newStart -= _removedBefore(selStart, lineStart, remove);
        newEnd -= _removedBefore(selEnd, lineStart, remove);
      }
    } else {
      if (line.isNotEmpty) {
        buf.write(kIndentUnit);
        if (selStart >= lineStart) newStart += kIndentUnit.length;
        if (selEnd >= lineStart) newEnd += kIndentUnit.length;
      }
      buf.write(line);
    }
    if (lineEnd >= regionEnd) break;
    buf.write('\n');
    lineStart = lineEnd + 1;
  }

  final newText =
      text.substring(0, regionStart) + buf.toString() + text.substring(regionEnd);
  if (newText == text) return value;
  newStart = newStart.clamp(0, newText.length);
  newEnd = newEnd.clamp(0, newText.length);
  final forward = sel.baseOffset <= sel.extentOffset;
  return TextEditingValue(
    text: newText,
    selection: TextSelection(
      baseOffset: forward ? newStart : newEnd,
      extentOffset: forward ? newEnd : newStart,
    ),
  );
}

// How much of a removal of [removed] chars at [lineStart] lands before
// [offset] (i.e. how far the offset shifts left).
int _removedBefore(int offset, int lineStart, int removed) {
  if (offset <= lineStart) return 0;
  final d = offset - lineStart;
  return d < removed ? d : removed;
}

/// Auto-closes brackets and quotes as they are typed:
/// * typing an opener inserts the matching closer and keeps the caret between
///   them (quotes skip this next to word characters / another quote, so
///   apostrophes stay usable);
/// * typing a closer that is already the next character skips over it instead
///   of doubling it;
/// * typing an opener with text selected wraps the selection in the pair;
/// * backspacing an empty pair removes both characters.
class AutoClosePairsFormatter extends TextInputFormatter {
  const AutoClosePairsFormatter();

  static const Map<String, String> _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
  };
  static const Set<String> _closers = {')', ']', '}'};
  static const Set<String> _quotes = {'"', "'"};

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldSel = oldValue.selection;
    final newSel = newValue.selection;
    if (!oldSel.isValid || !newSel.isValid || !newSel.isCollapsed) {
      return newValue;
    }
    // Never touch an active IME composition (CJK input).
    if (newValue.composing.isValid) return newValue;

    final oldText = oldValue.text;
    final newText = newValue.text;
    final selLen = oldSel.end - oldSel.start;

    // --- single-character insertion (replacing the selection, if any) ---
    if (newText.length == oldText.length - selLen + 1 &&
        newSel.baseOffset == oldSel.start + 1 &&
        newText.startsWith(oldText.substring(0, oldSel.start)) &&
        newText.endsWith(oldText.substring(oldSel.end))) {
      final ch = newText[oldSel.start];

      // Wrap a non-empty selection in the typed pair.
      final closer = _pairs[ch];
      if (closer != null && selLen > 0) {
        final selected = oldText.substring(oldSel.start, oldSel.end);
        return TextEditingValue(
          text: oldText.replaceRange(
            oldSel.start,
            oldSel.end,
            '$ch$selected$closer',
          ),
          selection: TextSelection(
            baseOffset: oldSel.start + 1,
            extentOffset: oldSel.end + 1,
          ),
        );
      }

      if (selLen == 0) {
        final caret = oldSel.start;
        final next = caret < oldText.length ? oldText[caret] : '';

        // Skip over an existing closer / closing quote instead of doubling it.
        if ((_closers.contains(ch) || _quotes.contains(ch)) && next == ch) {
          return TextEditingValue(
            text: oldText,
            selection: TextSelection.collapsed(offset: caret + 1),
          );
        }

        // Insert the matching closer after the caret.
        if (closer != null) {
          if (_quotes.contains(ch)) {
            final prev = caret > 0 ? oldText[caret - 1] : '';
            if (_isWordChar(prev) || _quotes.contains(prev)) return newValue;
            if (_isWordChar(next)) return newValue;
          }
          return TextEditingValue(
            text: newText.replaceRange(caret + 1, caret + 1, closer),
            selection: TextSelection.collapsed(offset: caret + 1),
          );
        }
      }
      return newValue;
    }

    // --- backspace deleting the opener of an empty pair: drop the closer too ---
    if (selLen == 0 &&
        newText.length == oldText.length - 1 &&
        newSel.baseOffset == oldSel.start - 1) {
      final deletedAt = newSel.baseOffset;
      final deleted = oldText[deletedAt];
      final closer = _pairs[deleted];
      if (closer != null &&
          deletedAt + 1 < oldText.length &&
          oldText[deletedAt + 1] == closer) {
        return TextEditingValue(
          text: newText.replaceRange(deletedAt, deletedAt + 1, ''),
          selection: TextSelection.collapsed(offset: deletedAt),
        );
      }
    }
    return newValue;
  }

  static bool _isWordChar(String c) {
    if (c.isEmpty) return false;
    final u = c.codeUnitAt(0);
    return (u >= 0x30 && u <= 0x39) ||
        (u >= 0x41 && u <= 0x5A) ||
        (u >= 0x61 && u <= 0x7A) ||
        u == 0x5F;
  }
}

const String _openBrackets = '([{';
const String _closeBrackets = ')]}';

/// The bracket pair the caret touches: checks the char before the caret then
/// the one at it; scans (with nesting, up to [maxScan] chars) for the match.
/// Returns `(open, close)` offsets, or null when the caret isn't on a bracket
/// or the match isn't found. String/comment contexts are not excluded.
({int open, int close})? matchBracketAt(
  String text,
  int caret, {
  int maxScan = 200000,
}) {
  int? pos;
  if (caret > 0 && _isBracket(text[caret - 1])) {
    pos = caret - 1;
  } else if (caret >= 0 && caret < text.length && _isBracket(text[caret])) {
    pos = caret;
  }
  if (pos == null) return null;
  final ch = text[pos];
  final oi = _openBrackets.indexOf(ch);
  if (oi >= 0) {
    final closeCh = _closeBrackets[oi];
    var depth = 0;
    final limit =
        (pos + maxScan) < text.length ? (pos + maxScan) : text.length;
    for (var i = pos; i < limit; i++) {
      final c = text[i];
      if (c == ch) {
        depth++;
      } else if (c == closeCh) {
        depth--;
        if (depth == 0) return (open: pos, close: i);
      }
    }
    return null;
  }
  final ci = _closeBrackets.indexOf(ch);
  final openCh = _openBrackets[ci];
  var depth = 0;
  final limit = (pos - maxScan) > 0 ? (pos - maxScan) : 0;
  for (var i = pos; i >= limit; i--) {
    final c = text[i];
    if (c == ch) {
      depth++;
    } else if (c == openCh) {
      depth--;
      if (depth == 0) return (open: i, close: pos);
    }
  }
  return null;
}

bool _isBracket(String c) =>
    _openBrackets.contains(c) || _closeBrackets.contains(c);
