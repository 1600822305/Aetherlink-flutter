import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';

/// A small extension→MIME table for the common types the pickers produce, used
/// when the plugin does not report a MIME type. Falls back to
/// `application/octet-stream`.
String mimeTypeForName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'heic' => 'image/heic',
    'svg' => 'image/svg+xml',
    'txt' || 'log' || 'csv' => 'text/plain',
    'md' || 'markdown' => 'text/markdown',
    'json' => 'application/json',
    'xml' => 'application/xml',
    'yaml' || 'yml' => 'application/yaml',
    'html' || 'htm' => 'text/html',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

/// Builds an image [ComposerAttachment] from picked [bytes] (raw base64,
/// rendered inline and sent as a vision image part).
ComposerAttachment imageAttachment({
  required String name,
  required Uint8List bytes,
  String? mimeType,
}) {
  final mime = mimeType ?? mimeTypeForName(name);
  return ComposerAttachment(
    id: generateId('file'),
    name: name,
    mimeType: mime.startsWith('image/') ? mime : 'image/jpeg',
    size: bytes.length,
    kind: ComposerAttachmentKind.image,
    base64Data: base64Encode(bytes),
  );
}

/// Builds a file [ComposerAttachment] from picked [bytes]. When the bytes decode
/// as UTF-8 text, it becomes a text attachment (so the model receives its
/// content like a pasted file); otherwise a binary file attachment carrying raw
/// base64 (stored + shown, not fed to the model).
ComposerAttachment fileAttachment({
  required String name,
  required Uint8List bytes,
  String? mimeType,
}) {
  final text = _tryDecodeUtf8Text(bytes);
  if (text != null) {
    return ComposerAttachment(
      id: generateId('file'),
      name: name,
      mimeType: 'text/plain',
      size: bytes.length,
      kind: ComposerAttachmentKind.text,
      text: text,
    );
  }
  return ComposerAttachment(
    id: generateId('file'),
    name: name,
    mimeType: mimeType ?? mimeTypeForName(name),
    size: bytes.length,
    kind: ComposerAttachmentKind.file,
    base64Data: base64Encode(bytes),
  );
}

/// Decodes [bytes] as UTF-8 text, or `null` when they are empty, contain a NUL
/// byte (a strong binary signal), or are not valid UTF-8.
String? _tryDecodeUtf8Text(Uint8List bytes) {
  if (bytes.isEmpty || bytes.contains(0)) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}
