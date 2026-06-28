// The capability-layer view of a workspace. Three implementations are
// planned (see docs/工作区与智能体模式-设计构想.md §2.3):
//
//   ① LocalSafBackend  — phone-local, Android SAF; canExec=false
//   ② TermuxBackend    — same-device Termux; canExec=true
//   ③ RemoteSshBackend — desktop / remote daemon; canExec=true, isRemote=true
//
// **Isolation rule** (docs/本地SAF工作区插件-方法规格.md §1): only
// `LocalSafBackend` is allowed to import `package:aetherlink_saf/...`.
// UI / chat / agent code depends on this file, never on the plugin directly.
// When we swap or rewrite the SAF plugin, the blast radius stays at one Dart
// file.

/// What a backend can do at runtime. UI / agent gates show or hide terminal
/// widgets, watcher subscriptions etc. based on this declaration.
class WorkspaceCapabilities {
  const WorkspaceCapabilities({
    required this.canExec,
    required this.canWatch,
    required this.isRemote,
  });

  /// Whether the backend can run shell commands (Termux / SSH yes, SAF no).
  final bool canExec;

  /// Whether the backend can stream file-change events. SAF has no
  /// inotify equivalent — always `false` on Android local.
  final bool canWatch;

  /// Whether the backend talks to another device. `true` opens up extra
  /// concerns: pairing, latency, auth tokens, etc.
  final bool isRemote;
}

/// A backend-neutral directory entry. Sourced from the plugin's `FileInfo`
/// but stripped of platform-specific fields (`permissions`, `mimeType`) so
/// the rest of the app never has to know about SAF.
class WorkspaceEntry {
  const WorkspaceEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.mtime,
    this.isHidden = false,
  });

  factory WorkspaceEntry.fromJson(Map<String, dynamic> json) => WorkspaceEntry(
        name: json['name'] as String,
        path: json['path'] as String,
        isDirectory: json['isDirectory'] as bool? ?? false,
        size: (json['size'] as num?)?.toInt() ?? 0,
        mtime: (json['mtime'] as num?)?.toInt() ?? 0,
        isHidden: json['isHidden'] as bool? ?? false,
      );

  final String name;

  /// Opaque identifier used to address this entry. For [LocalSafBackend]
  /// this is a `content://` URI; for SSH / Termux it'll be a posix path.
  /// **Treat as opaque** — never split on `/` or otherwise parse it.
  final String path;

  final bool isDirectory;
  final int size;
  final int mtime;
  final bool isHidden;

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'isDirectory': isDirectory,
        'size': size,
        'mtime': mtime,
        'isHidden': isHidden,
      };
}

/// A slice of a file read by line range (backend-neutral mirror of the
/// plugin's `ReadFileRangeResult`). [rangeHash] is the sha256 of just this
/// range's bytes; pass it back to [WorkspaceBackend.applyDiff] as the
/// optimistic-lock token along with [startLine] / [endLine].
class WorkspaceFileRange {
  const WorkspaceFileRange({
    required this.content,
    required this.totalLines,
    required this.startLine,
    required this.endLine,
    required this.rangeHash,
  });

  final String content;
  final int totalLines;
  final int startLine;
  final int endLine;
  final String rangeHash;
}

/// Outcome of [WorkspaceBackend.applyDiff] (backend-neutral mirror of the
/// plugin's `ApplyDiffResult`). [backupPath] is non-null only when the call
/// requested a backup.
class WorkspaceDiffResult {
  const WorkspaceDiffResult({
    required this.success,
    required this.linesChanged,
    required this.linesAdded,
    required this.linesDeleted,
    this.backupPath,
  });

  final bool success;
  final int linesChanged;
  final int linesAdded;
  final int linesDeleted;
  final String? backupPath;
}

/// Diff payload format for [WorkspaceBackend.applyDiff].
enum WorkspaceDiffFormat { searchReplace, unified }

/// What [WorkspaceBackend.searchFiles] matches against.
enum WorkspaceSearchType { name, content, both }

/// Backend interface — every workspace capability the rest of the app talks
/// to goes through this.
///
/// Methods that aren't supported on the current backend (`exec` on SAF,
/// `watch` everywhere for now, …) throw [UnsupportedError]; upstream code
/// should gate on [capabilities] before calling them. Write/edit/search
/// methods carry a default `UnsupportedError` implementation so read-only
/// backends (e.g. the mock) need not override them.
abstract class WorkspaceBackend {
  WorkspaceCapabilities get capabilities;

  /// Round-trips [value] through the backend's transport. Used to verify
  /// the underlying channel / connection is wired before doing real work.
  Future<String> echo(String value);

  /// Whether the persisted authorization for [path] is still valid. Backends
  /// with no permission model (mock / posix) return `true`. The SAF backend
  /// returns `false` when its `content://` grant was revoked or expired — the
  /// opaque path string is unchanged but no longer accessible — so management
  /// UI can surface a 「重新授权」 affordance without doing a full directory read.
  Future<bool> verifyAccess(String path) async => true;

  /// Lists the entries in [path]. Throws if [path] is a file or doesn't
  /// exist.
  Future<List<WorkspaceEntry>> listDir(String path);

  /// Reads [path] as UTF-8 text. Throws when the file is too large for a
  /// whole-file read (see plugin spec §3.3, 10 MB on Android); callers
  /// must fall back to a range read in that case.
  Future<String> readFile(String path);

  /// Reads lines `[startLine, endLine]` (1-based, inclusive) of [path].
  /// Use this when [readFile] would exceed the whole-file size cap.
  Future<WorkspaceFileRange> readFileRange(
    String path,
    int startLine,
    int endLine,
  ) =>
      throw UnsupportedError('readFileRange is not supported by this backend');

  /// Number of lines in [path].
  Future<int> getLineCount(String path) =>
      throw UnsupportedError('getLineCount is not supported by this backend');

  /// Metadata (name / size / mtime / kind) for the entry at [path], without
  /// having to list its parent. Throws when [path] doesn't exist.
  Future<WorkspaceEntry> getFileInfo(String path) =>
      throw UnsupportedError('getFileInfo is not supported by this backend');

  /// Reads up to [length] raw bytes of [path] starting at [offset] (defaults
  /// to the whole file). Unlike [readFile] this does no text decoding, so it's
  /// safe to use on binary content — e.g. sniffing a file's header to decide
  /// whether it's text before handing it to a text editor.
  Future<List<int>> readFileBytes(String path, {int offset = 0, int? length}) =>
      throw UnsupportedError('readFileBytes is not supported by this backend');

  // ===== mutations =====

  /// Overwrites (or, when [append], appends to) [path] with [content].
  Future<void> writeFile(String path, String content, {bool append = false}) =>
      throw UnsupportedError('writeFile is not supported by this backend');

  /// Creates a file named [name] under [parentPath], returning its opaque
  /// path. When [content] is null an empty file is created.
  Future<String> createFile(String parentPath, String name, {String? content}) =>
      throw UnsupportedError('createFile is not supported by this backend');

  /// Creates a directory named [name] under [parentPath], returning its
  /// opaque path.
  Future<String> createDirectory(
    String parentPath,
    String name, {
    bool recursive = false,
  }) =>
      throw UnsupportedError(
        'createDirectory is not supported by this backend',
      );

  /// Deletes the file or directory at [path]. For non-empty directories
  /// pass [recursive].
  Future<void> delete(
    String path, {
    bool isDirectory = false,
    bool recursive = false,
  }) =>
      throw UnsupportedError('delete is not supported by this backend');

  /// Renames the entry at [path] to [newName], returning its new opaque
  /// path.
  Future<String> rename(String path, String newName) =>
      throw UnsupportedError('rename is not supported by this backend');

  /// Moves the entry at [sourcePath] into [destinationParent], returning its
  /// new opaque path.
  Future<String> move(String sourcePath, String destinationParent) =>
      throw UnsupportedError('move is not supported by this backend');

  /// Copies the entry at [sourcePath] into [destinationParent], returning the
  /// copy's opaque path.
  Future<String> copy(
    String sourcePath,
    String destinationParent, {
    String? newName,
    bool overwrite = false,
  }) =>
      throw UnsupportedError('copy is not supported by this backend');

  /// Inserts [content] before 1-based [line] in [path].
  Future<void> insertContent(String path, int line, String content) =>
      throw UnsupportedError('insertContent is not supported by this backend');

  /// Replaces occurrences of [search] with [replace] in [path], returning the
  /// number of replacements made.
  Future<int> replaceInFile(
    String path,
    String search,
    String replace, {
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) =>
      throw UnsupportedError('replaceInFile is not supported by this backend');

  /// Applies [diff] to [path]. For optimistic locking pass the [rangeHash]
  /// from a prior [readFileRange] as [expectedRangeHash] together with the
  /// same [rangeStartLine] / [rangeEndLine]; the write is rejected if that
  /// range changed since it was read. Omit the range to lock against the
  /// whole file.
  Future<WorkspaceDiffResult> applyDiff(
    String path,
    String diff, {
    WorkspaceDiffFormat format = WorkspaceDiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
    int? rangeStartLine,
    int? rangeEndLine,
  }) =>
      throw UnsupportedError('applyDiff is not supported by this backend');

  /// Searches under [directory] for entries matching [query]. When [useRegex]
  /// is true, [query] is treated as a (case-insensitive) regular expression.
  Future<List<WorkspaceEntry>> searchFiles(
    String directory,
    String query, {
    WorkspaceSearchType searchType = WorkspaceSearchType.name,
    List<String> fileTypes = const [],
    int maxResults = 200,
    bool recursive = true,
    bool useRegex = false,
  }) =>
      throw UnsupportedError('searchFiles is not supported by this backend');
}
