import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

void main() {
  group('chunkText', () {
    test('empty text yields no chunks', () {
      expect(chunkText('', size: 10, overlap: 2), isEmpty);
    });

    test('preserves the substring invariant on every chunk', () {
      const text =
          'The quick brown fox jumps over the lazy dog. Pack my box with '
          'five dozen liquor jugs. How razorback jumping frogs can level six '
          'piqued gymnasts!';
      final chunks = chunkText(text, size: 40, overlap: 10);
      expect(chunks, isNotEmpty);
      for (final c in chunks) {
        expect(text.substring(c.charStart, c.charEnd), c.text);
      }
      // Full coverage: first starts at 0, last ends at text end.
      expect(chunks.first.charStart, 0);
      expect(chunks.last.charEnd, text.length);
    });

    test('overlap >= size is clamped so the loop always advances', () {
      final chunks = chunkText('abcdefgh', size: 4, overlap: 99);
      expect(chunks, isNotEmpty);
      expect(chunks.last.charEnd, 8);
      // unitIndex is contiguous.
      for (var i = 0; i < chunks.length; i++) {
        expect(chunks[i].unitIndex, i);
      }
    });
  });

  group('KnowledgeService', () {
    late AppDatabase db;
    late KnowledgeService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = KnowledgeService(db.knowledgeDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('createBase persists defaults and lists newest first', () async {
      final a = await service.createBase(name: '  Base A  ');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await service.createBase(
        name: 'Base B',
        scope: const KnowledgeScope(chatEnabled: true),
      );

      final bases = await service.listBases();
      expect(bases.map((e) => e.id), [b.id, a.id]);

      final reloadedA = bases.firstWhere((e) => e.id == a.id);
      expect(reloadedA.name, 'Base A'); // trimmed
      expect(reloadedA.searchMode, KnowledgeSearchMode.keyword);
      expect(reloadedA.status, KnowledgeBaseStatus.idle);
      expect(reloadedA.chunkSize, KnowledgeBase.kDefaultChunkSize);
      expect(reloadedA.scope.chatEnabled, isFalse);

      final reloadedB = bases.firstWhere((e) => e.id == b.id);
      expect(reloadedB.scope.chatEnabled, isTrue);
    });

    test('addNote ingests content and flips base status to completed',
        () async {
      final base = await service.createBase(name: 'KB');
      final item = await service.addNote(
        baseId: base.id,
        title: 'Note 1',
        text: 'Flutter uses the Dart language for building apps.',
      );

      expect(item.type, KnowledgeItemType.note);
      expect(item.status, KnowledgeItemStatus.completed);

      final items = await service.listItems(base.id);
      expect(items, hasLength(1));
      expect(items.single.title, 'Note 1');
      expect(await service.itemCount(base.id), 1);

      final reloaded =
          (await service.listBases()).firstWhere((e) => e.id == base.id);
      expect(reloaded.status, KnowledgeBaseStatus.completed);
    });

    test('empty-title note falls back to a placeholder title', () async {
      final base = await service.createBase(name: 'KB');
      final item =
          await service.addNote(baseId: base.id, title: '   ', text: 'hello');
      expect(item.title, '未命名笔记');
      expect(item.source, '未命名笔记');
    });

    test('addNote on a missing base throws', () async {
      expect(
        () => service.addNote(baseId: 'nope', title: 't', text: 'x'),
        throwsStateError,
      );
    });

    test('keyword search returns hits ranked by match, scoped to the base',
        () async {
      final base = await service.createBase(name: 'KB');
      await service.addNote(
        baseId: base.id,
        title: 'Dart',
        text: 'Dart is a client-optimized language. Dart compiles to native.',
      );
      await service.addNote(
        baseId: base.id,
        title: 'Python',
        text: 'Python is a general purpose scripting language.',
      );

      final hits = await service.search(baseId: base.id, query: 'dart');
      expect(hits, isNotEmpty);
      // Every hit actually contains the query token (case-insensitive).
      for (final h in hits) {
        expect(h.content.toLowerCase(), contains('dart'));
      }
      expect(hits.first.index, 1);
      expect(hits.first.knowledgeBaseId, base.id);

      // A term present in both notes matches both.
      final langHits = await service.search(baseId: base.id, query: 'language');
      expect(langHits.length, greaterThanOrEqualTo(2));
    });

    test('multi-token query ranks higher coverage first', () async {
      final base = await service.createBase(name: 'KB');
      await service.addNote(
        baseId: base.id,
        title: 'both',
        text: 'alpha beta appear together here.',
      );
      await service.addNote(
        baseId: base.id,
        title: 'one',
        text: 'only alpha appears here.',
      );

      final hits = await service.search(baseId: base.id, query: 'alpha beta');
      expect(hits, isNotEmpty);
      // The chunk covering both tokens (similarity 1.0) ranks first.
      expect(hits.first.content, contains('beta'));
      expect(hits.first.similarity, 1.0);
    });

    test('search honours topK', () async {
      final base = await service.createBase(name: 'KB');
      for (var i = 0; i < 6; i++) {
        await service.addNote(
          baseId: base.id,
          title: 'n$i',
          text: 'repeated keyword marker number $i.',
        );
      }
      final hits =
          await service.search(baseId: base.id, query: 'marker', topK: 3);
      expect(hits, hasLength(3));
    });

    test('search on unknown base or empty query returns empty', () async {
      final base = await service.createBase(name: 'KB');
      await service.addNote(baseId: base.id, title: 't', text: 'content');
      expect(await service.search(baseId: 'missing', query: 'x'), isEmpty);
      expect(await service.search(baseId: base.id, query: '   '), isEmpty);
    });

    test('deleteBase removes the base and all derived rows', () async {
      final base = await service.createBase(name: 'KB');
      await service.addNote(baseId: base.id, title: 't', text: 'to be deleted');

      await service.deleteBase(base.id);

      expect(await service.listBases(), isEmpty);
      expect(await service.listItems(base.id), isEmpty);
      expect(await service.search(baseId: base.id, query: 'deleted'), isEmpty);
    });
  });
}
