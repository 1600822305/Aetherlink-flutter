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
}
