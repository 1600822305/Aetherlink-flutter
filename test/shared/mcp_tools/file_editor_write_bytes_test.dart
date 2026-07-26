import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_write_handlers.dart';

/// In-memory posix-style backend holding raw bytes, with injectable failures
/// so the write-temp-then-swap path can be exercised at each step.
class _MemBackend extends WorkspaceBackend {
  _MemBackend(Iterable<String> dirs, Map<String, List<int>> files)
      : _dirs = {...dirs},
        files = {...files};

  final Set<String> _dirs;
  final Map<String, List<int>> files;

  /// Name → thrown error, checked in `createFileBytes`.
  final Map<String, Object> failCreate = {};

  /// Path → thrown error, checked in `rename`.
  final Map<String, Object> failRename = {};

  int deleteCalls = 0;

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
    if (!_dirs.contains(path)) throw Exception('no such dir: $path');
    return [
      for (final d in _dirs)
        if (d != path && _parent(d) == path) _entry(d, true),
      for (final f in files.keys)
        if (_parent(f) == path) _entry(f, false),
    ];
  }

  @override
  Future<String> readFile(String path) async {
    final b = files[path];
    if (b == null) throw Exception('no such file: $path');
    return utf8.decode(b);
  }

  @override
  Future<WorkspaceEntry> getFileInfo(String path) async {
    if (_dirs.contains(path)) return _entry(path, true);
    if (files.containsKey(path)) return _entry(path, false);
    throw Exception('no such entry: $path');
  }

  @override
  Future<String> createDirectory(
    String parentPath,
    String name, {
    bool recursive = false,
  }) async {
    if (!_dirs.contains(parentPath)) {
      throw Exception('parent missing: $parentPath');
    }
    final path = '$parentPath/$name';
    _dirs.add(path);
    return path;
  }

  @override
  Future<String> createFileBytes(
    String parentPath,
    String name,
    List<int> bytes,
  ) async {
    final boom = failCreate[name];
    if (boom != null) throw boom;
    if (!_dirs.contains(parentPath)) {
      throw Exception('parent missing: $parentPath');
    }
    final path = '$parentPath/$name';
    files[path] = [...bytes];
    return path;
  }

  @override
  Future<void> delete(
    String path, {
    bool isDirectory = false,
    bool recursive = false,
  }) async {
    deleteCalls++;
    if (files.remove(path) == null && !_dirs.remove(path)) {
      throw Exception('no such entry: $path');
    }
  }

  @override
  Future<String> rename(String path, String newName) async {
    final boom = failRename[path];
    if (boom != null) throw boom;
    final bytes = files.remove(path);
    if (bytes == null) throw Exception('no such file: $path');
    final target = '${_parent(path)}/$newName';
    files[target] = bytes;
    return target;
  }

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  WorkspaceEntry _entry(String path, bool isDir) => WorkspaceEntry(
        name: path.substring(path.lastIndexOf('/') + 1),
        path: path,
        isDirectory: isDir,
        size: files[path]?.length ?? 0,
        mtime: 1,
      );
}

List<int> _bytes(String s) => utf8.encode(s);
String _text(List<int>? b) => b == null ? '' : utf8.decode(b);

void main() {
  const root = '/root';
  const deck = '$root/a.pptx';
  const tempName = 'a.pptx$kTempWriteSuffix';
  const tempPath = '$root/$tempName';

  _MemBackend backendWith(Map<String, List<int>> files) =>
      _MemBackend({root}, files);

  WriteTargetResolver resolverFor(_MemBackend backend) =>
      (path) => locatePosixWriteTarget(backend, path);

  group('writeBytesAtPath — 新建', () {
    test('目标不存在时直接创建，内容正确', () async {
      final backend = backendWith({});
      final path = await writeBytesAtPath(
        resolverFor(backend),
        deck,
        _bytes('new'),
      );
      expect(path, deck);
      expect(_text(backend.files[deck]), 'new');
      expect(backend.deleteCalls, 0);
    });

    test('缺失的父目录会被逐级创建', () async {
      final backend = backendWith({});
      final path = await writeBytesAtPath(
        resolverFor(backend),
        '$root/out/deck/a.pptx',
        _bytes('new'),
      );
      expect(path, '$root/out/deck/a.pptx');
      expect((await backend.getFileInfo('$root/out/deck')).isDirectory, isTrue);
    });
  });

  group('writeBytesAtPath — 拒绝覆盖', () {
    test('overwrite 未开启时报错，且旧文件原封不动', () async {
      final backend = backendWith({deck: _bytes('old')});
      await expectLater(
        writeBytesAtPath(resolverFor(backend), deck, _bytes('new')),
        throwsA(isA<FileEditorError>()),
      );
      expect(_text(backend.files[deck]), 'old');
      expect(backend.deleteCalls, 0);
    });
  });

  group('writeBytesAtPath — 覆盖走 write-temp-then-swap', () {
    test('成功覆盖后内容更新，且不残留临时文件', () async {
      final backend = backendWith({deck: _bytes('old')});
      final path = await writeBytesAtPath(
        resolverFor(backend),
        deck,
        _bytes('new'),
        overwrite: true,
      );
      expect(path, deck);
      expect(_text(backend.files[deck]), 'new');
      expect(backend.files.containsKey(tempPath), isFalse);
    });

    // 回归：旧实现「先 delete 再 createFileBytes」在重建失败时会把旧导出一起丢掉。
    test('写新内容失败时旧文件必须还在（不再先删后建）', () async {
      final backend = backendWith({deck: _bytes('old')});
      backend.failCreate[tempName] = Exception('disk full');

      await expectLater(
        writeBytesAtPath(
          resolverFor(backend),
          deck,
          _bytes('new'),
          overwrite: true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(_text(backend.files[deck]), 'old');
      expect(backend.deleteCalls, 0, reason: '新内容落盘前不允许删任何东西');
    });

    test('上次中断残留的临时文件会被清掉后重用', () async {
      final backend = backendWith({
        deck: _bytes('old'),
        tempPath: _bytes('stale'),
      });
      await writeBytesAtPath(
        resolverFor(backend),
        deck,
        _bytes('new'),
        overwrite: true,
      );
      expect(_text(backend.files[deck]), 'new');
      expect(backend.files.containsKey(tempPath), isFalse);
    });

    test('改名失败时内容仍保留在临时文件里，错误信息给出路径', () async {
      final backend = backendWith({deck: _bytes('old')});
      backend.failRename[tempPath] = Exception('rename denied');

      await expectLater(
        writeBytesAtPath(
          resolverFor(backend),
          deck,
          _bytes('new'),
          overwrite: true,
        ),
        throwsA(
          isA<FileEditorError>().having(
            (e) => e.message,
            'message',
            allOf(contains(tempPath), contains('没有丢失')),
          ),
        ),
      );
      expect(_text(backend.files[tempPath]), 'new');
    });

    test('临时兄弟路径无法解析（不透明句柄）时拒绝覆盖，不删旧文件', () async {
      final backend = backendWith({deck: _bytes('old')});
      Future<WriteTarget> resolve(String path) async {
        if (path.endsWith(kTempWriteSuffix)) {
          throw const FileEditorError('目标不存在：不透明句柄路径无法用于新建文件。');
        }
        return locatePosixWriteTarget(backend, path);
      }

      await expectLater(
        writeBytesAtPath(resolve, deck, _bytes('new'), overwrite: true),
        throwsA(
          isA<FileEditorError>().having(
            (e) => e.message,
            'message',
            contains('无法安全覆盖'),
          ),
        ),
      );
      expect(_text(backend.files[deck]), 'old');
      expect(backend.deleteCalls, 0);
    });
  });
}
