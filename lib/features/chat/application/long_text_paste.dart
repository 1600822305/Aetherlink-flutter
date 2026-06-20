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
