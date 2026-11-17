import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/data/storage_repository_impl.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late Directory support;
  var imageCacheClears = 0;
  late StorageRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('aetherlink_storage_test_');
    documents = await Directory('${root.path}/documents').create();
    temporary = await Directory('${root.path}/temporary').create();
    support = await Directory('${root.path}/support').create();
    imageCacheClears = 0;
    repository = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => documents,
      temporaryDirectory: () async => temporary,
      supportDirectory: () async => support,
      workspaceNames: () async => {'known': '示例工作区'},
      clearImageCache: () async { imageCacheClears++; },
      canCleanCache: true,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> write(String relative, int bytes) async {
    final file = File('${documents.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(bytes, 1));
  }

  Future<void> writeSupport(String relative, int bytes) async {
    final file = File('${support.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(bytes, 1));
  }

  Future<void> topic(String id, String data) => db.customStatement(
    'INSERT INTO topic_rows (id, last_message_time_num, data) VALUES (?, 0, ?)',
    [id, data],
  );

  Future<void> message(String id, String topicId, {String role = 'user'}) =>
      db.customStatement(
        'INSERT INTO message_rows (id, topic_id, assistant_id, data, role) '
        "VALUES (?, ?, 'assistant', '{}', ?)",
        [id, topicId, role],
      );

  Future<void> block(String id, String messageId, String data) =>
      db.customStatement(
        'INSERT INTO message_block_rows (id, message_id, data) '
        'VALUES (?, ?, ?)',
        [id, messageId, data],
      );

  test('empty storage produces zero usage', () async {
    final report = await repository.scan();
    expect(report.totalBytes, 0);
    expect(report.totalFiles, 0);
    expect(report.items, isNotEmpty);
    expect(report.items.every((item) => item.usage.bytes == 0), isTrue);
    expect(await repository.topicUsage(), isEmpty);
    await repository.clean(StorageCleanup.fontCache);
    await repository.clean(StorageCleanup.workspaceHistory);
    await repository.cleanItem('terminalTmp');
  });

  test('directory resolution failures reach the caller', () async {
    final unavailable = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => throw FileSystemException('unavailable'),
      temporaryDirectory: () async => temporary,
    );
    await expectLater(unavailable.scan(), throwsA(isA<FileSystemException>()));
  });

  test('shared temporary directories are neither scanned nor cleaned', () async {
    final otherAppFile = File('${temporary.path}/other_app.tmp');
    await otherAppFile.writeAsBytes([1, 2, 3]);
    var resolutions = 0;
    final shared = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      temporaryDirectory: () async {
        resolutions++;
        return temporary;
      },
      canCleanCache: false,
    );
    final report = await shared.scan();
    expect(report.canCleanCache, isFalse);
    expect(report.categories[StorageCategory.cache]!.bytes, 0);
    expect(report.categories[StorageCategory.cache]!.fileCount, 0);
    await shared.clean(StorageCleanup.cache);
    expect(resolutions, 0);
    expect(await otherAppFile.readAsBytes(), [1, 2, 3]);
    expect((await repository.scan()).canCleanCache, isTrue);
    if (Platform.isLinux || Platform.isWindows) {
      final platformDefault = StorageRepositoryImpl(
        db,
        documentsDirectory: () async => documents,
        supportDirectory: () async => support,
        temporaryDirectory: () async => throw StateError('shared directory'),
      );
      expect((await platformDefault.scan()).canCleanCache, isFalse);
      await platformDefault.clean(StorageCleanup.cache);
    }
  });

  test('scan sums categories and ignores links', () async {
    await write('aetherlink.sqlite', 10);
    await write('aetherlink.sqlite-wal', 5);
    await write('aetherlink.sqlite-shm', 2);
    await write('agent_tool_outputs/nested/output.txt', 3);
    await write('browser_screenshots/screen.png', 4);
    await write('pptx_snapshots/slide.png', 5);
    await write('fonts/imported.ttf', 6);
    await write('google_fonts_cache/download.ttf', 7);
    await write('backups/backup.zip', 8);
    await write('avatars/avatar.png', 9);
    await write('notes/note.md', 10);
    await File('${temporary.path}/export.tmp').writeAsBytes([1, 2]);
    if (!Platform.isWindows) {
      await Link('${documents.path}/notes/outside').create(temporary.path);
    }
    final report = await repository.scan();
    expect(report.categories[StorageCategory.chat]!.bytes, 17);
    expect(report.categories[StorageCategory.chat]!.fileCount, 3);
    expect(report.categories[StorageCategory.tools]!.bytes, 12);
    expect(report.categories[StorageCategory.fonts]!.bytes, 6);
    expect(report.categories[StorageCategory.cache]!.bytes, 9);
    expect(report.categories[StorageCategory.notes]!.bytes, 10);
    expect(report.totalBytes, 71);
    expect(report.totalFiles, 12);
  });

  test('scan uses the currently configured notes directory', () async {
    await write('notes/default.md', 100);
    var selected = await Directory('${root.path}/custom_notes').create();
    await File('${selected.path}/custom.md').writeAsBytes([1, 2, 3]);
    final configured = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      notesDirectory: () async => selected,
      canCleanCache: false,
    );
    final usage = (await configured.scan()).categories[StorageCategory.notes]!;
    expect(usage.bytes, 3);
    expect(usage.fileCount, 1);
    selected = Directory('${root.path}/missing_notes');
    final missing = (await configured.scan()).categories[StorageCategory.notes]!;
    expect(missing.bytes, 0);
    expect(missing.fileCount, 0);
  });

  test('notes directory resolution errors are not hidden by defaults', () async {
    final configured = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      notesDirectory: () async => throw FileSystemException('notes unavailable'),
      canCleanCache: false,
    );
    await expectLater(configured.scan(), throwsA(isA<FileSystemException>()));
  });

  test('cleanup preserves imports and linked targets', () async {
    await write('fonts/imported.ttf', 6);
    await write('google_fonts_cache/download.ttf', 7);
    await write('notes/note.md', 8);
    await write('agent_tool_outputs/nested/output.txt', 3);
    await write('browser_screenshots/screen.png', 4);
    await write('pptx_snapshots/slide.png', 5);
    await File('${temporary.path}/export.tmp').writeAsBytes([1]);
    if (!Platform.isWindows) {
      await Link(
        '${temporary.path}/notes_link',
      ).create('${documents.path}/notes');
    }
    await repository.clean(StorageCleanup.fontCache);
    await expectLater(repository.clean(StorageCleanup.tools), throwsStateError);
    await expectLater(repository.cleanItem('agent_tool_outputs'), throwsArgumentError);
    await repository.clean(StorageCleanup.cache);
    expect(await File('${documents.path}/fonts/imported.ttf').exists(), isTrue);
    expect(await File('${documents.path}/notes/note.md').exists(), isTrue);
    expect(
      await Directory('${documents.path}/google_fonts_cache').exists(),
      isTrue,
    );
    expect(await temporary.exists(), isTrue);
    expect(await temporary.list().toList(), isEmpty);
    final report = await repository.scan();
    expect(report.categories[StorageCategory.tools]!.bytes, 12);
    expect(report.categories[StorageCategory.fonts]!.bytes, 6);
    expect(report.categories[StorageCategory.cache]!.bytes, 0);
  });

  test('details include only existing database files and support subitems', () async {
    await write('aetherlink.sqlite', 10);
    await write('aetherlink.sqlite-wal', 2);
    await writeSupport('pdfium/library.so', 3);
    await writeSupport('buddy_skins/pet.webp', 4);
    await writeSupport('file_history/known/index.json', 5);
    await writeSupport('file_history/unknown/objects/hash', 6);
    await writeSupport('terminal/rootfs/bin/sh', 7);
    await writeSupport('terminal/tmp/session', 8);
    final report = await repository.scan();
    expect(report.itemsFor(StorageCategory.chat).map((item) => item.name),
      ['aetherlink.sqlite', 'aetherlink.sqlite-wal']);
    expect(report.itemsFor(StorageCategory.workspaceHistory).map((item) => item.name),
      ['示例工作区', 'unknown']);
    expect(report.categories[StorageCategory.other]!.bytes, 7);
    expect(report.categories[StorageCategory.workspaceHistory]!.bytes, 11);
    expect(report.categories[StorageCategory.terminal]!.bytes, 15);
    expect(report.totalBytes, 45);
    expect(report.items.every((item) => FileSystemEntity.typeSync(
      item.path, followLinks: false) != FileSystemEntityType.notFound), isTrue);
    expect(report.itemsFor(StorageCategory.other).every((item) => !item.canClean), isTrue);
  });

  test('cache details do not double count and support independent cleanup', () async {
    await write('google_fonts_cache/font.ttf', 7);
    await File('${temporary.path}/export.tmp').writeAsBytes([1, 2]);
    final image = File('${temporary.path}/libCachedImageData/image');
    await image.parent.create();
    await image.writeAsBytes(List.filled(11, 1));
    final report = await repository.scan();
    final items = {for (final item in report.itemsFor(StorageCategory.cache)) item.id: item};
    expect(items['temporary']!.usage.bytes, 2);
    expect(items['fontCache']!.usage.bytes, 7);
    expect(items['imageCache']!.usage.bytes, 11);
    expect(report.totalBytes, 20);
    await repository.cleanItem('temporary');
    expect(await image.exists(), isTrue);
    expect(await File('${documents.path}/google_fonts_cache/font.ttf').exists(), isTrue);
    expect(imageCacheClears, 0);
    await repository.cleanItem('fontCache');
    expect(await image.exists(), isTrue);
    await repository.cleanItem('imageCache');
    expect(await image.exists(), isFalse);
    expect(imageCacheClears, 1);
    expect((await repository.scan()).totalBytes, 0);
  });

  test('all-cache cleanup clears every cache but keeps imported fonts', () async {
    await write('fonts/import.ttf', 3);
    await write('google_fonts_cache/font.ttf', 7);
    final image = File('${temporary.path}/libCachedImageData/image');
    await image.parent.create();
    await image.writeAsBytes([1]);
    await File('${temporary.path}/export.tmp').writeAsBytes([2]);
    await repository.clean(StorageCleanup.cache);
    expect((await repository.scan()).categories[StorageCategory.cache]!.bytes, 0);
    expect(await File('${documents.path}/fonts/import.ttf').exists(), isTrue);
    expect(imageCacheClears, 1);
  });

  test('desktop cache cleanup still clears fonts without resolving shared temp', () async {
    await write('google_fonts_cache/font.ttf', 7);
    final shared = StorageRepositoryImpl(db,
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      temporaryDirectory: () async => throw StateError('shared temp'),
      canCleanCache: false,
    );
    expect((await shared.scan()).itemsFor(StorageCategory.cache).map((item) => item.id),
      ['fontCache']);
    await shared.clean(StorageCleanup.cache);
    expect((await shared.scan()).categories[StorageCategory.cache]!.bytes, 0);
    await expectLater(shared.cleanItem('temporary'), throwsArgumentError);
    await expectLater(shared.cleanItem('imageCache'), throwsArgumentError);
  });

  test('history supports individual and all-workspace cleanup', () async {
    await writeSupport('file_history/known/index.json', 5);
    await writeSupport('file_history/known/objects/hash', 6);
    await writeSupport('file_history/unknown/index.json', 7);
    await writeSupport('terminal/rootfs/keep', 8);
    await repository.cleanItem('history:known');
    expect(await Directory('${support.path}/file_history/known').exists(), isTrue);
    expect((await repository.scan()).categories[StorageCategory.workspaceHistory]!.bytes, 7);
    await repository.clean(StorageCleanup.workspaceHistory);
    expect((await repository.scan()).itemsFor(StorageCategory.workspaceHistory), isEmpty);
    expect(await File('${support.path}/terminal/rootfs/keep').exists(), isTrue);
  });

  test('terminal tmp cleanup leaves rootfs untouched', () async {
    await writeSupport('terminal/rootfs/bin/sh', 7);
    await writeSupport('terminal/tmp/nested/session', 8);
    await repository.cleanItem('terminalTmp');
    expect(await File('${support.path}/terminal/rootfs/bin/sh').exists(), isTrue);
    expect((await repository.scan()).categories[StorageCategory.terminal]!.bytes, 7);
  });

  test('unknown, read-only and traversal item identifiers are rejected', () async {
    await writeSupport('pdfium/library.so', 3);
    await writeSupport('buddy_skins/pet.webp', 4);
    await writeSupport('terminal/rootfs/keep', 5);
    await writeSupport('file_history/known/index.json', 6);
    for (final id in ['pdfium', 'buddySkins', 'terminalRootfs', 'fonts', 'notes',
      'database', '../terminal', 'history:../terminal', 'history:known/../../terminal']) {
      await expectLater(repository.cleanItem(id), throwsArgumentError);
    }
    expect((await repository.scan()).totalBytes, 18);
  });

  test('intermediate and item-root symlinks cannot escape support roots', () async {
    if (Platform.isWindows) return;
    final outside = await Directory('${root.path}/outside').create();
    await File('${outside.path}/keep').writeAsBytes([1, 2, 3]);
    await Link('${support.path}/terminal').create(outside.path);
    final history = await Directory('${support.path}/file_history').create();
    await Link('${history.path}/linked').create(outside.path);
    final report = await repository.scan();
    expect(report.categories[StorageCategory.terminal]!.bytes, 0);
    expect(report.itemsFor(StorageCategory.workspaceHistory), isEmpty);
    await expectLater(repository.cleanItem('terminalTmp'), throwsA(isA<FileSystemException>()));
    await expectLater(repository.cleanItem('history:linked'), throwsArgumentError);
    await repository.clean(StorageCleanup.workspaceHistory);
    expect(await File('${outside.path}/keep').readAsBytes(), [1, 2, 3]);
  });

  test('workspace names fall back to ids when metadata cannot be read', () async {
    await writeSupport('file_history/known/index.json', 5);
    final fallback = StorageRepositoryImpl(db,
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      workspaceNames: () async => throw StateError('metadata unavailable'),
      canCleanCache: false,
    );
    expect((await fallback.scan()).itemsFor(StorageCategory.workspaceHistory).single.name,
      'known');
    await fallback.cleanItem('history:known');
    expect((await fallback.scan()).totalBytes, 0);
  });

  test('image cache metadata failures are not reported as success', () async {
    final failing = StorageRepositoryImpl(db,
      documentsDirectory: () async => documents,
      supportDirectory: () async => support,
      temporaryDirectory: () async => temporary,
      clearImageCache: () async => throw StateError('cache manager unavailable'),
      canCleanCache: true,
    );
    await expectLater(failing.cleanItem('imageCache'), throwsStateError);
  });

  test('SQL aggregates message counts, media and UTF-8 sizes', () async {
    await db.customStatement(
      'INSERT INTO assistant_rows (id, data) VALUES (?, ?)',
      ['assistant', jsonEncode({'name': '画图助手'})],
    );
    await topic(
      'large',
      jsonEncode({'name': '绘画', 'assistantId': 'assistant'}),
    );
    await topic('empty', '{}');
    await topic('small', 'invalid-json');
    await message('m1', 'large');
    await message('m2', 'large');
    await message('root', 'large', role: 'root');
    await message('m3', 'small');
    final image = jsonEncode({'type': 'image', 'data': '中文'});
    final video = jsonEncode({'type': 'video', 'data': 'AAAA'});
    await block('b1', 'm1', image);
    await block('b2', 'm1', video);
    await block('b3', 'm3', 'bad');
    await block('orphan', 'missing', image);
    final rows = await repository.topicUsage();
    expect(rows.map((row) => row.id), ['large', 'small', 'empty']);
    final first = rows.first;
    expect(first.title, '绘画');
    expect(first.assistantName, '画图助手');
    expect(first.bytes, utf8.encode(image).length + utf8.encode(video).length);
    expect(first.messageCount, 2);
    expect(first.imageCount, 1);
    expect(first.videoCount, 1);
    expect(rows[1].imageCount, 0);
    expect(rows[1].title, '未命名话题');
    expect(rows.last.messageCount, 0);
    expect(rows.last.assistantName, '未关联助手');
  });

  test('vacuum leaves topics readable', () async {
    await topic('keep', jsonEncode({'name': '保留'}));
    await repository.vacuum();
    expect((await repository.topicUsage()).single.id, 'keep');
  });
}
