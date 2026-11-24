import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/restore_plan.dart';

import 'backup_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService data safety', () {
    late AppDatabase db;
    late BackupService service;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      service = BackupService(db: db);
      tempDir = await Directory.systemTemp.createTemp('aether_backup_safety');
      PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('overwrite restore keeps tables the backup carries no data for',
        () async {
      await db.appSettingDao.setValue('local_only', 'keep');

      final file = await writeZipBackup(tempDir);
      await service.restoreFromFile(file);

      expect(await db.appSettingDao.getValue('local_only'), 'keep');
    });

    test('overwrite restore still replaces categories the backup carries',
        () async {
      await db.appSettingDao.setValue('old_key', 'old');

      final file = await writeZipBackup(
        tempDir,
        data: {
          'settings.json': [
            {'key': 'new_key', 'value': 'new'},
          ],
        },
      );
      await service.restoreFromFile(file);

      expect(await db.appSettingDao.getValue('old_key'), isNull);
      expect(await db.appSettingDao.getValue('new_key'), 'new');
    });

    test('overwriting settings keeps keys excluded from export', () async {
      await db.appSettingDao.setValue('workspace_ssh_credentials', 'secret');
      await db.appSettingDao.setValue('old_key', 'old');

      final file = await writeZipBackup(
        tempDir,
        data: {
          'settings.json': [
            {'key': 'new_key', 'value': 'new'},
          ],
        },
      );
      await service.restoreFromFile(
        file,
        mode: RestoreMode.overwrite,
        selection: const RestoreSelection(
          categories: {BackupCategory.settings},
        ),
      );

      expect(
        await db.appSettingDao.getValue('workspace_ssh_credentials'),
        'secret',
      );
      expect(await db.appSettingDao.getValue('old_key'), isNull);
      expect(await db.appSettingDao.getValue('new_key'), 'new');
    });

    test('backup does not export cloud storage credentials', () async {
      await db.appSettingDao.setValue('webdav_config', '{"password":"p"}');
      await db.appSettingDao.setValue('s3_config', '{"secretAccessKey":"s"}');
      await db.appSettingDao.setValue('theme', 'dark');

      final file = await service.createBackup();
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final entry = archive.findFile('settings.json')!;
      final settings =
          jsonDecode(utf8.decode(entry.content as List<int>)) as List<dynamic>;
      final keys = settings.map((e) => (e as Map)['key']).toSet();

      expect(keys, contains('theme'));
      expect(keys, isNot(contains('webdav_config')));
      expect(keys, isNot(contains('s3_config')));
    });
  });
}
