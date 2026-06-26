import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// Reads the current text of an opaque workspace [path] for diff previews,
/// returning `null` when the file is absent (e.g. a not-yet-created file),
/// a directory, binary, or too large to preview.
///
/// Mirrors the editor's own binary/oversized guards so a `write_to_file`
/// preview never tries to decode a huge or non-text blob.
final fileEditorCurrentContentProvider =
    FutureProvider.family<String?, String>((ref, path) async {
  try {
    final backend = await backendForPath(ref, path);
    final info = await backend.getFileInfo(path);
    if (info.isDirectory) return null;
    if (info.size > _previewMaxBytes) return null;
    return await backend.readFile(path);
  } catch (_) {
    return null;
  }
});

/// Cap for diff-preview reads — larger files skip the old/new diff and show
/// the new content as an additive preview instead.
const int _previewMaxBytes = 256 * 1024;
