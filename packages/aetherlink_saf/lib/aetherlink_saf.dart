/// Aetherlink local Android SAF workspace plugin.
///
/// Implements the contract in `docs/本地SAF工作区插件-方法规格.md`.
///
/// **Isolation rule** (spec §1): only `LocalSafBackend` (under
/// `lib/features/workspace/data/`) is allowed to import this package
/// directly. UI / chat / agent code must depend on `WorkspaceBackend`
/// instead, so the day we swap or rewrite this plugin, the blast radius
/// is one Dart file.
library;

export 'aetherlink_saf_platform_interface.dart' show AetherlinkSafPlatform;
export 'src/models.dart';

import 'dart:typed_data';

import 'aetherlink_saf_platform_interface.dart';
import 'src/models.dart';

/// Thin facade over [AetherlinkSafPlatform.instance]. Every method forwards
/// straight through; signatures mirror the spec doc so adding a new method
/// is a copy-paste here.
class AetherlinkSaf {
  const AetherlinkSaf();

  AetherlinkSafPlatform get _p => AetherlinkSafPlatform.instance;

  // ===== P0 =====

  Future<EchoResult> echo({required String value}) => _p.echo(value: value);

  Future<PermissionResult> requestPermissions() => _p.requestPermissions();

  Future<PermissionResult> checkPermissions({String? uri}) =>
      _p.checkPermissions(uri: uri);

  Future<List<SelectedFileInfo>> listPersistedPermissions() =>
      _p.listPersistedPermissions();

  Future<void> releasePersistableUriPermission({required String uri}) =>
      _p.releasePersistableUriPermission(uri: uri);

  Future<PickerResult> openSystemFilePicker({
    required PickerType type,
    bool multiple = false,
    List<String>? accept,
    String? startDirectory,
    String? title,
  }) =>
      _p.openSystemFilePicker(
        type: type,
        multiple: multiple,
        accept: accept,
        startDirectory: startDirectory,
        title: title,
      );

  Future<ListDirectoryResult> listDirectory({
    required String path,
    bool showHidden = false,
    FileSortBy sortBy = FileSortBy.byName,
    FileSortOrder sortOrder = FileSortOrder.asc,
  }) =>
      _p.listDirectory(
        path: path,
        showHidden: showHidden,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

  Future<ReadFileResult> readFile({
    required String path,
    String encoding = 'utf8',
  }) =>
      _p.readFile(path: path, encoding: encoding);

  Future<FileInfo> getFileInfo({required String path}) =>
      _p.getFileInfo(path: path);

  Future<bool> exists({required String path}) => _p.exists(path: path);

  // ===== P1: write & structure operations =====

  Future<void> writeFile({
    required String path,
    required String content,
    String encoding = 'utf8',
    bool append = false,
  }) =>
      _p.writeFile(
        path: path,
        content: content,
        encoding: encoding,
        append: append,
      );

  Future<PathResult> createFile({
    required String parentPath,
    required String name,
    String? content,
    String encoding = 'utf8',
    String? mimeType,
  }) =>
      _p.createFile(
        parentPath: parentPath,
        name: name,
        content: content,
        encoding: encoding,
        mimeType: mimeType,
      );

  Future<PathResult> createDirectory({
    required String parentPath,
    required String name,
    bool recursive = false,
  }) =>
      _p.createDirectory(
        parentPath: parentPath,
        name: name,
        recursive: recursive,
      );

  Future<void> deleteFile({required String path}) => _p.deleteFile(path: path);

  Future<void> deleteDirectory({required String path, bool recursive = false}) =>
      _p.deleteDirectory(path: path, recursive: recursive);

  Future<PathResult> renameFile({
    required String path,
    required String newName,
  }) =>
      _p.renameFile(path: path, newName: newName);

  Future<PathResult> moveFile({
    required String sourcePath,
    required String destinationParent,
  }) =>
      _p.moveFile(
        sourcePath: sourcePath,
        destinationParent: destinationParent,
      );

  Future<PathResult> copyFile({
    required String sourcePath,
    required String destinationParent,
    String? newName,
    bool overwrite = false,
  }) =>
      _p.copyFile(
        sourcePath: sourcePath,
        destinationParent: destinationParent,
        newName: newName,
        overwrite: overwrite,
      );

  // ===== P1: advanced reads =====

  Future<ReadFileRangeResult> readFileRange({
    required String path,
    required int startLine,
    required int endLine,
    String? encoding,
  }) =>
      _p.readFileRange(
        path: path,
        startLine: startLine,
        endLine: endLine,
        encoding: encoding,
      );

  Future<Uint8List> readFileBytes({
    required String path,
    int? offset,
    int? length,
  }) =>
      _p.readFileBytes(path: path, offset: offset, length: length);

  Future<int> getLineCount({required String path}) =>
      _p.getLineCount(path: path);

  Future<FileHashResult> getFileHash({
    required String path,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) =>
      _p.getFileHash(path: path, algorithm: algorithm);

  // ===== P2: advanced editing =====

  Future<void> insertContent({
    required String path,
    required int line,
    required String content,
  }) =>
      _p.insertContent(path: path, line: line, content: content);

  Future<ReplaceResult> replaceInFile({
    required String path,
    required String search,
    required String replace,
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) =>
      _p.replaceInFile(
        path: path,
        search: search,
        replace: replace,
        isRegex: isRegex,
        replaceAll: replaceAll,
        caseSensitive: caseSensitive,
      );

  Future<ApplyDiffResult> applyDiff({
    required String path,
    required String diff,
    DiffFormat format = DiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
  }) =>
      _p.applyDiff(
        path: path,
        diff: diff,
        format: format,
        createBackup: createBackup,
        expectedRangeHash: expectedRangeHash,
      );

  // ===== P2: search & system apps =====

  Future<SearchResult> searchFiles({
    required String directory,
    required String query,
    SearchType searchType = SearchType.name,
    List<String> fileTypes = const [],
    int maxResults = 200,
    bool recursive = true,
  }) =>
      _p.searchFiles(
        directory: directory,
        query: query,
        searchType: searchType,
        fileTypes: fileTypes,
        maxResults: maxResults,
        recursive: recursive,
      );

  Future<void> openSystemFileManager({String? path}) =>
      _p.openSystemFileManager(path: path);

  Future<void> openFileWithSystemApp({required String path, String? mimeType}) =>
      _p.openFileWithSystemApp(path: path, mimeType: mimeType);
}
