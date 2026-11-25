import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/backup/domain/restore_plan.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

import 'backup_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BackupService service;
  late WorldBookRepositoryImpl books;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db: db);
    books = WorldBookRepositoryImpl(db.worldBookDao);
    tempDir = await Directory.systemTemp.createTemp('aether_wb_backup');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  const lore = WorldBook(
    id: 'wb-1',
    name: '山海',
    description: 'desc',
    enabled: false,
    groupName: '设定集',
    entries: [
      WorldBookEntry(
        id: 'e1',
        name: '龙',
        content: 'LORE',
        keywords: ['dragon', r'/dra\w+/i'],
        secondaryKeywords: ['wing'],
        secondaryLogic: WorldBookSecondaryLogic.notAny,
        position: WorldBookInjectionPosition.atDepth,
        depth: 2,
        role: WorldBookInjectionRole.assistant,
        sticky: 3,
        cooldown: 2,
        delay: 1,
        order: 5,
        group: 'g1,g2',
        extra: {'customFromNewerST': 42},
      ),
    ],
  );

  Map<String, dynamic> record(WorldBook book, int sortOrder) => {
    ...book.toJson(),
    'sortOrder': sortOrder,
    'groupName': book.groupName,
    'updatedAt': 1700000000000,
  };

  test('createBackup exports world_books.json with a manifest count and '
      'the round trip restores it losslessly (order + group kept)', () async {
    await books.save(const WorldBook(id: 'wb-0', name: 'first'));
    await books.save(lore);

    final file = await service.createBackup();
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final manifest = BackupManifest.fromJsonString(
      utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
    );
    expect(manifest.stats.worldBooks, 2);
    final exported =
        jsonDecode(
              utf8.decode(
                archive.findFile('world_books.json')!.content as List<int>,
              ),
            )
            as List<dynamic>;
    expect(exported, hasLength(2));

    final scan = await service.scanBackup(file);
    expect(scan.countOf(BackupCategory.worldBooks), 2);

    // Wipe and restore from the real backup (checksum includes the new file).
    await db.delete(db.worldBookRows).go();
    final result = await service.restoreFromFile(file);
    expect(result.failed, 0);
    expect(result.byCategory[BackupCategory.worldBooks]!.reconciled, isTrue);
    expect(result.byCategory[BackupCategory.worldBooks]!.succeeded, 2);

    final restored = await books.getAll();
    expect(restored.map((b) => b.id), ['wb-0', 'wb-1']);
    expect(restored.last, lore);
  });

  test('an old backup without world_books.json restores and keeps existing '
      'world books (overwrite mode)', () async {
    await books.save(lore);
    final file = await writeZipBackup(tempDir, omit: {'world_books.json'});
    final scan = await service.scanBackup(file);
    expect(scan.countOf(BackupCategory.worldBooks), 0);
    final result = await service.restoreFromFile(file);
    expect(result.failed, 0);
    expect((await books.getAll()).single.id, 'wb-1');
  });

  test('overwrite replaces world books; merge skips existing ids', () async {
    await books.save(const WorldBook(id: 'old', name: 'old'));
    final file = await writeZipBackup(
      tempDir,
      data: {
        'world_books.json': [record(lore, 0)],
      },
    );

    final merged = await service.restoreFromFile(file, mode: RestoreMode.merge);
    expect(merged.failed, 0);
    expect((await books.getAll()).map((b) => b.id).toSet(), {'old', 'wb-1'});
    final again = await service.restoreFromFile(file, mode: RestoreMode.merge);
    expect(again.byCategory[BackupCategory.worldBooks]!.skipped, 1);

    await service.restoreFromFile(file);
    expect((await books.getAll()).map((b) => b.id), ['wb-1']);
  });

  test('a selective restore without 世界书 leaves world books untouched', () async {
    await books.save(const WorldBook(id: 'keep', name: 'keep'));
    final file = await writeZipBackup(
      tempDir,
      data: {
        'world_books.json': [record(lore, 0)],
      },
    );
    await service.restoreFromFile(
      file,
      selection: const RestoreSelection(categories: {BackupCategory.assistants}),
    );
    expect((await books.getAll()).map((b) => b.id), ['keep']);
  });

  test('worldBooks is an independent category with the 世界书 label', () {
    expect(BackupCategory.worldBooks.label, '世界书');
    expect(BackupCategory.worldBooks.directDependencies, isEmpty);
    expect(BackupCategory.assistants.requiredAncestors, isEmpty);
    expect(BackupCategory.worldBooks.dependentDescendants, isEmpty);
  });

  test('legacy manifests without the worldBooks stat read as 0', () {
    expect(BackupStats.fromJson(const {'topics': 3}).worldBooks, 0);
    expect(const BackupStats(worldBooks: 4).toJson()['worldBooks'], 4);
  });
}
