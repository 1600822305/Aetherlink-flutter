// Verifies the in-app file-change bus on [LocalSafBackend]: every mutation
// that goes through the backend emits a [WorkspaceChangeEvent] on watch(), so
// the browse / edit views can refresh live (canWatch contract). SAF can't see
// external edits, but reporting its own mutations is what the UI relies on.
//
// The real SAF plugin talks to a platform channel; here a fake [AetherlinkSaf]
// facade is injected so the backend runs without any native side.

import 'package:aetherlink_saf/aetherlink_saf.dart' as saf;
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/mock_workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A no-native [saf.AetherlinkSaf] facade: every mutation returns a plausible
/// result so [LocalSafBackend] can run and emit its change events under test.
class _FakeSaf extends saf.AetherlinkSaf {
  _FakeSaf();

  int replaceCount = 2;
  bool diffSuccess = true;

  @override
  Future<void> writeFile({
    required String path,
    required String content,
    String encoding = 'utf8',
    bool append = false,
  }) async {}

  @override
  Future<saf.PathResult> createFile({
    required String parentPath,
    required String name,
    String? content,
    String encoding = 'utf8',
    String? mimeType,
  }) async =>
      saf.PathResult(path: '$parentPath/$name');

  @override
  Future<saf.PathResult> createDirectory({
    required String parentPath,
    required String name,
    bool recursive = false,
  }) async =>
      saf.PathResult(path: '$parentPath/$name');

  @override
  Future<void> deleteFile({required String path}) async {}

  @override
  Future<void> deleteDirectory({
    required String path,
    bool recursive = false,
  }) async {}

  @override
  Future<saf.PathResult> renameFile({
    required String path,
    required String newName,
  }) async =>
      saf.PathResult(path: 'renamed:$newName');

  @override
  Future<saf.PathResult> moveFile({
    required String sourcePath,
    required String destinationParent,
  }) async =>
      saf.PathResult(path: '$destinationParent/moved');

  @override
  Future<saf.PathResult> copyFile({
    required String sourcePath,
    required String destinationParent,
    String? newName,
    bool overwrite = false,
  }) async =>
      saf.PathResult(path: '$destinationParent/copy');

  @override
  Future<void> insertContent({
    required String path,
    required int line,
    required String content,
  }) async {}

  @override
  Future<saf.ReplaceResult> replaceInFile({
    required String path,
    required String search,
    required String replace,
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) async =>
      saf.ReplaceResult(replacements: replaceCount, modified: replaceCount > 0);

  @override
  Future<saf.ApplyDiffResult> applyDiff({
    required String path,
    required String diff,
    saf.DiffFormat format = saf.DiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
    int? rangeStartLine,
    int? rangeEndLine,
  }) async =>
      saf.ApplyDiffResult(
        success: diffSuccess,
        linesChanged: 1,
        linesAdded: 0,
        linesDeleted: 0,
      );
}

void main() {
  late _FakeSaf plugin;
  late LocalSafBackend backend;
  late List<WorkspaceChangeEvent> events;

  setUp(() {
    plugin = _FakeSaf();
    backend = LocalSafBackend(plugin: plugin);
    events = [];
    // Subscribe before any mutation: the backend suppresses emission when there
    // are no listeners.
    backend.watch().listen(events.add);
  });

  // Broadcast delivery is async; flush the microtask/event queue before asserts.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('declares it can watch', () {
    expect(backend.capabilities.canWatch, isTrue);
  });

  test('writeFile emits a modified event', () async {
    await backend.writeFile('a.txt', 'hi');
    await settle();
    expect(events, hasLength(1));
    expect(events.single.kind, WorkspaceChangeKind.modified);
    expect(events.single.path, 'a.txt');
  });

  test('createFile emits created with the parent dir', () async {
    final path = await backend.createFile('dir', 'f.txt', content: 'x');
    await settle();
    expect(path, 'dir/f.txt');
    expect(events.single.kind, WorkspaceChangeKind.created);
    expect(events.single.path, 'dir/f.txt');
    expect(events.single.parentPath, 'dir');
  });

  test('createDirectory emits created with the parent dir', () async {
    await backend.createDirectory('dir', 'sub');
    await settle();
    expect(events.single.kind, WorkspaceChangeKind.created);
    expect(events.single.parentPath, 'dir');
  });

  test('delete emits a deleted event (file and dir)', () async {
    await backend.delete('a.txt');
    await backend.delete('d', isDirectory: true, recursive: true);
    await settle();
    expect(events, hasLength(2));
    expect(events.every((e) => e.kind == WorkspaceChangeKind.deleted), isTrue);
    expect(events.map((e) => e.path), ['a.txt', 'd']);
  });

  test('rename emits moved with fromPath', () async {
    final path = await backend.rename('old.txt', 'new.txt');
    await settle();
    expect(path, 'renamed:new.txt');
    expect(events.single.kind, WorkspaceChangeKind.moved);
    expect(events.single.fromPath, 'old.txt');
    expect(events.single.path, 'renamed:new.txt');
  });

  test('move emits moved with fromPath and dest parent', () async {
    await backend.move('s.txt', 'dest');
    await settle();
    expect(events.single.kind, WorkspaceChangeKind.moved);
    expect(events.single.fromPath, 's.txt');
    expect(events.single.parentPath, 'dest');
    expect(events.single.path, 'dest/moved');
  });

  test('copy emits created with dest parent', () async {
    await backend.copy('s.txt', 'dest');
    await settle();
    expect(events.single.kind, WorkspaceChangeKind.created);
    expect(events.single.parentPath, 'dest');
  });

  test('insertContent emits modified', () async {
    await backend.insertContent('a.txt', 1, 'line');
    await settle();
    expect(events.single.kind, WorkspaceChangeKind.modified);
  });

  test('replaceInFile emits modified only when something changed', () async {
    await backend.replaceInFile('a.txt', 'x', 'y');
    await settle();
    expect(events, hasLength(1));
    expect(events.single.kind, WorkspaceChangeKind.modified);

    plugin.replaceCount = 0;
    await backend.replaceInFile('a.txt', 'x', 'y');
    await settle();
    // No new event when no replacements were made.
    expect(events, hasLength(1));
  });

  test('applyDiff emits modified only on success', () async {
    plugin.diffSuccess = false;
    await backend.applyDiff('a.txt', 'diff');
    await settle();
    expect(events, isEmpty);

    plugin.diffSuccess = true;
    await backend.applyDiff('a.txt', 'diff');
    await settle();
    expect(events.single.kind, WorkspaceChangeKind.modified);
  });

  group('non-watching backend contract', () {
    test('mock backend cannot watch and watch() throws', () {
      final mock = MockWorkspaceBackend();
      expect(mock.capabilities.canWatch, isFalse);
      expect(mock.watch, throwsUnsupportedError);
    });
  });
}
