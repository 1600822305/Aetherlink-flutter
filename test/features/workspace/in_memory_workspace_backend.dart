import 'dart:async';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A writable in-memory [WorkspaceBackend] for unit tests: posix-style paths,
/// full create/rename/move/copy/delete support and a broadcast [watch]
/// stream. Also counts [listDir] calls so tests can assert caching / budget
/// behaviour.
class InMemoryWorkspaceBackend extends WorkspaceBackend {
  InMemoryWorkspaceBackend({this.protectedPaths = const {}});

  final Set<String> protectedPaths;

  final _Node _root = _Node.dir('');

  final StreamController<WorkspaceChangeEvent> _events =
      StreamController.broadcast();

  /// listDir invocations per path, for cache/budget assertions.
  final Map<String, int> listDirCalls = {};

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        canExec: false,
        canWatch: true,
        isRemote: false,
      );

  @override
  Future<String> echo(String value) async => value;

  @override
  Stream<WorkspaceChangeEvent> watch() => _events.stream;

  void emit(WorkspaceChangeEvent event) => _events.add(event);

  @override
  bool isProtectedPath(String path) => protectedPaths.contains(path);

  // ===== helpers =====

  List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  _Node _dirAt(String path) {
    var node = _root;
    for (final seg in _segments(path)) {
      final child = node.children[seg];
      if (child == null || !child.isDir) {
        throw StateError('not a directory: $path');
      }
      node = child;
    }
    return node;
  }

  ({_Node parent, _Node node, String name}) _lookup(String path) {
    final segs = _segments(path);
    if (segs.isEmpty) throw StateError('no entry at root path');
    final parent = _dirAt('/${segs.sublist(0, segs.length - 1).join('/')}');
    final node = parent.children[segs.last];
    if (node == null) throw StateError('not found: $path');
    return (parent: parent, node: node, name: segs.last);
  }

  String _join(String dir, String name) =>
      dir == '/' ? '/$name' : '$dir/$name';

  WorkspaceEntry _entry(String dirPath, _Node node) => WorkspaceEntry(
        name: node.name,
        path: _join(dirPath, node.name),
        isDirectory: node.isDir,
        size: node.content?.length ?? 0,
        mtime: 0,
        isHidden: node.name.startsWith('.'),
      );

  /// Seeds a directory (creating ancestors) — test setup helper.
  void seedDir(String path) {
    var node = _root;
    for (final seg in _segments(path)) {
      node = node.children.putIfAbsent(seg, () => _Node.dir(seg));
    }
  }

  /// Seeds a file with [content] — test setup helper.
  void seedFile(String path, [String content = '']) {
    final segs = _segments(path);
    seedDir('/${segs.sublist(0, segs.length - 1).join('/')}');
    _dirAt('/${segs.sublist(0, segs.length - 1).join('/')}')
        .children[segs.last] = _Node.file(segs.last, content);
  }

  bool exists(String path) {
    try {
      _lookup(path);
      return true;
    } catch (_) {
      return _segments(path).isEmpty;
    }
  }

  // ===== reads =====

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    listDirCalls[path] = (listDirCalls[path] ?? 0) + 1;
    final dir = _dirAt(path);
    return [for (final n in dir.children.values) _entry(path, n)];
  }

  @override
  Future<String> readFile(String path) async {
    final node = _lookup(path).node;
    if (node.isDir) throw StateError('is a directory: $path');
    return node.content ?? '';
  }

  @override
  Future<List<int>> readFileBytes(
    String path, {
    int offset = 0,
    int? length,
  }) async {
    final node = _lookup(path).node;
    if (node.isDir) throw StateError('is a directory: $path');
    final bytes = (node.content ?? '').codeUnits;
    final end =
        length == null ? bytes.length : (offset + length).clamp(0, bytes.length);
    return bytes.sublist(offset, end);
  }

  @override
  Future<WorkspaceEntry> getFileInfo(String path) async {
    final found = _lookup(path);
    final segs = _segments(path);
    final dirPath = '/${segs.sublist(0, segs.length - 1).join('/')}';
    return _entry(dirPath == '//' ? '/' : dirPath, found.node);
  }

  // ===== mutations =====

  @override
  Future<String> createFile(
    String parentPath,
    String name, {
    String? content,
  }) async {
    final dir = _dirAt(parentPath);
    if (dir.children.containsKey(name)) {
      throw StateError('already exists: $name');
    }
    dir.children[name] = _Node.file(name, content ?? '');
    return _join(parentPath, name);
  }

  @override
  Future<String> createFileBytes(
    String parentPath,
    String name,
    List<int> bytes,
  ) =>
      createFile(parentPath, name, content: String.fromCharCodes(bytes));

  @override
  Future<String> createDirectory(
    String parentPath,
    String name, {
    bool recursive = false,
  }) async {
    final dir = _dirAt(parentPath);
    final existing = dir.children[name];
    if (existing != null) {
      if (existing.isDir) return _join(parentPath, name);
      throw StateError('already exists: $name');
    }
    dir.children[name] = _Node.dir(name);
    return _join(parentPath, name);
  }

  @override
  Future<void> delete(
    String path, {
    bool isDirectory = false,
    bool recursive = false,
  }) async {
    if (isProtectedPath(path)) throw StateError('protected: $path');
    final found = _lookup(path);
    found.parent.children.remove(found.name);
  }

  @override
  Future<String> rename(String path, String newName) async {
    if (isProtectedPath(path)) throw StateError('protected: $path');
    final found = _lookup(path);
    if (found.parent.children.containsKey(newName)) {
      throw StateError('already exists: $newName');
    }
    found.parent.children.remove(found.name);
    found.parent.children[newName] = found.node..name = newName;
    final segs = _segments(path)..removeLast();
    return _join('/${segs.join('/')}', newName);
  }

  @override
  Future<String> move(String sourcePath, String destinationParent) async {
    if (isProtectedPath(sourcePath)) throw StateError('protected: $sourcePath');
    final found = _lookup(sourcePath);
    final dest = _dirAt(destinationParent);
    if (dest.children.containsKey(found.name)) {
      throw StateError('already exists: ${found.name}');
    }
    found.parent.children.remove(found.name);
    dest.children[found.name] = found.node;
    return _join(destinationParent, found.name);
  }

  @override
  Future<String> copy(
    String sourcePath,
    String destinationParent, {
    String? newName,
    bool overwrite = false,
  }) async {
    final found = _lookup(sourcePath);
    final dest = _dirAt(destinationParent);
    final name = newName ?? found.name;
    if (dest.children.containsKey(name) && !overwrite) {
      throw StateError('already exists: $name');
    }
    dest.children[name] = found.node.deepCopy(name);
    return _join(destinationParent, name);
  }
}

class _Node {
  _Node.dir(this.name)
      : isDir = true,
        content = null;

  _Node.file(this.name, this.content) : isDir = false;

  String name;
  final bool isDir;
  String? content;
  final Map<String, _Node> children = {};

  _Node deepCopy(String newName) {
    final copy = isDir ? _Node.dir(newName) : _Node.file(newName, content);
    for (final e in children.entries) {
      copy.children[e.key] = e.value.deepCopy(e.key);
    }
    return copy;
  }
}
