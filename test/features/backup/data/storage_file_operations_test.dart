import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:aetherlink_flutter/features/backup/data/storage_file_operations.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';

void main() {
  late Directory root;
  late Directory allowed;
  late Directory outside;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_paths_');
    allowed = await Directory(p.join(root.path, 'allowed')).create();
    outside = await Directory(p.join(root.path, 'allowed_sibling')).create();
    await File(p.join(outside.path, 'keep')).writeAsString('keep');
  });

  tearDown(() async => root.delete(recursive: true));

  StoragePathSpec spec(String path, {bool canClean = true}) => StoragePathSpec(
    id: 'test', category: StorageCategory.cache, name: '测试',
    root: allowed.path, path: path, canClean: canClean,
  );

  test('rejects sibling-prefix and normalized traversal escapes', () {
    for (final path in [outside.path, p.join(allowed.path, '..', 'allowed_sibling')]) {
      expect(isStoragePathSafe(allowed.path, path), isFalse);
      expect(() => clearStoragePaths([spec(path)]), throwsA(isA<FileSystemException>()));
      expect(scanStoragePaths([spec(path)], canCleanCache: true).items, isEmpty);
    }
    expect(File(p.join(outside.path, 'keep')).readAsStringSync(), 'keep');
  });

  test('missing directories scan as empty and cleanup is a no-op', () {
    final missing = spec(p.join(allowed.path, 'missing'));
    expect(scanStoragePaths([missing], canCleanCache: true).totalBytes, 0);
    expect(scanStoragePaths([missing], canCleanCache: true).items, isEmpty);
    clearStoragePaths([missing]);
  });

  test('root and intermediate symlinks are rejected', () async {
    if (Platform.isWindows) return;
    final link = Link(p.join(allowed.path, 'link'));
    await link.create(outside.path);
    for (final path in [link.path, p.join(link.path, 'child')]) {
      expect(isStoragePathSafe(allowed.path, path), isFalse);
      expect(() => clearStoragePaths([spec(path)]), throwsA(isA<FileSystemException>()));
      expect(scanStoragePaths([spec(path)], canCleanCache: true).items, isEmpty);
    }
    expect(isStoragePathSafe(link.path, link.path), isFalse);
    final disguised = '${link.path}${p.separator}..${p.separator}keep';
    expect(isStoragePathSafe(allowed.path, disguised), isFalse);
    expect(() => clearStoragePaths([spec(disguised)]), throwsA(isA<FileSystemException>()));
    expect(await File(p.join(outside.path, 'keep')).exists(), isTrue);
  });

  test('nested links are unlinked without measuring or removing targets', () async {
    if (Platform.isWindows) return;
    await Link(p.join(allowed.path, 'link')).create(outside.path);
    await File(p.join(allowed.path, 'remove')).writeAsBytes([1, 2]);
    final target = spec(allowed.path);
    expect(scanStoragePaths([target], canCleanCache: true).totalBytes, 2);
    clearStoragePaths([target]);
    expect(await allowed.exists(), isTrue);
    expect(await allowed.list().toList(), isEmpty);
    expect(await File(p.join(outside.path, 'keep')).readAsString(), 'keep');
  });

  test('read-only targets and caller supplied paths cannot be cleaned by id', () {
    final readOnly = spec(allowed.path, canClean: false);
    expect(() => cleanStorageItem([readOnly], 'test'), throwsArgumentError);
    expect(() => cleanStorageItem([spec(allowed.path)], outside.path), throwsArgumentError);
    expect(() => clearStoragePaths([readOnly]), throwsA(isA<FileSystemException>()));
  });

  test('a cleanup directory replaced by a file reports an error', () async {
    final file = await File(p.join(allowed.path, 'not_a_directory')).writeAsString('keep');
    expect(() => clearStoragePaths([spec(file.path)]), throwsA(isA<FileSystemException>()));
    expect(await file.readAsString(), 'keep');
  });
}
