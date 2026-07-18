import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_op_service.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

import 'in_memory_workspace_backend.dart';

/// In-memory backend with a scripted [exec] for permission tests.
class _ExecBackend extends InMemoryWorkspaceBackend {
  WorkspaceExecResult execResult =
      const WorkspaceExecResult(stdout: '', stderr: '', exitCode: 0);
  final List<String> commands = [];

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        canExec: true,
        canWatch: true,
        isRemote: false,
      );

  @override
  Future<WorkspaceExecResult> exec(
    String command, {
    String? workingDirectory,
    Duration? timeout,
    Future<void>? cancelSignal,
    void Function(String chunk)? onOutput,
  }) async {
    commands.add(command);
    return execResult;
  }
}

void main() {
  const root = '/ws';

  late InMemoryWorkspaceBackend backend;
  late Map<String, String> parentIndex;
  late WorkspaceFileOpService service;

  WorkspaceFileOpService buildService() => WorkspaceFileOpService(
        backend: backend,
        rootPath: root,
        parentOf: (path) => parentIndex[path],
      );

  Future<WorkspaceEntry> entryOf(String path) => backend.getFileInfo(path);

  // Loads [dir]'s listing into the parent index (the tree does this as it
  // expands directories).
  Future<void> index(String dir) async {
    for (final e in await backend.listDir(dir)) {
      parentIndex[e.path] = dir;
    }
  }

  setUp(() {
    backend = InMemoryWorkspaceBackend(protectedPaths: {'$root/sdcard'});
    backend.seedDir(root);
    parentIndex = {};
    service = buildService();
  });

  group('conflicts', () {
    test('findConflict returns the same-name entry or null', () async {
      backend.seedFile('$root/a.txt');
      expect((await service.findConflict(root, 'a.txt'))?.name, 'a.txt');
      expect(await service.findConflict(root, 'b.txt'), isNull);
    });

    test('copyKeepBothName picks a free name in the destination', () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/dst/a.txt')
        ..seedFile('$root/a.txt');
      final name = await service.copyKeepBothName(
        await entryOf('$root/a.txt'),
        '$root/dst',
      );
      expect(name, isNot('a.txt'));
      final taken = await service.siblingNames('$root/dst');
      expect(taken.contains(name), isFalse);
    });

    test('moveKeepBoth renames to a name free in both dirs, then moves',
        () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/dst/a.txt')
        ..seedFile('$root/a.txt');
      final moved = await service.moveKeepBoth(
        await entryOf('$root/a.txt'),
        root,
        '$root/dst',
      );
      expect(moved.movedName, isNot('a.txt'));
      expect(moved.originalName, 'a.txt');
      expect(backend.exists('$root/a.txt'), isFalse);
      expect(backend.exists('$root/dst/${moved.movedName}'), isTrue);
      expect(backend.exists('$root/dst/a.txt'), isTrue);
    });
  });

  group('undo move', () {
    test('undoMove moves back and restores the original name', () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/dst/a.txt')
        ..seedFile('$root/a.txt', 'src');
      await index(root);
      final moved = await service.moveKeepBoth(
        await entryOf('$root/a.txt'),
        root,
        '$root/dst',
      );
      expect(moved.sourcePath, '$root/a.txt');
      final restored = await service.undoMove(moved);
      expect(restored, '$root/a.txt');
      expect(backend.exists('$root/a.txt'), isTrue);
      expect(await backend.readFile('$root/a.txt'), 'src');
      expect(backend.exists('$root/dst/${moved.movedName}'), isFalse);
    });

    test('plain move records an undoable entry', () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/a.txt');
      await index(root);
      final moved = await service.move(
        await entryOf('$root/a.txt'),
        root,
        '$root/dst',
      );
      expect(moved.movedName, 'a.txt');
      expect(moved.sourceDir, root);
      await service.undoMove(moved);
      expect(backend.exists('$root/a.txt'), isTrue);
      expect(backend.exists('$root/dst/a.txt'), isFalse);
    });

    test('moveMany returns undoable move records', () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/a.txt')
        ..seedFile('$root/b.txt');
      await index(root);
      final result = await service.moveMany([
        await entryOf('$root/a.txt'),
        await entryOf('$root/b.txt'),
      ], '$root/dst');
      expect(result.moves, hasLength(2));
      for (final moved in result.moves.reversed) {
        await service.undoMove(moved);
      }
      expect(backend.exists('$root/a.txt'), isTrue);
      expect(backend.exists('$root/b.txt'), isTrue);
      expect(backend.exists('$root/dst/a.txt'), isFalse);
    });
  });

  group('permissions', () {
    test('isValidChmodMode accepts octal and symbolic modes', () {
      for (final ok in ['644', '0755', 'u+x', 'go-w', 'a=r', 'u+rw,go-w']) {
        expect(WorkspaceFileOpService.isValidChmodMode(ok), isTrue, reason: ok);
      }
      for (final bad in ['', '99', '77777', 'rm -rf /', 'u+q', '755; ls']) {
        expect(
          WorkspaceFileOpService.isValidChmodMode(bad),
          isFalse,
          reason: bad,
        );
      }
    });

    test('statPermissions parses stat output; chmod validates mode', () async {
      final execBackend = _ExecBackend();
      execBackend.seedDir(root);
      execBackend.seedFile('$root/a.txt');
      final svc = WorkspaceFileOpService(
        backend: execBackend,
        rootPath: root,
        parentOf: (path) => parentIndex[path],
      );
      execBackend.execResult =
          const WorkspaceExecResult(stdout: '755 -rwxr-xr-x u:g\n', stderr: '', exitCode: 0);
      final entry = await execBackend.getFileInfo('$root/a.txt');
      final perms = await svc.statPermissions(entry);
      expect(perms.octal, '755');
      expect(perms.symbolic, '-rwxr-xr-x');
      expect(perms.owner, 'u:g');
      expect(execBackend.commands.single, contains("stat -c '%a %A %U:%G'"));

      await svc.chmod(entry, '644', recursive: true);
      expect(execBackend.commands.last, "chmod -R 644 '$root/a.txt'");

      await expectLater(svc.chmod(entry, 'bad; rm'), throwsArgumentError);
    });
  });

  group('import / zip', () {
    test('importFiles writes bytes with keep-both naming', () async {
      backend.seedFile('$root/a.txt', 'old');
      await index(root);
      final result = await service.importFiles(root, [
        ImportFileData(name: 'a.txt', bytes: Uint8List.fromList('new'.codeUnits)),
        ImportFileData(name: 'b.txt', bytes: Uint8List.fromList('bb'.codeUnits)),
      ]);
      expect(result.imported, 2);
      expect(result.skipped, 0);
      expect(await backend.readFile('$root/a.txt'), 'old');
      expect(await backend.readFile('$root/a (2).txt'), 'new');
      expect(await backend.readFile('$root/b.txt'), 'bb');
    });

    test('zipEntry then extractZip round-trips a directory tree', () async {
      backend
        ..seedFile('$root/proj/main.dart', 'void main() {}')
        ..seedFile('$root/proj/lib/util.dart', 'x')
        ..seedDir('$root/proj/empty');
      await index(root);
      await index('$root/proj');
      final zipName =
          await service.zipEntry(await entryOf('$root/proj'));
      expect(zipName, 'proj.zip');
      expect(backend.exists('$root/proj.zip'), isTrue);

      await index(root);
      final dirName =
          await service.extractZip(await entryOf('$root/proj.zip'));
      expect(dirName, 'proj (2)'); // 'proj' is taken by the source dir
      expect(
        await backend.readFile('$root/proj (2)/proj/main.dart'),
        'void main() {}',
      );
      expect(
        await backend.readFile('$root/proj (2)/proj/lib/util.dart'),
        'x',
      );
      expect(backend.exists('$root/proj (2)/proj/empty'), isTrue);
    });

    test('extractZip skips zip-slip entries', () async {
      final archive = Archive()
        ..add(ArchiveFile.bytes('../evil.txt', Uint8List.fromList('x'.codeUnits)))
        ..add(ArchiveFile.bytes('ok.txt', Uint8List.fromList('ok'.codeUnits)));
      final bytes = ZipEncoder().encodeBytes(archive);
      backend.seedFile('$root/p.zip', String.fromCharCodes(bytes));
      await index(root);
      final dirName = await service.extractZip(await entryOf('$root/p.zip'));
      expect(dirName, 'p');
      expect(await backend.readFile('$root/p/ok.txt'), 'ok');
      expect(backend.exists('$root/evil.txt'), isFalse);
      expect(backend.exists('$root/p/evil.txt'), isFalse);
    });
  });

  group('creation', () {
    test('createFile returns a resolvable entry', () async {
      final entry = await service.createFile(root, 'x.txt', content: 'hi');
      expect(entry.name, 'x.txt');
      expect(entry.path, '$root/x.txt');
      expect(await backend.readFile(entry.path), 'hi');
    });
  });

  group('duplicate', () {
    test('copies next to the source with a fresh keep-both name', () async {
      backend
        ..seedDir('$root/lib')
        ..seedFile('$root/lib/a.txt', 'hi');
      await index(root);
      await index('$root/lib');
      final name = await service.duplicate(await entryOf('$root/lib/a.txt'));
      expect(name, isNot('a.txt'));
      expect(await backend.readFile('$root/lib/$name'), 'hi');
      expect(backend.exists('$root/lib/a.txt'), isTrue);
    });

    test('skips names already taken by earlier duplicates', () async {
      backend
        ..seedFile('$root/a.txt')
        ..seedFile('$root/a (2).txt');
      await index(root);
      final name = await service.duplicate(await entryOf('$root/a.txt'));
      expect(name, 'a (3).txt');
    });
  });

  group('trash', () {
    test('moveToTrash creates the trash dir and preserves the name', () async {
      backend.seedFile('$root/a.txt');
      await index(root);
      final trashed = await service.moveToTrash(await entryOf('$root/a.txt'));
      expect(trashed.originalName, 'a.txt');
      expect(trashed.movedName, 'a.txt');
      expect(trashed.sourceDir, root);
      expect(backend.exists('$root/a.txt'), isFalse);
      expect(
        backend.exists(
          '$root/${WorkspaceFileOpService.kTrashDirName}/a.txt',
        ),
        isTrue,
      );
    });

    test('moveToTrash keeps both on a name collision in the trash', () async {
      backend
        ..seedFile('$root/a.txt')
        ..seedFile(
          '$root/${WorkspaceFileOpService.kTrashDirName}/a.txt',
        );
      await index(root);
      final trashed = await service.moveToTrash(await entryOf('$root/a.txt'));
      expect(trashed.movedName, isNot('a.txt'));
      expect(trashed.originalName, 'a.txt');
    });

    test('undoTrash restores the original name and location', () async {
      backend
        ..seedFile('$root/a.txt')
        ..seedFile(
          '$root/${WorkspaceFileOpService.kTrashDirName}/a.txt',
        );
      await index(root);
      final trashed = await service.moveToTrash(await entryOf('$root/a.txt'));
      expect(trashed.sourcePath, '$root/a.txt');
      final restored = await service.undoTrash(trashed);
      expect(restored, '$root/a.txt');
      expect(backend.exists('$root/a.txt'), isTrue);
    });

    test('restoreFromTrash moves back to the root, keep-both on conflict',
        () async {
      const trash = '$root/${WorkspaceFileOpService.kTrashDirName}';
      backend
        ..seedFile('$trash/a.txt')
        ..seedFile('$root/a.txt');
      await index(root);
      await index(trash);
      final name = await service.restoreFromTrash(await entryOf('$trash/a.txt'));
      expect(name, isNot('a.txt'));
      expect(backend.exists('$root/$name'), isTrue);
    });

    test('isInTrash uses the cached ancestor chain', () async {
      const trash = '$root/${WorkspaceFileOpService.kTrashDirName}';
      backend
        ..seedDir('$trash/sub')
        ..seedFile('$trash/sub/a.txt');
      await index(root);
      await index(trash);
      await index('$trash/sub');
      expect(
        service.isInTrash(await entryOf('$trash/sub/a.txt'), trash),
        isTrue,
      );
      backend.seedFile('$root/b.txt');
      await index(root);
      expect(service.isInTrash(await entryOf('$root/b.txt'), trash), isFalse);
    });
  });

  group('batch', () {
    test('deleteManyToTrash skips protected paths and counts them', () async {
      backend
        ..seedFile('$root/a.txt')
        ..seedDir('$root/sdcard');
      await index(root);
      final result = await service.deleteManyToTrash([
        await entryOf('$root/a.txt'),
        await entryOf('$root/sdcard'),
      ]);
      expect(result.trashed.length, 1);
      expect(result.skipped, 1);
      expect(backend.exists('$root/sdcard'), isTrue);
    });

    test('deleteManyToTrash skips entries already in the trash', () async {
      const trash = '$root/${WorkspaceFileOpService.kTrashDirName}';
      backend.seedFile('$trash/a.txt');
      await index(root);
      await index(trash);
      final result = await service.deleteManyToTrash([
        await entryOf('$trash/a.txt'),
      ]);
      expect(result.trashed, isEmpty);
      expect(result.skipped, 1);
    });

    test('moveMany moves with keep-both, skips same-dir and self moves',
        () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/dst/a.txt')
        ..seedFile('$root/a.txt')
        ..seedFile('$root/dst/already.txt');
      await index(root);
      await index('$root/dst');
      final result = await service.moveMany([
        await entryOf('$root/a.txt'), // conflicts → keep-both
        await entryOf('$root/dst/already.txt'), // same dir → skip
        await entryOf('$root/dst'), // self → skip
      ], '$root/dst');
      expect(result.moved, 1);
      expect(result.skipped, 2);
      expect(result.touchedDirs, containsAll({root, '$root/dst'}));
      expect(backend.exists('$root/a.txt'), isFalse);
      expect(backend.exists('$root/dst/a.txt'), isTrue);
    });

    test('moveMany skips moving a directory into its own subtree', () async {
      backend.seedDir('$root/dir/sub');
      await index(root);
      await index('$root/dir');
      final result = await service.moveMany(
        [await entryOf('$root/dir')],
        '$root/dir/sub',
      );
      expect(result.moved, 0);
      expect(result.skipped, 1);
    });

    test('copyMany keep-both on conflict and skips copies into self',
        () async {
      backend
        ..seedDir('$root/dst')
        ..seedFile('$root/dst/a.txt')
        ..seedFile('$root/a.txt');
      await index(root);
      await index('$root/dst');
      final result = await service.copyMany([
        await entryOf('$root/a.txt'),
        await entryOf('$root/dst'),
      ], '$root/dst');
      expect(result.copied, 1);
      expect(result.skipped, 1);
      expect(backend.exists('$root/a.txt'), isTrue);
      final names = await service.siblingNames('$root/dst');
      expect(names.length, 2); // a.txt + the keep-both copy
    });
  });
}
