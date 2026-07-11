// Cross-widget glue for the multi-tab editor.
//
// Each open file is a live [FileEditor] kept in an IndexedStack, so its dirty
// state and a save/discard hook live inside that widget — but the tab strip
// (dirty dots) and the close-tab handler sit outside it. These two providers
// bridge that gap:
//   * [dirtyFilesProvider] — the set of open file paths with unsaved edits, so
//     the tab strip can show a dirty dot.
//   * [editorRegistryProvider] — a handle registry letting the close handler
//     save/discard a tab whose editor isn't the visible one.
//   * [editorJumpProvider] — a one-shot 「跳到某行」 request (全局搜索结果点击),
//     consumed by the target file's editor once it has loaded.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Save/discard hooks an editor exposes so its tab can be closed from outside.
class EditorHandle {
  const EditorHandle({required this.save, required this.discard});

  /// Persists the file; returns `true` on success.
  final Future<bool> Function() save;

  /// Drops unsaved edits (clears the dirty flag without writing).
  final void Function() discard;
}

/// Live registry of per-path editor handles. Plain mutable holder (not a
/// Notifier) since nothing rebuilds on it — the close handler just reads it.
class EditorRegistry {
  final Map<String, EditorHandle> _handles = {};

  void register(String path, EditorHandle handle) => _handles[path] = handle;

  void unregister(String path) => _handles.remove(path);

  EditorHandle? operator [](String path) => _handles[path];
}

final editorRegistryProvider = Provider<EditorRegistry>((ref) {
  return EditorRegistry();
});

/// The set of open files with unsaved edits, watched by the tab strip.
final dirtyFilesProvider = NotifierProvider<DirtyFiles, Set<String>>(
  DirtyFiles.new,
);

class DirtyFiles extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void set(String path, {required bool dirty}) {
    final has = state.contains(path);
    if (dirty == has) return;
    final next = {...state};
    if (dirty) {
      next.add(path);
    } else {
      next.remove(path);
    }
    state = next;
  }

  void clear(String path) => set(path, dirty: false);
}

/// A pending 「打开到指定行」 request ([line] is 1-based). Set alongside
/// opening the tab; the matching [path]'s editor consumes and clears it.
class EditorJumpRequest {
  const EditorJumpRequest(this.path, this.line);

  final String path;
  final int line;
}

final editorJumpProvider = NotifierProvider<EditorJump, EditorJumpRequest?>(
  EditorJump.new,
);

class EditorJump extends Notifier<EditorJumpRequest?> {
  @override
  EditorJumpRequest? build() => null;

  void request(String path, int line) => state = EditorJumpRequest(path, line);

  void clear() => state = null;
}
