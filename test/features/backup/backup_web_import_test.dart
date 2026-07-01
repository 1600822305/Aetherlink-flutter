import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
import 'package:aetherlink_flutter/features/backup/domain/restore_plan.dart';

/// Builds a minimal but structurally-complete AetherLink Web backup with known
/// per-category quantities so the scan counts can be asserted exactly:
/// 1 topic, 2 messages, 3 blocks (2 + 1), 1 assistant, 1 provider, 1 importable
/// memory (a second one is soft-deleted), and 1 unsupported category (知识库).
Map<String, dynamic> _sampleWebBackup() {
  return {
    'appInfo': {'name': 'AetherLink', 'backupVersion': 7},
    'timestamp': 1700000000000,
    'topics': [
      {
        'id': 't1',
        'title': '话题一',
        'assistantId': 'a1',
        'messages': [
          {
            'id': 'm1',
            'role': 'user',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'blocks': [
              {'id': 'b1', 'type': 'main_text', 'content': '你好'},
              {'id': 'b2', 'type': 'main_text', 'content': '世界'},
            ],
          },
          {
            'id': 'm2',
            'role': 'assistant',
            'createdAt': '2024-01-01T00:00:01.000Z',
            'blocks': [
              {'id': 'b3', 'type': 'main_text', 'content': '回复'},
            ],
          },
        ],
      },
    ],
    'assistants': [
      {'id': 'a1', 'name': '助手一'},
    ],
    'settings': {
      'providers': [
        {
          'id': 'p1',
          'name': 'Provider 1',
          'models': [
            {'id': 'model-1', 'name': 'Model 1'},
          ],
        },
      ],
    },
    'memories': [
      {'id': 'mem1', 'content': '记忆一'},
      {'id': 'mem2', 'content': '已删除', 'isDeleted': true},
    ],
    // Category Flutter has no table for — must surface as unsupported.
    'knowledgeBases': [
      {'id': 'kb1', 'name': '知识库一'},
    ],
  };
}

Future<File> _writeJsonFile(Directory dir, Object json) async {
  final file = File('${dir.path}/backup.json');
  await file.writeAsString(jsonEncode(json));
  return file;
}

void main() {
  group('BackupService web-JSON scan', () {
    late AppDatabase db;
    late BackupService service;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      service = BackupService(db: db);
      tempDir = await Directory.systemTemp.createTemp('aether_backup_test');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reports exact per-category counts + unsupported for a web backup',
        () async {
      final file = await _writeJsonFile(tempDir, _sampleWebBackup());

      final scan = await service.scanBackup(file);

      expect(scan.isWebFormat, isTrue);
      expect(scan.countOf(BackupCategory.topics), 1);
      expect(scan.countOf(BackupCategory.messages), 2);
      expect(scan.countOf(BackupCategory.messageBlocks), 3);
      expect(scan.countOf(BackupCategory.assistants), 1);
      expect(scan.countOf(BackupCategory.providers), 1);
      // One memory is soft-deleted, so only one is importable.
      expect(scan.countOf(BackupCategory.memories), 1);

      // 知识库 has no Flutter table -> surfaced as unsupported, not dropped
      // silently.
      expect(
        scan.unsupported.any((u) => u.name == '知识库' && u.count == 1),
        isTrue,
      );

      // Synthesized manifest mirrors the same tallies.
      final stats = scan.manifest!.stats;
      expect(stats.topics, 1);
      expect(stats.messages, 2);
      expect(stats.messageBlocks, 3);
      expect(stats.assistants, 1);
    });

    test('a valid-JSON but non-backup document yields nothing importable',
        () async {
      final file = await _writeJsonFile(tempDir, {'foo': 1});

      final scan = await service.scanBackup(file);

      // Scan never throws on shape; it simply finds no importable categories.
      expect(scan.presentCategories, isEmpty);
    });

    test('malformed JSON throws a friendly FormatException', () async {
      final file = File('${tempDir.path}/backup.json');
      await file.writeAsString('{ not valid json ');

      expect(
        () => service.scanBackup(file),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BackupService web-JSON restore validation', () {
    late AppDatabase db;
    late BackupService service;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      service = BackupService(db: db);
      tempDir = await Directory.systemTemp.createTemp('aether_backup_test');
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects a non-backup document before any auto-backup runs', () async {
      final file = await _writeJsonFile(tempDir, {'foo': 1});

      // Validation happens inside the parse isolate, ahead of the pre-restore
      // auto-backup, so this fails fast without touching platform channels.
      await expectLater(
        service.restoreFromFile(file),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('不是有效'),
          ),
        ),
      );
    });

    test('rejects malformed JSON', () async {
      final file = File('${tempDir.path}/backup.json');
      await file.writeAsString('{ broken ');

      await expectLater(
        service.restoreFromFile(file),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
