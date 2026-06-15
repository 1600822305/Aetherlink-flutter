import 'dart:typed_data';

/// A file the user chose through the platform file picker.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.path,
    required this.size,
    this.bytes,
  });

  final String name;
  final String path;
  final int size;

  /// In-memory contents, populated only when the picker is asked to read data.
  final Uint8List? bytes;
}

/// Reads and writes files in the app's private storage and lets the user pick
/// files from the device.
///
/// Implemented with `path_provider` + `dart:io` (and `file_picker` for
/// selection) under `impl/`. This interface stays pure Dart so callers and
/// tests depend on the abstraction, never the plugins (ADR-0007).
abstract interface class FileSystemApi {
  /// Absolute path of the app's private documents directory (persistent).
  Future<String> documentsDirectoryPath();

  /// Absolute path of the app's temporary/cache directory (may be cleared).
  Future<String> temporaryDirectoryPath();

  Future<bool> exists(String path);

  Future<Uint8List> readAsBytes(String path);

  Future<String> readAsString(String path);

  Future<void> writeAsBytes(String path, Uint8List bytes);

  Future<void> writeAsString(String path, String contents);

  Future<void> delete(String path);

  /// Opens the platform picker; returns null when the user cancels.
  Future<PickedFile?> pickFile({List<String>? allowedExtensions});
}
