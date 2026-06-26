/// The capability boundary every workspace backend implements. The UI (file
/// tree, file viewer, future terminal) talks only to this interface and never
/// to a concrete backend, so the same screens work over local SAF, Termux or
/// SSH once those land.
///
/// P0 ships only [MockWorkspaceBackend] (fake in-memory tree) so the file-tree
/// UI can be built and reviewed before the real Android SAF plugin
/// (`aetherlink_saf`) exists. Swapping in the real backend later is just
/// providing a different [WorkspaceBackend] — no UI change.
abstract interface class WorkspaceBackend {
  /// Lists the immediate children of [path] (a directory). [path] is
  /// backend-specific (a `content://` document id for SAF, a filesystem path
  /// for Termux / SSH). The workspace root is listed with the empty string.
  Future<List<FileEntry>> listDir(String path);

  /// Reads a text file at [path]. Throws if it is not a readable text file.
  Future<String> readFile(String path);

  /// Whether this backend can run a terminal (`exec`). Local SAF cannot;
  /// Termux / SSH can. Drives whether the (future) terminal page is enabled.
  bool get supportsTerminal;
}

/// One entry inside a directory listing — a pure value object, no IO.
class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
  });

  /// File / folder name shown in the tree (last path segment).
  final String name;

  /// Backend-specific identifier passed back into [WorkspaceBackend.listDir] /
  /// [WorkspaceBackend.readFile].
  final String path;

  final bool isDirectory;

  /// File size in bytes, when known. Null for directories or unknown.
  final int? size;
}
