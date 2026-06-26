import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'aetherlink_saf_method_channel.dart';
import 'src/models.dart';

/// Abstract platform interface for the Aetherlink local SAF workspace plugin.
///
/// Method contract: see docs/本地SAF工作区插件-方法规格.md. Every method below
/// throws [UnimplementedError] by default so concrete platform implementations
/// (e.g. [MethodChannelAetherlinkSaf]) only need to override the ones they
/// actually support.
abstract class AetherlinkSafPlatform extends PlatformInterface {
  AetherlinkSafPlatform() : super(token: _token);

  static final Object _token = Object();

  static AetherlinkSafPlatform _instance = MethodChannelAetherlinkSaf();

  static AetherlinkSafPlatform get instance => _instance;

  static set instance(AetherlinkSafPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ===== P0: connectivity self-test =====

  /// Round-trips [value] through the platform side. Returns whatever the
  /// native handler echoes back; used to verify the method channel is wired
  /// before any real SAF call is attempted.
  Future<EchoResult> echo({required String value}) {
    throw UnimplementedError('echo() has not been implemented.');
  }

  // ===== P0: permission management =====

  Future<PermissionResult> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  Future<PermissionResult> checkPermissions({String? uri}) {
    throw UnimplementedError('checkPermissions() has not been implemented.');
  }

  Future<List<SelectedFileInfo>> listPersistedPermissions() {
    throw UnimplementedError(
      'listPersistedPermissions() has not been implemented.',
    );
  }

  Future<void> releasePersistableUriPermission({required String uri}) {
    throw UnimplementedError(
      'releasePersistableUriPermission() has not been implemented.',
    );
  }

  // ===== P0: system picker =====

  Future<PickerResult> openSystemFilePicker({
    required PickerType type,
    bool multiple = false,
    List<String>? accept,
    String? startDirectory,
    String? title,
  }) {
    throw UnimplementedError(
      'openSystemFilePicker() has not been implemented.',
    );
  }

  // ===== P0: directory & file reads =====

  Future<ListDirectoryResult> listDirectory({
    required String path,
    bool showHidden = false,
    FileSortBy sortBy = FileSortBy.byName,
    FileSortOrder sortOrder = FileSortOrder.asc,
  }) {
    throw UnimplementedError('listDirectory() has not been implemented.');
  }

  Future<ReadFileResult> readFile({
    required String path,
    String encoding = 'utf8',
  }) {
    throw UnimplementedError('readFile() has not been implemented.');
  }

  Future<FileInfo> getFileInfo({required String path}) {
    throw UnimplementedError('getFileInfo() has not been implemented.');
  }

  Future<bool> exists({required String path}) {
    throw UnimplementedError('exists() has not been implemented.');
  }

  // ===== P1: write & structure operations =====

  Future<void> writeFile({
    required String path,
    required String content,
    String encoding = 'utf8',
    bool append = false,
  }) {
    throw UnimplementedError('writeFile() has not been implemented.');
  }

  Future<PathResult> createFile({
    required String parentPath,
    required String name,
    String? content,
    String encoding = 'utf8',
    String? mimeType,
  }) {
    throw UnimplementedError('createFile() has not been implemented.');
  }

  Future<PathResult> createDirectory({
    required String parentPath,
    required String name,
    bool recursive = false,
  }) {
    throw UnimplementedError('createDirectory() has not been implemented.');
  }

  Future<void> deleteFile({required String path}) {
    throw UnimplementedError('deleteFile() has not been implemented.');
  }

  Future<void> deleteDirectory({required String path, bool recursive = false}) {
    throw UnimplementedError('deleteDirectory() has not been implemented.');
  }

  Future<PathResult> renameFile({
    required String path,
    required String newName,
  }) {
    throw UnimplementedError('renameFile() has not been implemented.');
  }

  Future<PathResult> moveFile({
    required String sourcePath,
    required String destinationParent,
  }) {
    throw UnimplementedError('moveFile() has not been implemented.');
  }

  Future<PathResult> copyFile({
    required String sourcePath,
    required String destinationParent,
    String? newName,
    bool overwrite = false,
  }) {
    throw UnimplementedError('copyFile() has not been implemented.');
  }

  // ===== P1: advanced reads =====

  Future<ReadFileRangeResult> readFileRange({
    required String path,
    required int startLine,
    required int endLine,
    String? encoding,
  }) {
    throw UnimplementedError('readFileRange() has not been implemented.');
  }

  Future<Uint8List> readFileBytes({
    required String path,
    int? offset,
    int? length,
  }) {
    throw UnimplementedError('readFileBytes() has not been implemented.');
  }

  Future<int> getLineCount({required String path}) {
    throw UnimplementedError('getLineCount() has not been implemented.');
  }

  Future<FileHashResult> getFileHash({
    required String path,
    HashAlgorithm algorithm = HashAlgorithm.sha256,
  }) {
    throw UnimplementedError('getFileHash() has not been implemented.');
  }

  // ===== P2: advanced editing =====

  Future<void> insertContent({
    required String path,
    required int line,
    required String content,
  }) {
    throw UnimplementedError('insertContent() has not been implemented.');
  }

  Future<ReplaceResult> replaceInFile({
    required String path,
    required String search,
    required String replace,
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) {
    throw UnimplementedError('replaceInFile() has not been implemented.');
  }

  Future<ApplyDiffResult> applyDiff({
    required String path,
    required String diff,
    DiffFormat format = DiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
  }) {
    throw UnimplementedError('applyDiff() has not been implemented.');
  }

  // ===== P2: search & system apps =====

  Future<SearchResult> searchFiles({
    required String directory,
    required String query,
    SearchType searchType = SearchType.name,
    List<String> fileTypes = const [],
    int maxResults = 200,
    bool recursive = true,
  }) {
    throw UnimplementedError('searchFiles() has not been implemented.');
  }

  Future<void> openSystemFileManager({String? path}) {
    throw UnimplementedError(
      'openSystemFileManager() has not been implemented.',
    );
  }

  Future<void> openFileWithSystemApp({required String path, String? mimeType}) {
    throw UnimplementedError(
      'openFileWithSystemApp() has not been implemented.',
    );
  }
}
