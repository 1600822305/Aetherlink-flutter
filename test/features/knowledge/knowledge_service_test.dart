import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedder.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedding.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_ranking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_reranker.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_url_fetcher.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_workspace_source.dart';

/// Deterministic bag-of-words embedder: each text maps to a vector counting how
/// many times each [vocab] term occurs (case-insensitive substring). Records
/// every batch it embeds in [log] so tests can assert dedup / call counts.
class _FakeEmbedder implements KnowledgeEmbedder {
  _FakeEmbedder(this.vocab, this.log, {this.returnEmpty = false});

  final List<String> vocab;
  final List<List<String>> log;
  final bool returnEmpty;

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    log.add(List.of(texts));
    if (returnEmpty) return [for (final _ in texts) const <double>[]];
    return [
      for (final text in texts)
        [
          for (final term in vocab)
            term.allMatches(text.toLowerCase()).length.toDouble(),
        ],
    ];
  }
}

/// Deterministic reranker: delegates scoring to [score] so tests control the
/// new order (or throw to prove reranking stays best-effort).
class _FakeReranker implements KnowledgeReranker {
  _FakeReranker(this.score);

  final List<double>? Function(String query, List<String> documents) score;

  @override
  Future<List<double>?> rerank({
    required String query,
    required List<String> documents,
  }) async => score(query, documents);
}

/// In-memory workspace source. [files] maps an opaque path to a
/// `(name, text, mtime, size)` record — tests mutate/remove entries to simulate
/// file edits and deletions between ingestion and search. [statThrows] makes
/// [statFile] throw, to prove staleness checks stay best-effort.
class _FakeWorkspaceSource implements KnowledgeWorkspaceSource {
  _FakeWorkspaceSource(
    Map<String, (String, String, int, int)> files, {
    this.statThrows = false,
  }) : files = Map.of(files);

  final Map<String, (String, String, int, int)> files;
  final bool statThrows;

  @override
  Future<List<KnowledgeWorkspaceFile>> listTextFiles(
    String workspaceId,
  ) async => [
    for (final entry in files.entries)
      KnowledgeWorkspaceFile(
        path: entry.key,
        name: entry.value.$1,
        text: entry.value.$2,
        mtime: entry.value.$3,
        size: entry.value.$4,
      ),
  ];

  @override
  Future<KnowledgeWorkspaceStat?> statFile(
    String workspaceId,
    String path,
  ) async {
    if (statThrows) throw StateError('stat failed');
    final file = files[path];
    if (file == null) return null;
    return KnowledgeWorkspaceStat(mtime: file.$3, size: file.$4);
  }
}

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

    test('setBaseGroup / renameGroup / dissolveGroup manage group membership',
        () async {
      final a = await service.createBase(name: 'A');
      final b = await service.createBase(name: 'B');
      final c = await service.createBase(name: 'C');

      await service.setBaseGroup(a.id, '  工作  ');
      await service.setBaseGroup(b.id, '工作');
      expect((await service.getBase(a.id))!.groupName, '工作'); // trimmed
      expect((await service.getBase(b.id))!.groupName, '工作');
      expect((await service.getBase(c.id))!.groupName, isNull);

      await service.renameGroup('工作', '学习');
      expect((await service.getBase(a.id))!.groupName, '学习');
      expect((await service.getBase(b.id))!.groupName, '学习');

      await service.setBaseGroup(a.id, '   ');
      expect((await service.getBase(a.id))!.groupName, isNull); // blank clears

      await service.dissolveGroup('学习');
      expect((await service.getBase(b.id))!.groupName, isNull);
      expect(await service.listBases(), hasLength(3)); // bases survive

      await expectLater(
        service.renameGroup('学习', '  '),
        throwsStateError,
      );
      await expectLater(
        service.setBaseGroup('missing', 'G'),
        throwsStateError,
      );
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

    test('addFile ingests a txt/md file as a file-typed, searchable item',
        () async {
      final base = await service.createBase(name: 'KB');
      final item = await service.addFile(
        baseId: base.id,
        fileName: 'notes.md',
        text: 'Flutter widgets compose into a tree.',
        sourcePath: '/docs/notes.md',
      );

      expect(item.type, KnowledgeItemType.file);
      expect(item.title, 'notes.md');
      expect(item.source, '/docs/notes.md'); // keeps the original path
      expect(item.status, KnowledgeItemStatus.completed);

      final hits = await service.search(baseId: base.id, query: 'widgets');
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('widgets'));

      final reloaded =
          (await service.listBases()).firstWhere((e) => e.id == base.id);
      expect(reloaded.status, KnowledgeBaseStatus.completed);
    });

    test('addFile falls back to a placeholder title and rejects empty content',
        () async {
      final base = await service.createBase(name: 'KB');
      final item =
          await service.addFile(baseId: base.id, fileName: '   ', text: 'x');
      expect(item.title, '未命名文件');
      expect(item.source, '未命名文件'); // no path + blank name → placeholder

      expect(
        () => service.addFile(baseId: base.id, fileName: 'blank.txt', text: '  '),
        throwsStateError,
      );
    });

    test('addUrl fetches, converts and ingests a url-typed, searchable item',
        () async {
      final calls = <String>[];
      final urlService = KnowledgeService(
        db.knowledgeDao,
        urlFetcher: (url) async {
          calls.add(url);
          return const KnowledgeFetchedPage(
            markdown: '# Riverpod Guide\n\nProviders compose your app state.',
            title: 'Riverpod Guide',
          );
        },
      );
      final base = await urlService.createBase(name: 'KB');
      final item = await urlService.addUrl(
        baseId: base.id,
        url: '  https://example.com/riverpod  ',
      );

      expect(calls, ['https://example.com/riverpod']); // trimmed before fetch
      expect(item.type, KnowledgeItemType.url);
      expect(item.source, 'https://example.com/riverpod');
      expect(item.title, 'Riverpod Guide'); // fetched page title

      final hits =
          await urlService.search(baseId: base.id, query: 'providers');
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('providers'));
    });

    test('addUrl prefers an explicit title and falls back to the URL',
        () async {
      final urlService = KnowledgeService(
        db.knowledgeDao,
        urlFetcher: (url) async =>
            const KnowledgeFetchedPage(markdown: 'body text', title: null),
      );
      final base = await urlService.createBase(name: 'KB');

      final explicit = await urlService.addUrl(
        baseId: base.id,
        url: 'https://a.test',
        title: '  My Title  ',
      );
      expect(explicit.title, 'My Title');

      final fallback =
          await urlService.addUrl(baseId: base.id, url: 'https://b.test');
      expect(fallback.title, 'https://b.test'); // no title → URL itself
    });

    test('addUrl rejects empty url / empty fetched content / no fetcher',
        () async {
      final base = await service.createBase(name: 'KB');
      // No fetcher configured on the default `service`.
      expect(
        () => service.addUrl(baseId: base.id, url: 'https://x.test'),
        throwsStateError,
      );

      final emptyFetcher = KnowledgeService(
        db.knowledgeDao,
        urlFetcher: (url) async =>
            const KnowledgeFetchedPage(markdown: '   ', title: null),
      );
      final base2 = await emptyFetcher.createBase(name: 'KB2');
      expect(
        () => emptyFetcher.addUrl(baseId: base2.id, url: '  '),
        throwsStateError, // empty url
      );
      expect(
        () => emptyFetcher.addUrl(baseId: base2.id, url: 'https://x.test'),
        throwsStateError, // empty fetched content
      );
    });

    test('setFileProcessor persists, clears and rejects unknown ids',
        () async {
      final base = await service.createBase(name: 'KB');
      expect(base.fileProcessorId, isNull);

      await service.setFileProcessor(base.id, 'mineru');
      expect((await service.getBase(base.id))!.fileProcessorId, 'mineru');

      await service.setFileProcessor(base.id, null);
      expect((await service.getBase(base.id))!.fileProcessorId, isNull);

      expect(
        () => service.setFileProcessor(base.id, 'nope'),
        throwsStateError,
      );
    });

    test(
        'addProcessedFile ingests the cloud markdown snapshot and refresh '
        'does not re-call the cloud', () async {
      final calls = <(KnowledgeFileProcessor, String)>[];
      final cloudService = KnowledgeService(
        db.knowledgeDao,
        filePreprocessor: ({
          required processor,
          required fileName,
          required bytes,
        }) async {
          calls.add((processor, fileName));
          return '# Cloud Result\n\nParsed by cloud service.';
        },
      );
      final base = await cloudService.createBase(name: 'KB');
      await cloudService.setFileProcessor(base.id, 'doc2x');

      final item = await cloudService.addProcessedFile(
        baseId: base.id,
        fileName: 'paper.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(calls, [(KnowledgeFileProcessor.doc2x, 'paper.pdf')]);
      expect(item.type, KnowledgeItemType.file);
      expect(
        await cloudService.readItemContent(item.id),
        contains('Parsed by cloud service'),
      );

      // 权威快照已落库：重建索引从已存正文重建，不再重复调云端。
      final count = await cloudService.reindexBase(base.id);
      expect(count, 1);
      expect(calls.length, 1);

      final hits = await cloudService.search(baseId: base.id, query: 'cloud');
      expect(hits, isNotEmpty);
    });

    test(
        'addProcessedFile rejects missing processor / preprocessor / empty '
        'result', () async {
      // 库未配置处理器。
      final cloudService = KnowledgeService(
        db.knowledgeDao,
        filePreprocessor: ({
          required processor,
          required fileName,
          required bytes,
        }) async =>
            '   ',
      );
      final base = await cloudService.createBase(name: 'KB');
      expect(
        () => cloudService.addProcessedFile(
          baseId: base.id,
          fileName: 'a.pdf',
          bytes: Uint8List(0),
        ),
        throwsStateError,
      );

      // 未注入预处理器。
      await service.setFileProcessor(base.id, 'mistral');
      expect(
        () => service.addProcessedFile(
          baseId: base.id,
          fileName: 'a.pdf',
          bytes: Uint8List(0),
        ),
        throwsStateError,
      );

      // 云端返回空结果。
      expect(
        () => cloudService.addProcessedFile(
          baseId: base.id,
          fileName: 'a.pdf',
          bytes: Uint8List(0),
        ),
        throwsStateError,
      );
    });

    test('addWorkspace ingests every text file with a source fingerprint',
        () async {
      final wsService = KnowledgeService(
        db.knowledgeDao,
        workspaceSource: _FakeWorkspaceSource({
          '/a.md': ('a.md', 'alpha content', 100, 13),
          '/sub/b.txt': ('b.txt', 'bravo content', 200, 13),
          '/empty.txt': ('empty.txt', '   ', 300, 3), // blank → skipped
        }),
      );
      final base = await wsService.createBase(name: 'KB');
      final items = await wsService.addWorkspace(
        baseId: base.id,
        workspaceId: 'ws-1',
      );

      expect(items, hasLength(2));
      for (final item in items) {
        expect(item.type, KnowledgeItemType.workspace);
        expect(item.sourceFingerprint, isNotNull);
        expect(item.sourceFingerprint, contains('"workspaceId":"ws-1"'));
      }
      // Ingested content is searchable through the same pipeline.
      final hits = await wsService.search(baseId: base.id, query: 'bravo');
      expect(hits, isNotEmpty);
      expect(hits.first.possiblyStale, isNot(true));
    });

    test('addWorkspace rejects missing source / no ingestible files',
        () async {
      final base = await service.createBase(name: 'KB');
      // No workspace source configured on the default `service`.
      expect(
        () => service.addWorkspace(baseId: base.id, workspaceId: 'ws-1'),
        throwsStateError,
      );

      final emptyService = KnowledgeService(
        db.knowledgeDao,
        workspaceSource: _FakeWorkspaceSource(const {}),
      );
      final base2 = await emptyService.createBase(name: 'KB2');
      expect(
        () => emptyService.addWorkspace(baseId: base2.id, workspaceId: 'ws-1'),
        throwsStateError,
      );
    });

    test('search marks workspace hits possiblyStale when the file changed',
        () async {
      final source = _FakeWorkspaceSource({
        '/a.md': ('a.md', 'zulu content', 100, 12),
        '/b.md': ('b.md', 'yankee content', 100, 14),
      });
      final wsService =
          KnowledgeService(db.knowledgeDao, workspaceSource: source);
      final base = await wsService.createBase(name: 'KB');
      await wsService.addWorkspace(baseId: base.id, workspaceId: 'ws-1');

      // Untouched files → no stale flag.
      var hits = await wsService.search(baseId: base.id, query: 'zulu');
      expect(hits, isNotEmpty);
      expect(hits.first.possiblyStale, isNot(true));

      // mtime changed → stale; deleted file (stat null) → stale.
      source.files['/a.md'] = ('a.md', 'zulu content', 999, 12);
      hits = await wsService.search(baseId: base.id, query: 'zulu');
      expect(hits.first.possiblyStale, true);

      source.files.remove('/b.md');
      hits = await wsService.search(baseId: base.id, query: 'yankee');
      expect(hits.first.possiblyStale, true);

      // Non-workspace items are never flagged.
      await wsService.addNote(
        baseId: base.id,
        title: 'note',
        text: 'xray note',
      );
      hits = await wsService.search(baseId: base.id, query: 'xray');
      expect(hits, isNotEmpty);
      expect(hits.first.possiblyStale, isNot(true));
    });

    test('staleness check is best-effort: stat errors never break search',
        () async {
      final source = _FakeWorkspaceSource(
        {'/a.md': ('a.md', 'whiskey content', 100, 15)},
        statThrows: true,
      );
      final wsService =
          KnowledgeService(db.knowledgeDao, workspaceSource: source);
      final base = await wsService.createBase(name: 'KB');
      await wsService.addWorkspace(baseId: base.id, workspaceId: 'ws-1');

      final hits = await wsService.search(baseId: base.id, query: 'whiskey');
      expect(hits, isNotEmpty);
      expect(hits.first.possiblyStale, isNot(true));
    });

    test('deleteItem removes only that item and its derived rows', () async {
      final base = await service.createBase(name: 'KB');
      final keep =
          await service.addNote(baseId: base.id, title: 'keep', text: 'alpha');
      final drop =
          await service.addNote(baseId: base.id, title: 'drop', text: 'beta');

      await service.deleteItem(drop.id);

      final items = await service.listItems(base.id);
      expect(items.map((e) => e.id), [keep.id]);
      expect(await service.search(baseId: base.id, query: 'beta'), isEmpty);
      expect(
        await service.search(baseId: base.id, query: 'alpha'),
        isNotEmpty,
      );
    });

    test('trashItem soft-deletes; restoreItem rebuilds; emptyTrash purges',
        () async {
      final base = await service.createBase(name: 'KB');
      final item =
          await service.addNote(baseId: base.id, title: 'a', text: 'zeta');

      // 移入回收站：列表 / 检索排除，回收站可见，正文保留。
      await service.trashItem(item.id);
      expect(await service.listItems(base.id), isEmpty);
      expect(await service.search(baseId: base.id, query: 'zeta'), isEmpty);
      final trash = await service.listTrash(base.id);
      expect(trash.map((e) => e.id), [item.id]);
      expect(trash.single.deletedAt, isNotNull);

      // 恢复：条目回列表、索引重建、可再次检索。
      await service.restoreItem(item.id);
      expect(await service.listTrash(base.id), isEmpty);
      expect((await service.listItems(base.id)).map((e) => e.id), [item.id]);
      expect(await service.search(baseId: base.id, query: 'zeta'), isNotEmpty);

      // 恢复未删除条目抛错。
      await expectLater(service.restoreItem(item.id), throwsStateError);

      // 清空回收站：彻底删除。
      await service.trashItem(item.id);
      expect(await service.emptyTrash(base.id), 1);
      expect(await service.listTrash(base.id), isEmpty);
      expect(await service.readItemContent(item.id), isNull);
    });

    test('reindexItem rebuilds only that item and leaves siblings intact',
        () async {
      final base = await service.createBase(name: 'KB');
      final target =
          await service.addNote(baseId: base.id, title: 'a', text: 'gamma');
      final other =
          await service.addNote(baseId: base.id, title: 'b', text: 'delta');

      final count = await service.reindexItem(target.id);
      expect(count, greaterThan(0));

      // 目标条目的切块重建后仍可检索，其它条目不受影响。
      expect(await service.itemChunks(target.id), hasLength(count));
      expect(await service.search(baseId: base.id, query: 'gamma'), isNotEmpty);
      expect(await service.search(baseId: base.id, query: 'delta'), isNotEmpty);
      expect(await service.itemChunks(other.id), isNotEmpty);

      await expectLater(service.reindexItem('missing'), throwsStateError);
    });

    test('reindexBase rebuilds derived chunks from stored content', () async {
      final base = await service.createBase(name: 'KB');
      await service.addNote(baseId: base.id, title: 'a', text: 'gamma delta');
      await service.addNote(baseId: base.id, title: 'b', text: 'epsilon');

      final count = await service.reindexBase(base.id);
      expect(count, 2);

      // Content survives the rebuild → keyword search still hits.
      final hits = await service.search(baseId: base.id, query: 'gamma');
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('gamma'));
    });

    test('reindexBase on an empty base is a no-op returning 0', () async {
      final base = await service.createBase(name: 'KB');
      expect(await service.reindexBase(base.id), 0);
    });
  });

  group('embedding domain helpers', () {
    test('computeEmbeddingKey is stable and model-sensitive', () {
      final a1 = computeEmbeddingKey('model-a', 'hello world');
      final a2 = computeEmbeddingKey('model-a', 'hello world');
      final b = computeEmbeddingKey('model-b', 'hello world');
      final c = computeEmbeddingKey('model-a', 'other text');
      expect(a1, a2); // deterministic
      expect(a1, isNot(b)); // different model → different key
      expect(a1, isNot(c)); // different content → different key
    });

    test('vector codec round-trips and tolerates garbage', () {
      expect(decodeVector(encodeVector([1.0, -2.5, 3.0])), [1.0, -2.5, 3.0]);
      expect(decodeVector('not json'), isEmpty);
      expect(decodeVector('{"a":1}'), isEmpty);
    });

    test('cosineSimilarity: identical=1, orthogonal=0, zero=0', () {
      expect(cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1.0, 1e-9));
      expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0.0, 1e-9));
      expect(cosineSimilarity([0, 0], [1, 1]), 0.0);
      expect(cosineSimilarity([1, 2], [1, 2, 3]), 0.0); // length mismatch
    });

    test('fuseWithRrf rewards items ranked well in both lists', () {
      // 'b' appears in both rankings (2nd then 1st); 'a' and 'c' only once each.
      final fused = fuseWithRrf([
        ['a', 'b'],
        ['b', 'c'],
      ]);
      expect(fused.first, 'b');
      expect(fused.toSet(), {'a', 'b', 'c'});
    });
  });

  group('KnowledgeService (vector/hybrid P1)', () {
    late AppDatabase db;
    late List<List<String>> embedLog;

    KnowledgeService buildService({bool returnEmpty = false, bool known = true}) {
      final embedder = _FakeEmbedder(const [
        'dart',
        'python',
        'language',
        'native',
        'script',
      ], embedLog, returnEmpty: returnEmpty);
      return KnowledgeService(
        db.knowledgeDao,
        embedderResolver: (key) async =>
            (known && key == 'model-a') ? embedder : null,
      );
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      embedLog = [];
    });

    tearDown(() async {
      await db.close();
    });

    Future<KnowledgeBase> seed(
      KnowledgeService service,
      KnowledgeSearchMode mode, {
      String? modelKey = 'model-a',
    }) async {
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: modelKey,
        searchMode: mode,
      );
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
      return base;
    }

    test('createBase auto-detects embedding dimensions (gap ⑨)', () async {
      final service = buildService();
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.hybrid,
      );
      // _FakeEmbedder 的向量长度 == vocab 长度（5）。
      expect(base.dimensions, 5);
      expect((await service.getBase(base.id))!.dimensions, 5);

      // 无效模型 / 空向量：探测失败留空，不阻断建库。
      expect(await service.detectEmbeddingDimensions('unknown'), isNull);
      expect(
        await buildService(returnEmpty: true)
            .detectEmbeddingDimensions('model-a'),
        isNull,
      );
      final unknownBase = await buildService(known: false).createBase(
        name: 'KB2',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.hybrid,
      );
      expect(unknownBase.dimensions, isNull);
    });

    test('createBase without a model forces keyword mode', () async {
      final service = buildService();
      final base = await service.createBase(
        name: 'KB',
        searchMode: KnowledgeSearchMode.vector,
      );
      expect(base.embeddingModelKey, isNull);
      expect(base.searchMode, KnowledgeSearchMode.keyword);
    });

    test('vector search ranks by cosine similarity', () async {
      final service = buildService();
      final base = await seed(service, KnowledgeSearchMode.vector);
      final hits = await service.search(baseId: base.id, query: 'dart native');
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('dart'));
      expect(hits.first.similarity, greaterThan(0));
    });

    test('embedding dedups by embeddingKey across identical content', () async {
      final service = buildService();
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      const text = 'Dart compiles to native code.';
      await service.addNote(baseId: base.id, title: 'a', text: text);
      final batchesAfterFirst = embedLog.length;
      // Identical content → every chunk's embeddingKey already exists → no
      // second embed batch is issued during ingest.
      await service.addNote(baseId: base.id, title: 'b', text: text);
      expect(embedLog.length, batchesAfterFirst);
    });

    test('stored vectors are reused on a later search (no re-embed)', () async {
      final service = buildService();
      final base = await seed(service, KnowledgeSearchMode.vector);
      final ingestBatches = embedLog.length;
      await service.search(baseId: base.id, query: 'dart');
      // Only the query itself is embedded; chunk vectors come from kb_embedding.
      expect(embedLog.length, ingestBatches + 1);
      expect(embedLog.last, ['dart']);
    });

    test('hybrid fuses keyword + vector rankings', () async {
      final service = buildService();
      final base = await seed(service, KnowledgeSearchMode.hybrid);
      final hits = await service.search(baseId: base.id, query: 'dart');
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('dart'));
    });

    test('vector mode falls back to keyword when model unresolved', () async {
      final service = buildService(known: false);
      final base = await seed(service, KnowledgeSearchMode.vector);
      // Resolver returns null → no embeddings persisted → keyword fallback.
      final hits = await service.search(baseId: base.id, query: 'python');
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('python'));
    });

    test('vector mode falls back when embedding yields empty vectors',
        () async {
      final service = buildService(returnEmpty: true);
      final base = await seed(service, KnowledgeSearchMode.vector);
      final hits = await service.search(baseId: base.id, query: 'language');
      // Empty query/chunk vectors → _vectorScored returns null → keyword hits.
      expect(hits, isNotEmpty);
      expect(hits.first.content.toLowerCase(), contains('language'));
    });

    test('deleteBase GCs orphaned embeddings but keeps shared ones', () async {
      final service = buildService();
      const text = 'Dart compiles to native code.';
      final a = await service.createBase(
        name: 'A',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await service.addNote(baseId: a.id, title: 'a', text: text);
      final b = await service.createBase(
        name: 'B',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      // Same text + same model → same embeddingKey, shared (deduped) row.
      await service.addNote(baseId: b.id, title: 'b', text: text);

      final before = await db.select(db.kbEmbeddingRows).get();
      expect(before, isNotEmpty);

      // Deleting A leaves the shared embedding alive (still referenced by B).
      await service.deleteBase(a.id);
      expect(await db.select(db.kbEmbeddingRows).get(), before);

      // Deleting the last referencing base GCs the now-orphaned embedding.
      await service.deleteBase(b.id);
      expect(await db.select(db.kbEmbeddingRows).get(), isEmpty);
    });

    test('reindexBase reuses stored vectors without re-embedding', () async {
      final service = buildService();
      final base = await seed(service, KnowledgeSearchMode.vector);
      final batchesAfterIngest = embedLog.length;

      // Content is unchanged → every chunk's embeddingKey already exists, so
      // the rebuild issues no new embed batch (dedup, §5.1).
      final count = await service.reindexBase(base.id);
      expect(count, 2);
      expect(embedLog.length, batchesAfterIngest);

      // Vectors survive the rebuild → vector search still ranks by cosine.
      final hits = await service.search(baseId: base.id, query: 'dart native');
      expect(hits, isNotEmpty);
      expect(hits.first.similarity, greaterThan(0));
    });

    test('deleteItem GCs orphaned embeddings but keeps shared ones', () async {
      final service = buildService();
      const text = 'Dart compiles to native code.';
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      final shared =
          await service.addNote(baseId: base.id, title: 'a', text: text);
      // Same text + model → identical embeddingKey, shared (deduped) row.
      await service.addNote(baseId: base.id, title: 'b', text: text);

      final before = await db.select(db.kbEmbeddingRows).get();
      expect(before, isNotEmpty);

      // Deleting one referrer leaves the shared embedding alive.
      await service.deleteItem(shared.id);
      expect(await db.select(db.kbEmbeddingRows).get(), before);
    });

    test('threshold filters out low-similarity vector hits', () async {
      final service = buildService();
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await service.addNote(
        baseId: base.id,
        title: 'py',
        text: 'Python scripting only.',
      );
      // Query shares no vocab term with the note → cosine 0, below threshold.
      final hits = await service.search(
        baseId: base.id,
        query: 'dart',
        topK: 5,
      );
      // Keyword would also miss 'dart'; vector returns a 0-sim hit which the
      // base's null threshold keeps — assert similarity is 0 for that hit.
      for (final h in hits) {
        expect(h.similarity, 0);
      }
    });
  });

  group('KnowledgeService (failure recovery / quota / GC P3d)', () {
    late AppDatabase db;
    late List<List<String>> embedLog;

    KnowledgeService buildService({bool returnEmpty = false, bool known = true}) {
      final embedder = _FakeEmbedder(const [
        'dart',
        'python',
        'language',
      ], embedLog, returnEmpty: returnEmpty);
      return KnowledgeService(
        db.knowledgeDao,
        embedderResolver: (key) async =>
            (known && key == 'model-a') ? embedder : null,
      );
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      embedLog = [];
    });

    tearDown(() async {
      await db.close();
    });

    test('retryPendingEmbeddings backfills chunks left without vectors',
        () async {
      // Ingest while the embedder yields empty vectors → chunks stay pending.
      final broken = buildService(returnEmpty: true);
      final base = await broken.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await broken.addNote(baseId: base.id, title: 'a', text: 'dart language');
      expect(await broken.pendingEmbeddingCount(base.id), greaterThan(0));

      // Retry with a healthy embedder only embeds the pending chunks.
      final healthy = buildService();
      final embedded = await healthy.retryPendingEmbeddings(base.id);
      expect(embedded, greaterThan(0));
      expect(await healthy.pendingEmbeddingCount(base.id), 0);

      // The backfilled vectors are live: vector search ranks by cosine.
      final hits = await healthy.search(baseId: base.id, query: 'dart');
      expect(hits, isNotEmpty);
      expect(hits.first.similarity, greaterThan(0));
    });

    test('retryPendingEmbeddings is a no-op when nothing is pending', () async {
      final service = buildService();
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await service.addNote(baseId: base.id, title: 'a', text: 'dart');
      final batches = embedLog.length;
      expect(await service.retryPendingEmbeddings(base.id), 0);
      expect(embedLog.length, batches); // no extra embed calls
    });

    test('retryPendingEmbeddings returns 0 for keyword bases and when the '
        'model is unresolved', () async {
      final service = buildService();
      final kw = await service.createBase(name: 'KW');
      await service.addNote(baseId: kw.id, title: 'a', text: 'dart');
      expect(await service.retryPendingEmbeddings(kw.id), 0);
      expect(await service.pendingEmbeddingCount(kw.id), 0);

      final broken = buildService(returnEmpty: true);
      final vec = await broken.createBase(
        name: 'V',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await broken.addNote(baseId: vec.id, title: 'a', text: 'dart');
      final unresolved = buildService(known: false);
      expect(await unresolved.retryPendingEmbeddings(vec.id), 0);
      // Still pending — nothing was consumed by the failed retry.
      expect(await unresolved.pendingEmbeddingCount(vec.id), greaterThan(0));
    });

    test('retryPendingEmbeddings reuses existing vectors without re-embedding',
        () async {
      const text = 'dart language';
      // Ingest while the embedder is broken → chunks left pending.
      final broken = buildService(returnEmpty: true);
      final bad = await broken.createBase(
        name: 'B',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await broken.addNote(baseId: bad.id, title: 'b', text: text);
      expect(await broken.pendingEmbeddingCount(bad.id), greaterThan(0));

      // The same content is later embedded successfully elsewhere.
      final service = buildService();
      final good = await service.createBase(
        name: 'A',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await service.addNote(baseId: good.id, title: 'a', text: text);

      final batches = embedLog.length;
      final embedded = await service.retryPendingEmbeddings(bad.id);
      expect(embedded, greaterThan(0));
      // Identical content + model → embeddingKey already exists, so the retry
      // attaches the stored vector without a new embed batch.
      expect(embedLog.length, batches);
    });

    test('storageUsage aggregates counts and flags the soft limit', () async {
      final service = buildService();
      final base = await service.createBase(name: 'KB');
      await service.addNote(baseId: base.id, title: 'a', text: 'dart python');

      final usage = await service.storageUsage();
      expect(usage.stats.baseCount, 1);
      expect(usage.stats.itemCount, 1);
      expect(usage.stats.chunkCount, greaterThan(0));
      expect(usage.stats.contentBytes, greaterThan(0));
      expect(usage.stats.totalBytes, greaterThanOrEqualTo(
        usage.stats.contentBytes + usage.stats.chunkBytes,
      ));
      // Tiny fixture stays far below the 200MB soft limit.
      expect(usage.overSoftLimit, isFalse);
    });

    test('gcOrphanEmbeddings removes unreferenced vectors only', () async {
      final service = buildService();
      final base = await service.createBase(
        name: 'KB',
        embeddingModelKey: 'model-a',
        searchMode: KnowledgeSearchMode.vector,
      );
      await service.addNote(baseId: base.id, title: 'a', text: 'dart');
      expect(await service.gcOrphanEmbeddings(), 0); // all referenced

      // Simulate an orphan left behind by an interrupted rebuild.
      await db.into(db.kbEmbeddingRows).insert(
            KbEmbeddingRowsCompanion.insert(
              embeddingKey: 'orphan-key',
              dimensions: 2,
              vector: encodeVector(const [1.0, 0.0]),
              createdAt: 0,
            ),
          );
      expect(await service.gcOrphanEmbeddings(), 1);
      final rest = await db.select(db.kbEmbeddingRows).get();
      expect(rest.every((r) => r.embeddingKey != 'orphan-key'), isTrue);
      expect(rest, isNotEmpty); // referenced vectors survive
    });
  });

  group('KnowledgeService rerank (gap ⑥)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<KnowledgeBase> seed(KnowledgeService service) async {
      final base = await service.createBase(name: 'KB');
      await service.updateBaseRerankModel(base.id, 'rerank-a');
      await service.addNote(
        baseId: base.id,
        title: 'Dart',
        text: 'Dart is a client-optimized language for fast apps.',
      );
      await service.addNote(
        baseId: base.id,
        title: 'Python',
        text: 'Python is a general purpose language for scripting.',
      );
      return base;
    }

    test('updateBaseRerankModel persists / clears the key', () async {
      final service = KnowledgeService(db.knowledgeDao);
      final base = await service.createBase(name: 'KB');
      await service.updateBaseRerankModel(base.id, '  rerank-a  ');
      expect((await service.getBase(base.id))!.rerankModelKey, 'rerank-a');
      await service.updateBaseRerankModel(base.id, '   ');
      expect((await service.getBase(base.id))!.rerankModelKey, isNull);
      await expectLater(
        service.updateBaseRerankModel('missing', 'x'),
        throwsStateError,
      );
    });

    test('search re-orders hits by reranker scores and rewrites similarity',
        () async {
      final queries = <String>[];
      final service = KnowledgeService(
        db.knowledgeDao,
        rerankerResolver: (key) async => key == 'rerank-a'
            ? _FakeReranker((query, docs) {
                queries.add(query);
                // Python 片段拿高分，Dart 片段拿低分 → 反转关键词排序。
                return [
                  for (final d in docs) d.contains('Python') ? 0.9 : 0.1,
                ];
              })
            : null,
      );
      final base = await seed(service);

      final refs = await service.search(baseId: base.id, query: 'language');
      expect(refs, hasLength(2));
      expect(refs.first.content, contains('Python'));
      expect(refs.first.similarity, 0.9);
      expect(refs.first.index, 1);
      expect(refs.last.similarity, 0.1);
      expect(refs.last.index, 2);
      expect(queries, ['language']);
    });

    test('rerank is best-effort: failures keep the original order', () async {
      final service = KnowledgeService(
        db.knowledgeDao,
        rerankerResolver: (key) async =>
            _FakeReranker((_, _) => throw StateError('rerank down')),
      );
      final base = await seed(service);
      final refs = await service.search(baseId: base.id, query: 'Dart');
      expect(refs, isNotEmpty);
      expect(refs.first.content, contains('Dart'));
    });

    test('no rerank model → reranker never resolved, order unchanged',
        () async {
      var resolved = 0;
      final service = KnowledgeService(
        db.knowledgeDao,
        rerankerResolver: (key) async {
          resolved++;
          return null;
        },
      );
      final base = await service.createBase(name: 'KB');
      await service.addNote(baseId: base.id, title: 'Dart', text: 'Dart');
      await service.search(baseId: base.id, query: 'Dart');
      expect(resolved, 0);
    });
  });
}
