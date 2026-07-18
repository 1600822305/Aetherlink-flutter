import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/file_tree_controller.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_tree_sort.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

import 'in_memory_workspace_backend.dart';

void main() {
  const root = '/ws';

  late InMemoryWorkspaceBackend backend;
  late FileTreeController tree;
  late List<String> errors;
  late List<String> reveals;
  late int gitRefreshes;

  setUp(() {
    backend = InMemoryWorkspaceBackend();
    backend.seedDir(root);
    errors = [];
    reveals = [];
    gitRefreshes = 0;
    tree = FileTreeController(
      onError: errors.add,
      onGitRefresh: () => gitRefreshes++,
      onReveal: reveals.add,
    );
  });

  tearDown(() => tree.dispose());

  List<String> rowPaths() => [
        for (final r in tree.buildRows(false, TreeSortMode.nameAsc))
          if (r.entry != null) r.entry!.path,
      ];

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('binding / loading', () {
    test('bind loads and expands the root', () async {
      backend
        ..seedFile('$root/a.txt')
        ..seedDir('$root/lib');
      tree.bind(root, backend);
      await settle();
      expect(tree.isExpanded(root), isTrue);
      expect(rowPaths(), ['$root/lib', '$root/a.txt']);
    });

    test('hidden entries are filtered unless showHidden', () async {
      backend
        ..seedFile('$root/.env')
        ..seedFile('$root/a.txt');
      tree.bind(root, backend);
      await settle();
      expect(rowPaths(), ['$root/a.txt']);
      final all = tree.buildRows(true, TreeSortMode.nameAsc);
      expect(all.length, 2);
    });

    test('toggleDir expands lazily and caches; parentOf is derived', () async {
      backend.seedFile('$root/lib/main.dart');
      tree.bind(root, backend);
      await settle();
      tree.toggleDir(await backend.getFileInfo('$root/lib'));
      await settle();
      expect(rowPaths(), ['$root/lib', '$root/lib/main.dart']);
      expect(tree.parentOf('$root/lib/main.dart'), '$root/lib');
      // Collapse and re-expand: no extra listDir (cached).
      tree.toggleDir(await backend.getFileInfo('$root/lib'));
      tree.toggleDir(await backend.getFileInfo('$root/lib'));
      await settle();
      expect(backend.listDirCalls['$root/lib'], 1);
    });

    test('reload re-lists a directory and evicts vanished subtrees', () async {
      backend.seedFile('$root/lib/main.dart');
      tree.bind(root, backend);
      await settle();
      tree.toggleDir(await backend.getFileInfo('$root/lib'));
      await settle();
      // Delete lib out of band, then reload the root.
      await backend.delete('$root/lib', isDirectory: true, recursive: true);
      await tree.reload(root);
      expect(rowPaths(), isEmpty);
      expect(tree.parentOf('$root/lib/main.dart'), isNull);
    });

    test('refresh clears caches and reloads the root', () async {
      backend.seedFile('$root/a.txt');
      tree.bind(root, backend);
      await settle();
      backend.seedFile('$root/b.txt');
      tree.refresh();
      await settle();
      expect(rowPaths(), ['$root/a.txt', '$root/b.txt']);
    });

    test('collapseAll keeps only the root expanded', () async {
      backend.seedFile('$root/lib/main.dart');
      tree.bind(root, backend);
      await settle();
      tree.toggleDir(await backend.getFileInfo('$root/lib'));
      await settle();
      tree.collapseAll();
      expect(rowPaths(), ['$root/lib']);
      expect(tree.isExpanded(root), isTrue);
    });

    test('a listDir failure surfaces onError and collapses the dir', () async {
      backend.seedDir('$root/lib');
      tree.bind(root, backend);
      await settle();
      await backend.delete('$root/lib', isDirectory: true);
      tree.toggleDir(
        const WorkspaceEntry(
          name: 'lib',
          path: '$root/lib',
          isDirectory: true,
          size: 0,
          mtime: 0,
        ),
      );
      await settle();
      expect(errors, hasLength(1));
      expect(tree.isExpanded('$root/lib'), isFalse);
    });
  });

  group('selection', () {
    test('enter / toggle / takeSelection round-trip', () async {
      backend
        ..seedFile('$root/a.txt')
        ..seedFile('$root/b.txt');
      tree.bind(root, backend);
      await settle();
      tree.enterSelect();
      expect(tree.selecting, isTrue);
      final a = await backend.getFileInfo('$root/a.txt');
      tree.toggleSelected(a);
      tree.toggleSelected(await backend.getFileInfo('$root/b.txt'));
      tree.toggleSelected(a); // deselect
      final sel = tree.takeSelection();
      expect(sel.map((e) => e.path), ['$root/b.txt']);
      expect(tree.selecting, isFalse);
      expect(tree.selected, isEmpty);
    });

    test('bind resets selection state', () async {
      backend.seedFile('$root/a.txt');
      tree.bind(root, backend);
      await settle();
      tree.enterSelect();
      tree.toggleSelected(await backend.getFileInfo('$root/a.txt'));
      tree.bind(root, backend);
      expect(tree.selecting, isFalse);
      expect(tree.selected, isEmpty);
    });
  });

  group('reveal', () {
    test('revealPath derives the ancestor chain from posix paths', () async {
      backend.seedFile('$root/lib/src/deep.dart');
      tree.bind(root, backend);
      await settle();
      final found = await tree.revealPath('$root/lib/src/deep.dart');
      expect(found, isTrue);
      expect(tree.isExpanded('$root/lib'), isTrue);
      expect(tree.isExpanded('$root/lib/src'), isTrue);
      expect(reveals, ['$root/lib/src/deep.dart']);
    });

    test('revealPath returns false for a missing target', () async {
      backend.seedFile('$root/a.txt');
      tree.bind(root, backend);
      await settle();
      expect(await tree.revealPath('$root/nope/x.dart'), isFalse);
      expect(reveals, isEmpty);
    });

    test('revealActive dedups repeated reveals of the same path', () async {
      backend.seedFile('$root/lib/main.dart');
      tree.bind(root, backend);
      await settle();
      await tree.revealActive('$root/lib/main.dart');
      await tree.revealActive('$root/lib/main.dart');
      expect(reveals, hasLength(1));
    });

    test('the DFS fallback respects the listDir budget', () async {
      // A root whose name breaks path derivation (not a prefix of targets).
      backend.seedDir(root);
      for (var i = 0; i < kMaxRevealSearchDirs + 8; i++) {
        backend.seedDir('$root/d$i/x');
      }
      tree.bind(root, backend);
      await settle();
      // Target that doesn't exist → DFS visits at most the budget.
      final found = await tree.revealPath('/elsewhere/target.dart');
      expect(found, isFalse);
      final visited =
          backend.listDirCalls.values.fold<int>(0, (a, b) => a + b);
      expect(visited, lessThanOrEqualTo(kMaxRevealSearchDirs + 2));
    });
  });

  group('watch', () {
    test('events reload only already-loaded dirs, debounced', () async {
      backend.seedFile('$root/lib/main.dart');
      tree.bind(root, backend);
      await settle();
      backend.seedFile('$root/new.txt');
      backend
        ..emit(
          const WorkspaceChangeEvent(
            kind: WorkspaceChangeKind.created,
            path: '$root/new.txt',
            parentPath: root,
          ),
        )
        ..emit(
          const WorkspaceChangeEvent(
            kind: WorkspaceChangeKind.created,
            path: '$root/lib/other.dart',
            parentPath: '$root/lib', // not loaded → ignored
          ),
        );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(rowPaths(), contains('$root/new.txt'));
      // lib was never expanded/loaded, so it must not have been listed.
      expect(backend.listDirCalls['$root/lib'], isNull);
    });

    test('a watch burst triggers one throttled git refresh', () async {
      backend.seedFile('$root/a.txt');
      tree.bind(root, backend);
      await settle();
      final before = gitRefreshes; // bind itself schedules one refresh
      for (var i = 0; i < 5; i++) {
        backend.emit(
          const WorkspaceChangeEvent(
            kind: WorkspaceChangeKind.modified,
            path: '$root/a.txt',
            parentPath: root,
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(gitRefreshes, before + 1);
    });
  });
}
