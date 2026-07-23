import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_write_handlers.dart';

/// In-memory posix-style backend: `_dirs` holds directory paths, `_files`
/// path→content. Paths are plain strings ('/root', '/root/a.txt').
class _MemBackend extends WorkspaceBackend {
  _MemBackend(Iterable<String> dirs, Map<String, String> files)
      : _dirs = {...dirs},
        _files = {...files};

  final Set<String> _dirs;
  final Map<String, String> _files;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
      canExec: false, canWatch: false, isRemote: false);

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    if (!_dirs.contains(path)) throw Exception('no such dir: $path');
    final out = <WorkspaceEntry>[];
    for (final d in _dirs) {
      if (d != path && _parent(d) == path) out.add(_entry(d, true));
    }
    for (final f in _files.keys) {
      if (_parent(f) == path) out.add(_entry(f, false));
    }
    return out;
  }

  @override
  Future<String> readFile(String path) async {
    final c = _files[path];
    if (c == null) throw Exception('no such file: $path');
    return c;
  }

  @override
  Future<WorkspaceEntry> getFileInfo(String path) async {
    if (_dirs.contains(path)) return _entry(path, true);
    if (_files.containsKey(path)) return _entry(path, false);
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
  Future<String> createFile(
    String parentPath,
    String name, {
    String? content,
  }) async {
    if (!_dirs.contains(parentPath)) {
      throw Exception('parent missing: $parentPath');
    }
    final path = '$parentPath/$name';
    _files[path] = content ?? '';
    return path;
  }

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  WorkspaceEntry _entry(String path, bool isDir) => WorkspaceEntry(
        name: path.substring(path.lastIndexOf('/') + 1),
        path: path,
        isDirectory: isDir,
        size: 0,
        mtime: 1,
      );
}

void main() {
  group('posixBasename / posixDirname', () {
    test('splits absolute paths', () {
      expect(posixBasename('/a/b/c.txt'), 'c.txt');
      expect(posixDirname('/a/b/c.txt'), '/a/b');
      expect(posixDirname('/a'), '/');
      expect(posixBasename('/'), '');
    });
  });

  group('locatePosixWriteTarget', () {
    test('existing file → overwrite target', () async {
      final backend = _MemBackend({'/root'}, {'/root/a.txt': 'hi'});
      final t = await locatePosixWriteTarget(backend, '/root/a.txt');
      expect(t.existing, isNotNull);
      expect(t.existing!.path, '/root/a.txt');
    });

    test('existing directory is rejected', () async {
      final backend = _MemBackend({'/root', '/root/sub'}, {});
      expect(
        () => locatePosixWriteTarget(backend, '/root/sub'),
        throwsA(isA<FileEditorError>()),
      );
    });

    test('missing file with existing parent → creation target', () async {
      final backend = _MemBackend({'/root'}, {});
      final t = await locatePosixWriteTarget(backend, '/root/new.txt');
      expect(t.existing, isNull);
      expect(t.parentPath, '/root');
      expect(t.missingDirs, isEmpty);
      expect(t.fileName, 'new.txt');
    });

    test('missing ancestors are collected in order (mkdir -p)', () async {
      final backend = _MemBackend({'/root'}, {});
      final t = await locatePosixWriteTarget(backend, '/root/a/b/c.txt');
      expect(t.parentPath, '/root');
      expect(t.missingDirs, ['a', 'b']);
      expect(t.fileName, 'c.txt');
    });

    test('intermediate segment that is a file is rejected', () async {
      final backend = _MemBackend({'/root'}, {'/root/a': 'file'});
      expect(
        () => locatePosixWriteTarget(backend, '/root/a/b.txt'),
        throwsA(isA<FileEditorError>()),
      );
    });
  });

  group('locateOpaqueWriteTarget', () {
    test('navigates existing segments, collects missing dirs', () async {
      final backend =
          _MemBackend({'/root', '/root/lib'}, {'/root/lib/x.dart': ''});
      final existing =
          await locateOpaqueWriteTarget(backend, '/root', 'lib/x.dart');
      expect(existing.existing!.path, '/root/lib/x.dart');

      final create =
          await locateOpaqueWriteTarget(backend, '/root', 'lib/a/b/y.dart');
      expect(create.existing, isNull);
      expect(create.parentPath, '/root/lib');
      expect(create.missingDirs, ['a', 'b']);
      expect(create.fileName, 'y.dart');
    });

    test('rejects .. and empty paths', () async {
      final backend = _MemBackend({'/root'}, {});
      expect(
        () => locateOpaqueWriteTarget(backend, '/root', '../x.txt'),
        throwsA(isA<FileEditorError>()),
      );
      expect(
        () => locateOpaqueWriteTarget(backend, '/root', './'),
        throwsA(isA<FileEditorError>()),
      );
    });

    test('directory as final segment is rejected', () async {
      final backend = _MemBackend({'/root', '/root/lib'}, {});
      expect(
        () => locateOpaqueWriteTarget(backend, '/root', 'lib'),
        throwsA(isA<FileEditorError>()),
      );
    });
  });

  group('materializeWriteTarget', () {
    test('creates missing dirs then the file', () async {
      final backend = _MemBackend({'/root'}, {});
      final t = await locatePosixWriteTarget(backend, '/root/a/b/c.txt');
      final path = await materializeWriteTarget(t, 'hello');
      expect(path, '/root/a/b/c.txt');
      expect(await backend.readFile(path), 'hello');
      expect((await backend.getFileInfo('/root/a/b')).isDirectory, isTrue);
    });
  });

  group('diffSummaryJson', () {
    test('null when unchanged', () {
      expect(diffSummaryJson('a\nb\n', 'a\nb\n'), isNull);
    });

    test('counts added/removed and renders compact diff', () {
      final d = diffSummaryJson('a\nb\nc\n', 'a\nB\nc\nd\n')!;
      expect(d['linesAdded'], 2);
      expect(d['linesRemoved'], 1);
      final text = d['diff'] as String;
      expect(text, contains('-b'));
      expect(text, contains('+B'));
      expect(text, contains('+d'));
    });

    test('collapses far-apart hunks with … and truncates long diffs', () {
      final old = List.generate(50, (i) => 'line$i').join('\n');
      final neu = old.replaceFirst('line5', 'LINE5').replaceFirst(
            'line45',
            'LINE45',
          );
      final text = diffSummaryJson(old, neu)!['diff'] as String;
      expect(text, contains('…'));
      expect(text, contains('-line5'));
      expect(text, contains('+LINE45'));
      expect(text, isNot(contains('line20')));

      final bigOld = List.generate(400, (i) => 'x$i').join('\n');
      final bigNew = List.generate(400, (i) => 'y$i').join('\n');
      final big = diffSummaryJson(bigOld, bigNew)!['diff'] as String;
      expect(big, contains('（diff 过长，已截断）'));
      expect('\n'.allMatches(big).length, lessThan(130));
    });
  });
}
