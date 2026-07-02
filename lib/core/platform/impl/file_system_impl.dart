import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/platform/file_system_api.dart';

/// [FileSystemApi] backed by `path_provider` + `dart:io`, with `file_picker`
/// for user-driven selection. The only place these plugins are imported.
class PluginFileSystemApi implements FileSystemApi {
  const PluginFileSystemApi();

  @override
  Future<String> documentsDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  @override
  Future<String> temporaryDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<Uint8List> readAsBytes(String path) => File(path).readAsBytes();

  @override
  Future<String> readAsString(String path) => File(path).readAsString();

  @override
  Future<void> writeAsBytes(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<void> writeAsString(String path, String contents) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<PickedFile?> pickFile({List<String>? allowedExtensions}) async {
    final result = await FilePicker.pickFiles(
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final picked = result.files.first;
    return PickedFile(
      name: picked.name,
      path: picked.path ?? '',
      size: picked.size,
      bytes: picked.bytes,
    );
  }

  @override
  Future<List<PickedFile>> pickFiles({List<String>? allowedExtensions}) async {
    final result = await FilePicker.pickFiles(
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
    );
    if (result == null) return const [];
    return [
      for (final picked in result.files)
        PickedFile(
          name: picked.name,
          path: picked.path ?? '',
          size: picked.size,
          bytes: picked.bytes,
        ),
    ];
  }
}
