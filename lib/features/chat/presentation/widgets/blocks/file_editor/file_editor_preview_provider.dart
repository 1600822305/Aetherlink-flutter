import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// Reads the current text of an opaque workspace [path] for diff previews,
/// returning `null` when the file is absent (e.g. a not-yet-created file),
/// a directory, binary, or too large to preview.
///
/// Mirrors the editor's own binary/oversized guards so a `write_to_file`
/// preview never tries to decode a huge or non-text blob.
///
/// `autoDispose` keeps memory bounded — each unique path is read once, cached
/// while any diff card watches it, then held a little longer via a keepAlive
/// timer so scrolling a card out and back in doesn't re-read the file. With no
/// watchers the entry is finally evicted instead of leaking for the session.
final fileEditorCurrentContentProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, path) async {
  // Hold the cached read for a short window after the last watcher leaves.
  final link = ref.keepAlive();
  final timer = Timer(_cacheTtl, link.close);
  ref.onDispose(timer.cancel);

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

/// How long a preview read stays cached after its last watcher detaches.
const Duration _cacheTtl = Duration(minutes: 5);

/// Cap for diff-preview reads — larger files skip the old/new diff and show
/// the new content as an additive preview instead.
const int _previewMaxBytes = 256 * 1024;
