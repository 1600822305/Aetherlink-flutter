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
}
