import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_search_result.dart';

/// Filesystem-backed store for notes — the Flutter port of Cherry Studio's
/// `SimpleNoteService` / `NotesService`. Notes are real `.md` files under a
/// root directory; folders form the tree.
///
/// Default storage = the app documents directory (`<appDocuments>/notes`), so
/// it works out of the box on every platform with no permissions. A user can
/// override the root with [customRoot] (picked via the system directory picker)
/// to keep notes in a shared location — interop with the original/web app.
///
/// Note: on Android, an arbitrary directory may require SAF; this uses whatever
/// path the picker returns and falls back to the default if it isn't usable.
class NotesFileStore {
  NotesFileStore({this.customRoot});

  /// Absolute path of a user-chosen root, or `null`/empty for the default.
  final String? customRoot;

  Directory? _rootCache;

  /// The notes root directory, created on first access.
  Future<Directory> _root() async {
    final cached = _rootCache;
    if (cached != null) return cached;
    final custom = customRoot;
    Directory dir;
    if (custom != null && custom.trim().isNotEmpty) {
      dir = Directory(custom.trim());
      // Fall back to the default if the custom path can't be used.
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } on FileSystemException {
          dir = await _defaultDir();
        }
      }
    } else {
      dir = await _defaultDir();
    }
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _rootCache = dir;
    return dir;
  }

  Future<Directory> _defaultDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'notes'));
  }

  /// The absolute path of the notes root (for display in settings).
  Future<String> rootPath() async => (await _root()).path;

  /// The absolute filesystem path of a note/folder, e.g. for sharing the real
  /// `.md` file through the OS share sheet.
  Future<String> absolutePath(String relPath) async =>
      _abs((await _root()).path, relPath);

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

  /// Recursively full-text-searches all notes under the root, matching both
  /// file names and content. Pure-Dart port of Cherry Studio's
  /// `NotesSearchService` (no native plugin): folder/file walk + regex match,
  /// relevance-scored. Returns results sorted by descending score.
  Future<List<NoteSearchResult>> search(
    String keyword, {
    bool caseSensitive = false,
    int maxResults = 100,
    int maxMatchesPerFile = 10,
    int contextLength = 40,
    int maxFileSizeBytes = 2 * 1024 * 1024,
    int maxDepth = 8,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const <NoteSearchResult>[];
    final root = (await _root()).path;
    final pattern = RegExp(
      RegExp.escape(trimmed),
      caseSensitive: caseSensitive,
    );

    final results = <NoteSearchResult>[];
    await _walk(
      Directory(root),
      root,
      pattern,
      0,
      maxDepth,
      maxMatchesPerFile,
      contextLength,
      maxFileSizeBytes,
      maxResults,
      results,
    );
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  Future<void> _walk(
    Directory dir,
    String root,
    RegExp pattern,
    int depth,
    int maxDepth,
    int maxMatchesPerFile,
    int contextLength,
    int maxFileSizeBytes,
    int maxResults,
    List<NoteSearchResult> out,
  ) async {
    if (depth > maxDepth || out.length >= maxResults) return;
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final entity in entries) {
      if (out.length >= maxResults) return;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        await _walk(entity, root, pattern, depth + 1, maxDepth,
            maxMatchesPerFile, contextLength, maxFileSizeBytes, maxResults, out);
        continue;
      }
      if (entity is! File || !name.toLowerCase().endsWith('.md')) continue;

      final stat = entity.statSync();
      final node = NoteNode(
        name: name,
        relativePath: _rel(root, entity.path),
        isDirectory: false,
        modifiedAt: stat.modified,
        createdAt: stat.changed,
        size: stat.size,
      );

      final nameMatches = pattern.hasMatch(node.title);
      var matches = const <NoteSearchMatch>[];
      if (stat.size <= maxFileSizeBytes) {
        matches = _matchContent(
          await entity.readAsString().catchError((_) => ''),
          pattern,
          maxMatchesPerFile,
          contextLength,
        );
      }
      if (!nameMatches && matches.isEmpty) continue;

      final type = nameMatches && matches.isNotEmpty
          ? NoteMatchType.both
          : (nameMatches ? NoteMatchType.filename : NoteMatchType.content);
      out.add(
        NoteSearchResult(
          node: node,
          matchType: type,
          matches: matches,
          score: _score(node, pattern, nameMatches, matches.length),
        ),
      );
    }
  }

  List<NoteSearchMatch> _matchContent(
    String content,
    RegExp pattern,
    int maxMatches,
    int contextLength,
  ) {
    if (content.isEmpty) return const <NoteSearchMatch>[];
    final out = <NoteSearchMatch>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length && out.length < maxMatches; i++) {
      final line = lines[i];
      for (final m in pattern.allMatches(line)) {
        const before = 2;
        final ctxStart = (m.start - before).clamp(0, line.length);
        final ctxEnd = (m.end + contextLength).clamp(0, line.length);
        final prefix = ctxStart > 0 ? '…' : '';
        final context = prefix + line.substring(ctxStart, ctxEnd);
        out.add(
          NoteSearchMatch(
            lineNumber: i + 1,
            context: context,
            matchStart: prefix.length + (m.start - ctxStart),
            matchEnd: prefix.length + (m.end - ctxStart),
          ),
        );
        if (out.length >= maxMatches) break;
      }
    }
    return out;
  }

  int _score(NoteNode node, RegExp pattern, bool nameMatches, int contentHits) {
    var score = 0;
    final title = node.title;
    if (nameMatches) {
      score += pattern.stringMatch(title) == title ? 200 : 100;
    }
    score += (contentHits * 2).clamp(0, 50);
    final days = DateTime.now().difference(node.modifiedAt).inDays;
    score += (10 - days).clamp(0, 10); // recency boost
    return score;
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
