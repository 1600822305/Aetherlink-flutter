import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// 只提供原生递归列表的后端：listDir 被调用即视为走了逐层回退（计数断言）。
class _NativeListBackend extends WorkspaceBackend {
  _NativeListBackend(this._listing);

  final WorkspaceRecursiveListing _listing;
  int listDirCalls = 0;
  int nativeCalls = 0;
  Set<String>? lastSkipDirs;
  int? lastMaxDepth;
  int? lastMaxEntries;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
    canExec: false,
    canWatch: false,
    isRemote: false,
  );

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    listDirCalls++;
    return const [];
  }

  @override
  Future<String> readFile(String path) async => '';

  @override
  Future<WorkspaceRecursiveListing?> listDirRecursive(
    String path, {
    required int maxDepth,
    Set<String> skipDirs = const {},
    int maxEntries = 2000,
  }) async {
    nativeCalls++;
    lastSkipDirs = skipDirs;
    lastMaxDepth = maxDepth;
    lastMaxEntries = maxEntries;
    return _listing;
  }
}

WorkspaceEntry _entry(String name, {bool dir = false, int mtime = 0}) =>
    WorkspaceEntry(
      name: name,
      path: '/root/$name',
      isDirectory: dir,
      size: 0,
      mtime: mtime,
    );

void main() {
  group('listRecursive 原生快路径', () {
    test('后端返回原生列表时不再逐层 listDir，且透传 skipDirs / 上限', () async {
      final backend = _NativeListBackend(
        WorkspaceRecursiveListing([
          _entry('lib', dir: true),
          _entry('a.dart', mtime: 2),
          _entry('b.txt', mtime: 5),
        ], truncated: true),
      );
      final listing = await listRecursive(backend, '/root', 3);
      expect(backend.nativeCalls, 1);
      expect(backend.listDirCalls, 0);
      expect(backend.lastMaxDepth, 3);
      expect(backend.lastSkipDirs, kListIgnoredDirs);
      expect(backend.lastMaxEntries, kMaxRecursiveEntries);
      expect(listing.truncated, isTrue);
      expect(listing.entries.length, 3);
      expect(listing.entries.first['name'], 'lib');
    });

    test('fileNamePattern 只留匹配文件，sortByMtime 降序', () async {
      final backend = _NativeListBackend(
        WorkspaceRecursiveListing([
          _entry('lib', dir: true),
          _entry('a.dart', mtime: 2),
          _entry('c.dart', mtime: 9),
          _entry('b.txt', mtime: 5),
        ], truncated: false),
      );
      final listing = await listRecursive(
        backend,
        '/root',
        2,
        fileNamePattern: RegExp(r'\.dart$'),
        sortByMtime: true,
      );
      expect(
        [for (final e in listing.entries) e['name']],
        ['c.dart', 'a.dart'],
      );
    });

    test('后端不支持原生递归时回退逐层遍历', () async {
      final fallback = _FallbackBackend();
      final listing = await listRecursive(fallback, '/root', 1);
      expect(listing.entries, isEmpty);
      expect(fallback.listDirCalls, 1);
    });
  });
}

class _FallbackBackend extends WorkspaceBackend {
  int listDirCalls = 0;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
    canExec: false,
    canWatch: false,
    isRemote: false,
  );

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    listDirCalls++;
    return [];
  }

  @override
  Future<String> readFile(String path) async => '';
}
