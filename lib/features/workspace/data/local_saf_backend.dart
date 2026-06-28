// LocalSafBackend — the **only** file in the app allowed to import the
// `aetherlink_saf` plugin (docs/本地SAF工作区插件-方法规格.md §1).
//
// Translates `WorkspaceBackend` calls into plugin calls and turns
// plugin-side `FileInfo` into the backend-neutral `WorkspaceEntry`.

import 'package:aetherlink_saf/aetherlink_saf.dart' as saf;

import '../domain/workspace_backend.dart';

class LocalSafBackend implements WorkspaceBackend {
  LocalSafBackend({saf.AetherlinkSaf? plugin})
      : _plugin = plugin ?? const saf.AetherlinkSaf();

  final saf.AetherlinkSaf _plugin;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        // SAF can't run shell commands.
        canExec: false,
        // SAF has no inotify equivalent (spec §3.4).
        canWatch: false,
        isRemote: false,
      );

  @override
  Future<String> echo(String value) async {
    final result = await _plugin.echo(value: value);
    return result.value;
  }

  @override
  Future<bool> verifyAccess(String path) async {
    final result = await _plugin.checkPermissions(uri: path);
    return result.granted;
  }

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    final result = await _plugin.listDirectory(path: path);
    return [for (final f in result.files) _toEntry(f)];
  }

  @override
  Future<String> readFile(String path) async {
    final result = await _plugin.readFile(path: path);
    return result.content;
  }

  @override
  Future<WorkspaceFileRange> readFileRange(
    String path,
    int startLine,
    int endLine,
  ) async {
    final r = await _plugin.readFileRange(
      path: path,
      startLine: startLine,
      endLine: endLine,
    );
    return WorkspaceFileRange(
      content: r.content,
      totalLines: r.totalLines,
      startLine: r.startLine,
      endLine: r.endLine,
      rangeHash: r.rangeHash,
    );
  }

  @override
  Future<int> getLineCount(String path) => _plugin.getLineCount(path: path);

  @override
  Future<WorkspaceEntry> getFileInfo(String path) async {
    final f = await _plugin.getFileInfo(path: path);
    return _toEntry(f);
  }

  @override
  Future<List<int>> readFileBytes(
    String path, {
    int offset = 0,
    int? length,
  }) =>
      _plugin.readFileBytes(path: path, offset: offset, length: length);

  @override
  Future<void> writeFile(String path, String content, {bool append = false}) =>
      _plugin.writeFile(path: path, content: content, append: append);

  @override
  Future<String> createFile(
    String parentPath,
    String name, {
    String? content,
  }) async {
    final r = await _plugin.createFile(
      parentPath: parentPath,
      name: name,
      content: content,
    );
    return r.path;
  }

  @override
  Future<String> createDirectory(
    String parentPath,
    String name, {
    bool recursive = false,
  }) async {
    final r = await _plugin.createDirectory(
      parentPath: parentPath,
      name: name,
      recursive: recursive,
    );
    return r.path;
  }

  @override
  Future<void> delete(
    String path, {
    bool isDirectory = false,
    bool recursive = false,
  }) =>
      isDirectory
          ? _plugin.deleteDirectory(path: path, recursive: recursive)
          : _plugin.deleteFile(path: path);

  @override
  Future<String> rename(String path, String newName) async {
    final r = await _plugin.renameFile(path: path, newName: newName);
    return r.path;
  }

  @override
  Future<String> move(String sourcePath, String destinationParent) async {
    final r = await _plugin.moveFile(
      sourcePath: sourcePath,
      destinationParent: destinationParent,
    );
    return r.path;
  }

  @override
  Future<String> copy(
    String sourcePath,
    String destinationParent, {
    String? newName,
    bool overwrite = false,
  }) async {
    final r = await _plugin.copyFile(
      sourcePath: sourcePath,
      destinationParent: destinationParent,
      newName: newName,
      overwrite: overwrite,
    );
    return r.path;
  }

  @override
  Future<void> insertContent(String path, int line, String content) =>
      _plugin.insertContent(path: path, line: line, content: content);

  @override
  Future<int> replaceInFile(
    String path,
    String search,
    String replace, {
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) async {
    final r = await _plugin.replaceInFile(
      path: path,
      search: search,
      replace: replace,
      isRegex: isRegex,
      replaceAll: replaceAll,
      caseSensitive: caseSensitive,
    );
    return r.replacements;
  }

  @override
  Future<WorkspaceDiffResult> applyDiff(
    String path,
    String diff, {
    WorkspaceDiffFormat format = WorkspaceDiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
    int? rangeStartLine,
    int? rangeEndLine,
  }) async {
    final r = await _plugin.applyDiff(
      path: path,
      diff: diff,
      format: _diffFormat(format),
      createBackup: createBackup,
      expectedRangeHash: expectedRangeHash,
      rangeStartLine: rangeStartLine,
      rangeEndLine: rangeEndLine,
    );
    return WorkspaceDiffResult(
      success: r.success,
      linesChanged: r.linesChanged,
      linesAdded: r.linesAdded,
      linesDeleted: r.linesDeleted,
      backupPath: r.backupPath,
    );
  }

  @override
  Future<List<WorkspaceEntry>> searchFiles(
    String directory,
    String query, {
    WorkspaceSearchType searchType = WorkspaceSearchType.name,
    List<String> fileTypes = const [],
    int maxResults = 200,
    bool recursive = true,
    bool useRegex = false,
  }) async {
    final r = await _plugin.searchFiles(
      directory: directory,
      query: query,
      searchType: _searchType(searchType),
      fileTypes: fileTypes,
      maxResults: maxResults,
      recursive: recursive,
      useRegex: useRegex,
    );
    return [for (final f in r.files) _toEntry(f)];
  }

  static WorkspaceEntry _toEntry(saf.FileInfo f) => WorkspaceEntry(
        name: f.name,
        path: f.path,
        isDirectory: f.type == saf.FileType.directory,
        size: f.size,
        mtime: f.mtime,
        isHidden: f.isHidden,
      );

  static saf.DiffFormat _diffFormat(WorkspaceDiffFormat f) => switch (f) {
        WorkspaceDiffFormat.searchReplace => saf.DiffFormat.searchReplace,
        WorkspaceDiffFormat.unified => saf.DiffFormat.unified,
      };

  static saf.SearchType _searchType(WorkspaceSearchType t) => switch (t) {
        WorkspaceSearchType.name => saf.SearchType.name,
        WorkspaceSearchType.content => saf.SearchType.content,
        WorkspaceSearchType.both => saf.SearchType.both,
      };

  /// Launches the system directory picker, persists the grant, and returns
  /// the picked root as a backend-neutral [PickedDirectory] (or `null` when
  /// the user cancels). SAF-specific, so it lives on the concrete backend
  /// rather than [WorkspaceBackend] — callers get a neutral type back, no
  /// `aetherlink_saf` types leak out (spec §1 isolation rule).
  Future<PickedDirectory?> pickDirectory() async {
    final result =
        await _plugin.openSystemFilePicker(type: saf.PickerType.directory);
    if (result.cancelled || result.directories.isEmpty) return null;
    final d = result.directories.first;
    return PickedDirectory(
      name: d.name,
      root: d.path,
      displayPath: d.displayPath,
    );
  }
}

/// A directory the user picked through the system SAF picker, stripped of all
/// `aetherlink_saf` types so callers (UI / store) can build a `Workspace`
/// without importing the plugin.
///
/// [root] is the opaque `content://` URI used to address the directory;
/// [displayPath] is a human-readable hint for the UI only (never pass it back
/// to any backend method).
class PickedDirectory {
  const PickedDirectory({
    required this.name,
    required this.root,
    this.displayPath,
  });

  final String name;
  final String root;
  final String? displayPath;
}
