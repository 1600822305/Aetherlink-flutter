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
      if (uri != null) 'uri': uri,
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
      if (accept != null) 'accept': accept,
      if (startDirectory != null) 'startDirectory': startDirectory,
      if (title != null) 'title': title,
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
}
