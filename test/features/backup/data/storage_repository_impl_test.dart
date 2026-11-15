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
  late StorageRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('aetherlink_storage_test_');
    documents = await Directory('${root.path}/documents').create();
    temporary = await Directory('${root.path}/temporary').create();
    repository = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => documents,
      temporaryDirectory: () async => temporary,
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
    expect(await repository.topicUsage(), isEmpty);
    await repository.clean(StorageCleanup.fontCache);
  });

  test('directory resolution failures reach the caller', () async {
    final unavailable = StorageRepositoryImpl(
      db,
      documentsDirectory: () async => throw FileSystemException('unavailable'),
      temporaryDirectory: () async => temporary,
    );
    await expectLater(unavailable.scan(), throwsA(isA<FileSystemException>()));
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
    expect(report.categories[StorageCategory.fonts]!.bytes, 13);
    expect(report.categories[StorageCategory.notes]!.bytes, 10);
    expect(report.totalBytes, 71);
    expect(report.totalFiles, 12);
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
    await repository.clean(StorageCleanup.tools);
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
    expect(report.categories[StorageCategory.tools]!.bytes, 0);
    expect(report.categories[StorageCategory.fonts]!.bytes, 6);
    expect(report.categories[StorageCategory.cache]!.bytes, 0);
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
