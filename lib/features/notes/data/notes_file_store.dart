import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';

/// Filesystem-backed store for notes — the Flutter port of Cherry Studio's
/// `SimpleNoteService` / `NotesService`. Notes are real `.md` files under a
/// root directory; folders form the tree.
///
/// MVP storage = the app documents directory (`<appDocuments>/notes`), so it
/// works out of the box on every platform with no permissions. A user-selected
/// directory (and Android SAF) is a later phase (see
/// `docs/design/notes-feature-research.md` §8).
class NotesFileStore {
  Directory? _rootCache;

  /// The notes root directory, created on first access.
  Future<Directory> _root() async {
    final cached = _rootCache;
    if (cached != null) return cached;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'notes'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _rootCache = dir;
    return dir;
  }

  /// The absolute path of the notes root (for display in settings).
  Future<String> rootPath() async => (await _root()).path;

  String _abs(String root, String relPath) =>
      relPath.isEmpty ? root : p.join(root, p.joinAll(relPath.split('/')));

  String _rel(String root, String absPath) =>
      p.relative(absPath, from: root).replaceAll(r'\', '/');

  /// Lists the folders and `.md` notes directly under [relPath] (root when
  /// empty). Non-markdown files are ignored. Unsorted — sorting is the
  /// controller's job.
  Future<List<NoteNode>> list(String relPath) async {
    final root = (await _root()).path;
    final dir = Directory(_abs(root, relPath));
    if (!dir.existsSync()) return const <NoteNode>[];

    final out = <NoteNode>[];
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue; // hidden
      final isDir = entity is Directory;
      if (!isDir && !name.toLowerCase().endsWith('.md')) continue;
      final stat = entity.statSync();
      out.add(
        NoteNode(
          name: name,
          relativePath: _rel(root, entity.path),
          isDirectory: isDir,
          modifiedAt: stat.modified,
          createdAt: stat.changed,
          size: isDir ? null : stat.size,
        ),
      );
    }
    return out;
  }

  /// Reads a note's raw markdown content.
  Future<String> read(String relPath) async {
    final root = (await _root()).path;
    final file = File(_abs(root, relPath));
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  /// Overwrites a note's content (UTF-8).
  Future<void> write(String relPath, String content) async {
    final root = (await _root()).path;
    await File(_abs(root, relPath)).writeAsString(content);
  }

  /// Creates a new `.md` note under [parentRel] with a collision-safe name and
  /// returns its relative path.
  Future<String> createNote(String parentRel, String rawName) async {
    final root = (await _root()).path;
    var base = rawName.trim().isEmpty ? '未命名笔记' : rawName.trim();
    if (base.toLowerCase().endsWith('.md')) {
      base = base.substring(0, base.length - 3);
    }
    final name = _uniqueName(_abs(root, parentRel), base, '.md');
    final file = File(p.join(_abs(root, parentRel), name));
    await file.create(recursive: true);
    return _rel(root, file.path);
  }

  /// Creates a new folder under [parentRel] and returns its relative path.
  Future<String> createFolder(String parentRel, String rawName) async {
    final root = (await _root()).path;
    final base = rawName.trim().isEmpty ? '新建文件夹' : rawName.trim();
    final name = _uniqueName(_abs(root, parentRel), base, '');
    final dir = Directory(p.join(_abs(root, parentRel), name));
    await dir.create(recursive: true);
    return _rel(root, dir.path);
  }

  /// Renames a file or folder in place; returns the new relative path.
  Future<String> rename(String relPath, bool isDirectory, String rawName) async {
    final root = (await _root()).path;
    final abs = _abs(root, relPath);
    final parent = p.dirname(abs);
    var newName = rawName.trim();
    if (!isDirectory && !newName.toLowerCase().endsWith('.md')) {
      newName = '$newName.md';
    }
    final target = p.join(parent, newName);
    if (target == abs) return relPath;
    if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
      throw const FileSystemException('同名文件或文件夹已存在');
    }
    final renamed = isDirectory
        ? await Directory(abs).rename(target)
        : await File(abs).rename(target);
    return _rel(root, renamed.path);
  }

  /// Deletes a file or folder (folders recursively).
  Future<void> delete(String relPath, bool isDirectory) async {
    final root = (await _root()).path;
    final abs = _abs(root, relPath);
    if (isDirectory) {
      final dir = Directory(abs);
      if (dir.existsSync()) await dir.delete(recursive: true);
    } else {
      final file = File(abs);
      if (file.existsSync()) await file.delete();
    }
  }

  /// Returns a name not already taken in [parentAbs], appending ` (n)` on
  /// collision. [ext] is the extension to test/append (`.md` or empty).
  String _uniqueName(String parentAbs, String base, String ext) {
    String candidate(int n) => n == 0 ? '$base$ext' : '$base ($n)$ext';
    var n = 0;
    while (FileSystemEntity.typeSync(p.join(parentAbs, candidate(n))) !=
        FileSystemEntityType.notFound) {
      n++;
    }
    return candidate(n);
  }
}
