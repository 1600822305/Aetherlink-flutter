import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'aetherlink_saf_platform_interface.dart';
import 'src/models.dart';

/// Default [AetherlinkSafPlatform] backed by a method channel. The native
/// counterpart is `AetherlinkSafPlugin` (Kotlin) in `android/src/main/kotlin/.../`.
///
/// Each method maps 1:1 to a channel call; method names and the JSON shape of
/// arguments and results are the wire contract — see docs/本地SAF工作区插件-方法规格.md.
class MethodChannelAetherlinkSaf extends AetherlinkSafPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('aetherlink_saf');

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      method,
      args,
    );
    return result ?? const <Object?, Object?>{};
  }

  // ===== echo =====

  @override
  Future<EchoResult> echo({required String value}) async {
    final map = await _invokeMap('echo', {'value': value});
    return EchoResult.fromMap(map);
  }

  // ===== permission management =====

  @override
  Future<PermissionResult> requestPermissions() async {
    final map = await _invokeMap('requestPermissions');
    return PermissionResult.fromMap(map);
  }

  @override
  Future<PermissionResult> checkPermissions({String? uri}) async {
    final map = await _invokeMap('checkPermissions', {
      'uri': ?uri,
    });
    return PermissionResult.fromMap(map);
  }

  @override
  Future<List<SelectedFileInfo>> listPersistedPermissions() async {
    final raw = await methodChannel.invokeListMethod<Object?>(
      'listPersistedPermissions',
    );
    return [
      if (raw != null)
        for (final item in raw)
          if (item is Map)
            SelectedFileInfo.fromMap(item.cast<Object?, Object?>()),
    ];
  }

  @override
  Future<void> releasePersistableUriPermission({required String uri}) async {
    await methodChannel.invokeMethod<void>('releasePersistableUriPermission', {
      'uri': uri,
    });
  }

  // ===== system picker =====

  @override
  Future<PickerResult> openSystemFilePicker({
    required PickerType type,
    bool multiple = false,
    List<String>? accept,
    String? startDirectory,
    String? title,
  }) async {
    final map = await _invokeMap('openSystemFilePicker', {
      'type': type.wireValue,
      'multiple': multiple,
      'accept': ?accept,
      'startDirectory': ?startDirectory,
      'title': ?title,
    });
    return PickerResult.fromMap(map);
  }

  // ===== directory & file reads =====

  @override
  Future<ListDirectoryResult> listDirectory({
    required String path,
    bool showHidden = false,
    FileSortBy sortBy = FileSortBy.byName,
    FileSortOrder sortOrder = FileSortOrder.asc,
  }) async {
    final map = await _invokeMap('listDirectory', {
      'path': path,
      'showHidden': showHidden,
      'sortBy': sortBy.wireValue,
      'sortOrder': sortOrder.wireValue,
    });
    return ListDirectoryResult.fromMap(map);
  }

  @override
  Future<ReadFileResult> readFile({
    required String path,
    String encoding = 'utf8',
  }) async {
    final map = await _invokeMap('readFile', {
      'path': path,
      'encoding': encoding,
    });
    return ReadFileResult.fromMap(map);
  }

  @override
  Future<FileInfo> getFileInfo({required String path}) async {
    final map = await _invokeMap('getFileInfo', {'path': path});
    return FileInfo.fromMap(map);
  }

  @override
  Future<bool> exists({required String path}) async {
    final map = await _invokeMap('exists', {'path': path});
    return (map['exists'] as bool?) ?? false;
  }

  // ===== P1: write & structure operations =====

  @override
  Future<void> writeFile({
    required String path,
    required String content,
    String encoding = 'utf8',
    bool append = false,
  }) async {
    await methodChannel.invokeMethod<void>('writeFile', {
      'path': path,
      'content': content,
      'encoding': encoding,
      'append': append,
    });
  }

  @override
  Future<PathResult> createFile({
    required String parentPath,
    required String name,
    String? content,
    String encoding = 'utf8',
    String? mimeType,
  }) async {
    final map = await _invokeMap('createFile', {
      'parentPath': parentPath,
      'name': name,
      'content': ?content,
      'encoding': encoding,
      'mimeType': ?mimeType,
    });
    return PathResult.fromMap(map);
  }

  @override
  Future<PathResult> createDirectory({
    required String parentPath,
    required String name,
    bool recursive = false,
  }) async {
    final map = await _invokeMap('createDirectory', {
      'parentPath': parentPath,
      'name': name,
      'recursive': recursive,
    });
    return PathResult.fromMap(map);
  }

  @override
  Future<void> deleteFile({required String path}) async {
    await methodChannel.invokeMethod<void>('deleteFile', {'path': path});
  }

  @override
  Future<void> deleteDirectory({
    required String path,
    bool recursive = false,
  }) async {
    await methodChannel.invokeMethod<void>('deleteDirectory', {
      'path': path,
      'recursive': recursive,
    });
  }

  @override
  Future<PathResult> renameFile({
    required String path,
    required String newName,
  }) async {
    final map = await _invokeMap('renameFile', {
      'path': path,
      'newName': newName,
    });
    return PathResult.fromMap(map);
  }

  @override
  Future<PathResult> moveFile({
    required String sourcePath,
    required String destinationParent,
  }) async {
    final map = await _invokeMap('moveFile', {
      'sourcePath': sourcePath,
      'destinationParent': destinationParent,
    });
    return PathResult.fromMap(map);
  }

  @override
  Future<PathResult> copyFile({
    required String sourcePath,
    required String destinationParent,
    String? newName,
    bool overwrite = false,
  }) async {
    final map = await _invokeMap('copyFile', {
      'sourcePath': sourcePath,
      'destinationParent': destinationParent,
      'newName': ?newName,
      'overwrite': overwrite,
    });
    return PathResult.fromMap(map);
  }

  // ===== P1: advanced reads =====

  @override
  Future<ReadFileRangeResult> readFileRange({
    required String path,
    required int startLine,
    required int endLine,
    String? encoding,
  }) async {
    final map = await _invokeMap('readFileRange', {
      'path': path,
      'startLine': startLine,
      'endLine': endLine,
      'encoding': ?encoding,
    });
    return ReadFileRangeResult.fromMap(map);
  }

  @override
  Future<Uint8List> readFileBytes({
    required String path,
    int? offset,
    int? length,
  }) async {
    final map = await _invokeMap('readFileBytes', {
      'path': path,
      'offset': ?offset,
      'length': ?length,
    });
    final bytes = map['bytes'];
    return bytes is Uint8List ? bytes : Uint8List(0);
  }

  @override
  Future<int> getLineCount({required String path}) async {
    final map = await _invokeMap('getLineCount', {'path': path});
    return (map['lines'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<FileHashResult> getFileHash({
    required String path,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) async {
    final map = await _invokeMap('getFileHash', {
      'path': path,
      'algorithm': algorithm.wireValue,
    });
    return FileHashResult.fromMap(map);
  }

  // ===== P2: advanced editing =====

  @override
  Future<void> insertContent({
    required String path,
    required int line,
    required String content,
  }) async {
    await methodChannel.invokeMethod<void>('insertContent', {
      'path': path,
      'line': line,
      'content': content,
    });
  }

  @override
  Future<ReplaceResult> replaceInFile({
    required String path,
    required String search,
    required String replace,
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) async {
    final map = await _invokeMap('replaceInFile', {
      'path': path,
      'search': search,
      'replace': replace,
      'isRegex': isRegex,
      'replaceAll': replaceAll,
      'caseSensitive': caseSensitive,
    });
    return ReplaceResult.fromMap(map);
  }

  @override
  Future<ApplyDiffResult> applyDiff({
    required String path,
    required String diff,
    DiffFormat format = DiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
  }) async {
    final map = await _invokeMap('applyDiff', {
      'path': path,
      'diff': diff,
      'format': format.wireValue,
      'createBackup': createBackup,
      'expectedRangeHash': ?expectedRangeHash,
    });
    return ApplyDiffResult.fromMap(map);
  }

  // ===== P2: search & system apps =====

  @override
  Future<SearchResult> searchFiles({
    required String directory,
    required String query,
    SearchType searchType = SearchType.name,
    List<String> fileTypes = const [],
    int maxResults = 200,
    bool recursive = true,
  }) async {
    final map = await _invokeMap('searchFiles', {
      'directory': directory,
      'query': query,
      'searchType': searchType.wireValue,
      'fileTypes': fileTypes,
      'maxResults': maxResults,
      'recursive': recursive,
    });
    return SearchResult.fromMap(map);
  }

  @override
  Future<void> openSystemFileManager({String? path}) async {
    await methodChannel.invokeMethod<void>('openSystemFileManager', {
      'path': ?path,
    });
  }

  @override
  Future<void> openFileWithSystemApp({
    required String path,
    String? mimeType,
  }) async {
    await methodChannel.invokeMethod<void>('openFileWithSystemApp', {
      'path': path,
      'mimeType': ?mimeType,
    });
  }
}
