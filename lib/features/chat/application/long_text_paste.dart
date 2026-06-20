import 'dart:convert';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';

/// `YYYYMMDDTHHMMSS` in UTC — the port of the web filename stamp
/// (`new Date().toISOString().slice(0, 19).replace(/[:-]/g, '')`).
String pasteFileTimestamp(DateTime now) {
  final u = now.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T'
      '${two(u.hour)}${two(u.minute)}${two(u.second)}';
}

/// The single contiguous run that [newText] adds over [oldText] under the
/// assumption of one edit (an insert/paste that may also have replaced a
/// selection), found by stripping the common prefix and suffix.
class TextInsertion {
  const TextInsertion({
    required this.inserted,
    required this.restored,
    required this.caret,
  });

  /// The added run (what was pasted/typed in this step).
  final String inserted;

  /// [oldText] with the run removed (the common prefix + suffix). For a paste
  /// over a selection this is the text with that selection dropped too.
  final String restored;

  /// The caret offset within [restored] right after the removed run.
  final int caret;
}

/// Detects the run [newText] inserts over [oldText]. Returns `null` when the
/// diff isn't insertion-shaped (e.g. a deletion / no growth), so callers can
/// ignore non-paste edits. Used as a catch-all paste detector for the mobile
/// paths that bypass both `PasteTextIntent` and `contextMenuBuilder` (e.g. the
/// IME clipboard chip, which commits text straight through the input
/// connection).
TextInsertion? detectInsertion(String oldText, String newText) {
  if (newText.length <= oldText.length) return null;
  var prefix = 0;
  while (prefix < oldText.length &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      oldText.codeUnitAt(oldText.length - 1 - suffix) ==
          newText.codeUnitAt(newText.length - 1 - suffix)) {
    suffix++;
  }
  final inserted = newText.substring(prefix, newText.length - suffix);
  if (inserted.isEmpty) return null;
  final restored =
      oldText.substring(0, prefix) + oldText.substring(oldText.length - suffix);
  return TextInsertion(inserted: inserted, restored: restored, caret: prefix);
}

/// The decision behind 长文本粘贴为文件 (pure port of
/// `LongTextPasteService.handleTextPaste`): returns a pending [ComposerAttachment]
/// when [enabled] and [text] is strictly longer than [threshold] characters,
/// else `null` (paste falls through to a normal insert).
///
/// [now] is injectable for deterministic file names in tests.
ComposerAttachment? convertPastedTextToAttachment({
  required String text,
  required bool enabled,
  required int threshold,
  DateTime? now,
}) {
  if (!enabled || text.length <= threshold) return null;
  return ComposerAttachment(
    id: generateId('file'),
    name: '粘贴的文本_${pasteFileTimestamp(now ?? DateTime.now())}.txt',
    mimeType: 'text/plain',
    size: utf8.encode(text).length,
    text: text,
  );
}
