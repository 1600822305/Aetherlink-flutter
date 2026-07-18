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
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

/// 手工拼一个 Flutter ZIP 备份（跳过 createBackup 对 path_provider 的依赖），
/// 数据文件齐全、checksum 与打包逻辑一致，可选携带 knowledge.json。
Future<File> _writeZipBackup(
  Directory dir, {
  List<Map<String, dynamic>> knowledge = const [],
  bool includeKnowledgeEntry = true,
}) async {
  final categories = <String, List<Map<String, dynamic>>>{
    'topics.json': const [],
    'messages.json': const [],
    'message_blocks.json': const [],
    'assistants.json': const [],
    'providers.json': const [],
    'groups.json': const [],
    'settings.json': const [],
    if (includeKnowledgeEntry) 'knowledge.json': knowledge,
  };
  final manifest = {
    'version': 1,
    'appVersion': '0.0.0',
    'platform': 'test',
    'schemaVersion': 12,
    'createdAt': DateTime.now().toIso8601String(),
    'deviceInfo': '',
    // checksum 为空则跳过校验（与真实旧备份兼容路径一致）。
    'checksum': '',
    'stats': {'knowledge': knowledge.length},
    'options': {
      'includeMessages': true,
      'includeProviders': true,
      'includeSettings': true,
    },
  };

  final archive = Archive();
  void add(String name, Object json) {
    final bytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('manifest.json', manifest);
  categories.forEach(add);

  final file = File('${dir.path}/backup.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive));
  return file;
}

/// 把 path_provider 的临时目录指向测试专用目录，让 _extractZip 在纯 Dart 测试
/// 里也能解包（无真实平台通道）。
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService knowledge backup/restore (P3d §11.2)', () {
    late AppDatabase db;
    late BackupService service;
    late KnowledgeService knowledge;
    late Directory tempDir;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      service = BackupService(db: db);
      knowledge = KnowledgeService(db.knowledgeDao);
      tempDir = await Directory.systemTemp.createTemp('aether_kb_backup');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Map<String, dynamic> sampleKnowledgeRecord() => {
          'id': 'kb-1',
          'name': '恢复库',
          'embeddingModelKey': null,
          'dimensions': null,
          'chunkSize': 20,
          'chunkOverlap': 4,
          'searchMode': 'keyword',
          'threshold': null,
          'topK': 5,
          'scope': const KnowledgeScope(chatEnabled: true).toJson(),
          'status': 'completed',
          'createdAt': 1700000000000,
          'items': [
            {
              'id': 'item-1',
              'type': 'note',
              'source': 'note',
              'conceptId': 'item-1',
              'title': '笔记一',
              'status': 'completed',
              'error': null,
              'sourceFingerprint': null,
              'createdAt': 1700000000000,
              'content': 'dart is a client optimized language for fast apps',
              'contentHash': 'hash-1',
            },
          ],
        };

    test('scan surfaces knowledge as a supported category with its count',
        () async {
      final file = await _writeZipBackup(
        tempDir,
        knowledge: [sampleKnowledgeRecord()],
      );
      final scan = await service.scanBackup(file);
      expect(scan.countOf(BackupCategory.knowledge), 1);
    });

    test('restore rebuilds authority rows + derived chunks; keyword search '
        'works immediately', () async {
      final file = await _writeZipBackup(
        tempDir,
        knowledge: [sampleKnowledgeRecord()],
      );

      final result = await service.restoreFromFile(file);
      expect(result.failed, 0);

      final bases = await knowledge.listBases();
      expect(bases, hasLength(1));
      expect(bases.single.id, 'kb-1');
      expect(bases.single.scope.chatEnabled, isTrue);

      final items = await knowledge.listItems('kb-1');
      expect(items, hasLength(1));
      expect(items.single.title, '笔记一');

      // 派生切块已按库的 chunkSize/overlap 重建，关键词检索立即可用。
      final chunks = await db.select(db.kbChunkRows).get();
      expect(chunks, isNotEmpty);
      final hits = await knowledge.search(baseId: 'kb-1', query: 'dart');
      expect(hits, isNotEmpty);
    });

    test('restore keeps trashed items in the trash without derived chunks',
        () async {
      final record = sampleKnowledgeRecord();
      (record['items'] as List).add({
        'id': 'item-trashed',
        'type': 'note',
        'source': 'note',
        'conceptId': 'item-trashed',
        'title': '回收站笔记',
        'status': 'completed',
        'error': null,
        'sourceFingerprint': null,
        'createdAt': 1700000000000,
        'deletedAt': 1700000001000,
        'content': 'trashed note content',
        'contentHash': 'hash-2',
      });
      final file = await _writeZipBackup(tempDir, knowledge: [record]);

      final result = await service.restoreFromFile(file);
      expect(result.failed, 0);

      final live = await knowledge.listItems('kb-1');
      expect(live.map((i) => i.id), ['item-1']);
      final trash = await knowledge.listTrash('kb-1');
      expect(trash.map((i) => i.id), ['item-trashed']);

      final trashedChunks = await (db.select(db.kbChunkRows)
            ..where((t) => t.itemId.equals('item-trashed')))
          .get();
      expect(trashedChunks, isEmpty);

      // 恢复后仍可从回收站还原（正文保留，切块重建）。
      await knowledge.restoreItem('item-trashed');
      final restoredChunks = await (db.select(db.kbChunkRows)
            ..where((t) => t.itemId.equals('item-trashed')))
          .get();
      expect(restoredChunks, isNotEmpty);
    });

    test('restore round-trips base-level group / rerank / file-processor '
        'config', () async {
      final record = sampleKnowledgeRecord()
        ..['groupName'] = '工作'
        ..['rerankModelKey'] = 'provider|rerank-model'
        ..['fileProcessorId'] = 'mineru';
      final file = await _writeZipBackup(tempDir, knowledge: [record]);

      await service.restoreFromFile(file);

      final base = (await knowledge.listBases()).single;
      expect(base.groupName, '工作');
      expect(base.rerankModelKey, 'provider|rerank-model');
      expect(base.fileProcessorId, 'mineru');
    });

    test('overwrite restore of an old backup without knowledge.json keeps '
        'existing knowledge bases', () async {
      final base = await knowledge.createBase(name: '现存库');
      await knowledge.addNote(baseId: base.id, title: 't', text: 'keep me');

      final file = await _writeZipBackup(
        tempDir,
        includeKnowledgeEntry: false,
      );
      await service.restoreFromFile(file);

      final bases = await knowledge.listBases();
      expect(bases.map((b) => b.name), contains('现存库'));
      expect(await knowledge.listItems(base.id), isNotEmpty);
    });

    test('overwrite restore replaces existing knowledge with backup contents',
        () async {
      final old = await knowledge.createBase(name: '旧库');
      await knowledge.addNote(baseId: old.id, title: 'x', text: 'old text');

      final file = await _writeZipBackup(
        tempDir,
        knowledge: [sampleKnowledgeRecord()],
      );
      await service.restoreFromFile(file);

      final bases = await knowledge.listBases();
      expect(bases.map((b) => b.id), ['kb-1']);
      expect(bases.map((b) => b.name), isNot(contains('旧库')));
    });

    test('merge restore keeps existing bases and skips duplicate ids',
        () async {
      final existing = await knowledge.createBase(name: '现存库');

      final file = await _writeZipBackup(
        tempDir,
        knowledge: [sampleKnowledgeRecord()],
      );
      final result = await service.restoreFromFile(
        file,
        mode: RestoreMode.merge,
      );
      expect(result.failed, 0);

      final bases = await knowledge.listBases();
      expect(bases.map((b) => b.id).toSet(), {existing.id, 'kb-1'});

      // 再导一次同一份备份：merge 模式按 id 跳过，不产生重复。
      final again = await service.restoreFromFile(
        file,
        mode: RestoreMode.merge,
      );
      expect(again.failed, 0);
      expect((await knowledge.listBases()).length, 2);
    });
  });
}
