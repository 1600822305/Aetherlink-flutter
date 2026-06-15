import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:aetherlink_flutter/core/platform/impl/file_system_impl.dart';

/// Headless smoke test: exercises the real impl's file I/O against a temporary
/// directory. No path_provider/file_picker device channels are touched.
void main() {
  const fs = PluginFileSystemApi();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aetherlink_fs_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writes, confirms existence, reads back, then deletes bytes', () async {
    final path = p.join(tempDir.path, 'nested', 'attachment.bin');
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    expect(await fs.exists(path), isFalse);

    await fs.writeAsBytes(path, bytes);
    expect(await fs.exists(path), isTrue);
    expect(await fs.readAsBytes(path), bytes);

    await fs.delete(path);
    expect(await fs.exists(path), isFalse);
  });

  test('writes and reads back string contents', () async {
    final path = p.join(tempDir.path, 'export.json');

    await fs.writeAsString(path, '{"topic":"t1"}');

    expect(await fs.readAsString(path), '{"topic":"t1"}');
  });

  test('delete is a no-op when the file is absent', () async {
    final path = p.join(tempDir.path, 'missing.txt');

    await fs.delete(path);

    expect(await fs.exists(path), isFalse);
  });
}
