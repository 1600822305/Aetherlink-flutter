import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_url_fetcher.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_workspace_source.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';

/// Captures the enclosing [Ref] so tests can drive [runKnowledgeTool] (which is
/// `Ref`-dependent, exactly like the in-chat call site) against an overridden
/// [knowledgeServiceProvider].
final _runnerProvider =
    Provider<Future<McpToolResult> Function(String, Map<String, Object?>)>(
  (ref) => (name, args) => runKnowledgeTool(ref, name, args),
);

/// Same trick for the `Ref`-dependent [hasChatEnabledKnowledgeBase] probe.
final _hasChatProvider = Provider<Future<bool> Function()>(
  (ref) => () => hasChatEnabledKnowledgeBase(ref),
);

Map<String, Object?> _data(McpToolResult result) {
  final decoded = jsonDecode(result.text) as Map<String, Object?>;
  expect(decoded['success'], isTrue, reason: result.text);
  return decoded['data'] as Map<String, Object?>;
}

/// Fixed two-file workspace source for the `add_workspace` action tests.
class _StubWorkspaceSource implements KnowledgeWorkspaceSource {
  @override
  Future<List<KnowledgeWorkspaceFile>> listTextFiles(
    String workspaceId,
  ) async => const [
    KnowledgeWorkspaceFile(
      path: '/a.md',
      name: 'a.md',
      text: 'alpha content',
      mtime: 100,
      size: 13,
    ),
    KnowledgeWorkspaceFile(
      path: '/b.txt',
      name: 'b.txt',
      text: 'bravo content',
      mtime: 200,
      size: 13,
    ),
  ];

  @override
  Future<KnowledgeWorkspaceStat?> statFile(
    String workspaceId,
    String path,
  ) async => null;
}

void main() {
  group('knowledgeToolRiskLevel / needsConfirmation', () {
    test('read-only tools never need confirmation', () {
      for (final name in [
        kKnowledgeListTool,
        kKnowledgeSearchTool,
        kKnowledgeReadTool,
      ]) {
        expect(knowledgeToolRiskLevel(name, const {}), isNull);
        expect(knowledgeToolNeedsConfirmation(name, const {}), isFalse);
      }
    });

    test('kb_manage grades delete high, others medium, and always confirms',
        () {
      expect(
        knowledgeToolRiskLevel(kKnowledgeManageTool, {'action': 'delete'}),
        KnowledgeToolRisk.high,
      );
      for (final action in [
        'create',
        'add_note',
        'add_url',
        'add_workspace',
        'refresh',
        'retry_embeddings',
      ]) {
        expect(
          knowledgeToolRiskLevel(kKnowledgeManageTool, {'action': action}),
          KnowledgeToolRisk.medium,
        );
      }
      // Missing/unknown action defensively treated as a write.
      expect(
        knowledgeToolRiskLevel(kKnowledgeManageTool, const {}),
        KnowledgeToolRisk.medium,
      );
      expect(
        knowledgeToolNeedsConfirmation(kKnowledgeManageTool, {'action': 'x'}),
        isTrue,
      );
    });
  });

  group('runKnowledgeTool', () {
    late AppDatabase db;
    late KnowledgeService service;
    late ProviderContainer container;
    late Future<McpToolResult> Function(String, Map<String, Object?>) run;
    late Future<bool> Function() hasChatBase;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = KnowledgeService(db.knowledgeDao);
      container = ProviderContainer(
        overrides: [knowledgeServiceProvider.overrideWithValue(service)],
      );
      run = container.read(_runnerProvider);
      hasChatBase = container.read(_hasChatProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('hasChatEnabledKnowledgeBase reflects base existence', () async {
      expect(await hasChatBase(), isFalse);
      await service.createBase(name: 'private');
      expect(await hasChatBase(), isTrue);
    });

    test('kb_list surfaces all bases', () async {
      await service.createBase(name: 'private');
      await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );

      final data = _data(await run(kKnowledgeListTool, const {}));
      final bases = (data['knowledgeBases'] as List).cast<Map<String, dynamic>>();
      expect(bases, hasLength(2));
      expect({for (final b in bases) b['name']}, {'private', 'shared'});
    });

    test('kb_list of a base lists its items', () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      await service.addNote(baseId: base.id, title: 'N1', text: 'hello world');

      final data = _data(await run(kKnowledgeListTool, {'base_id': base.id}));
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(1));
      expect(items.single['title'], 'N1');
    });

    test('kb_search finds a note and returns its documentId', () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final item = await service.addNote(
        baseId: base.id,
        title: 'Dart',
        text: 'Flutter uses the Dart language for building apps.',
      );

      final data = _data(await run(kKnowledgeSearchTool, {'query': 'Dart'}));
      final results = (data['results'] as List).cast<Map<String, dynamic>>();
      expect(results, isNotEmpty);
      expect(results.first['documentId'], item.id);
    });

    test('kb_search errors when no base exists', () async {
      final result = await run(kKnowledgeSearchTool, {'query': 'x'});
      expect(result.isError, isTrue);
    });

    test('kb_read returns full content for a chat base item', () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final item = await service.addNote(
        baseId: base.id,
        title: 'Note',
        text: 'the quick brown fox',
      );

      final data = _data(
        await run(kKnowledgeReadTool, {
          'base_id': base.id,
          'document_id': item.id,
        }),
      );
      expect(data['content'], 'the quick brown fox');
      expect(data['truncated'], isFalse);
    });

    test('kb_read errors for an item from another base', () async {
      final a = await service.createBase(
        name: 'a',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final b = await service.createBase(
        name: 'b',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final item = await service.addNote(baseId: b.id, title: 't', text: 'x');

      final result = await run(kKnowledgeReadTool, {
        'base_id': a.id,
        'document_id': item.id,
      });
      expect(result.isError, isTrue);
    });

    test('kb_manage create makes a base visible to chat', () async {
      final data = _data(
        await run(kKnowledgeManageTool, {
          'action': 'create',
          'name': 'from model',
        }),
      );
      final id = data['knowledgeBaseId'] as String;
      final base = await service.getBase(id);
      expect(base, isNotNull);
      // Immediately visible to the chat track.
      expect(await hasChatBase(), isTrue);
    });

    test('kb_manage add_note ingests into a chat base', () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final data = _data(
        await run(kKnowledgeManageTool, {
          'action': 'add_note',
          'base_id': base.id,
          'title': 'T',
          'text': 'body text',
        }),
      );
      expect(data['documentId'], isNotNull);
      expect(await service.itemCount(base.id), 1);
    });

    test('kb_manage add_url fetches, converts and ingests into a chat base',
        () async {
      final urlService = KnowledgeService(
        db.knowledgeDao,
        urlFetcher: (url) async => KnowledgeFetchedPage(
          markdown: '# Fetched\n\nbody of $url',
          title: 'Fetched',
        ),
      );
      final urlContainer = ProviderContainer(
        overrides: [knowledgeServiceProvider.overrideWithValue(urlService)],
      );
      addTearDown(urlContainer.dispose);
      final urlRun = urlContainer.read(_runnerProvider);

      final base = await urlService.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final data = _data(
        await urlRun(kKnowledgeManageTool, {
          'action': 'add_url',
          'base_id': base.id,
          'url': 'https://example.com/a',
        }),
      );
      expect(data['documentId'], isNotNull);
      expect(data['title'], 'Fetched');
      expect(data['source'], 'https://example.com/a');
      expect(await urlService.itemCount(base.id), 1);
    });

    test('kb_manage add_url requires the url argument', () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final result = await run(kKnowledgeManageTool, {
        'action': 'add_url',
        'base_id': base.id,
      });
      expect(result.isError, isTrue);
    });

    test('kb_manage add_workspace ingests workspace text files', () async {
      final wsService = KnowledgeService(
        db.knowledgeDao,
        workspaceSource: _StubWorkspaceSource(),
      );
      final wsContainer = ProviderContainer(
        overrides: [knowledgeServiceProvider.overrideWithValue(wsService)],
      );
      addTearDown(wsContainer.dispose);
      final wsRun = wsContainer.read(_runnerProvider);

      final base = await wsService.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final data = _data(
        await wsRun(kKnowledgeManageTool, {
          'action': 'add_workspace',
          'base_id': base.id,
          'workspace_id': 'ws-1',
        }),
      );
      expect(data['workspaceId'], 'ws-1');
      expect(data['ingestedFiles'], 2);
      expect(await wsService.itemCount(base.id), 2);
    });

    test('kb_manage add_workspace requires the workspace_id argument',
        () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      final result = await run(kKnowledgeManageTool, {
        'action': 'add_workspace',
        'base_id': base.id,
      });
      expect(result.isError, isTrue);
    });

    test('kb_manage delete removes the base', () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      await run(kKnowledgeManageTool, {
        'action': 'delete',
        'base_id': base.id,
      });
      expect(await service.getBase(base.id), isNull);
    });

    test('kb_manage refresh rebuilds the index and reports item count',
        () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      await service.addNote(baseId: base.id, title: 'n', text: 'alpha beta');
      final result = await run(kKnowledgeManageTool, {
        'action': 'refresh',
        'base_id': base.id,
      });
      expect(result.isError, isFalse);
      expect(result.text, contains('"reindexedItems": 1'));
      // Content survives the rebuild → still searchable.
      expect(
        await service.search(baseId: base.id, query: 'alpha'),
        isNotEmpty,
      );
    });

    test('kb_manage retry_embeddings reports embedded and pending counts',
        () async {
      final base = await service.createBase(
        name: 'shared',
        scope: const KnowledgeScope(chatEnabled: true),
      );
      await service.addNote(baseId: base.id, title: 'n', text: 'alpha');
      final result = await run(kKnowledgeManageTool, {
        'action': 'retry_embeddings',
        'base_id': base.id,
      });
      // Keyword base → nothing to backfill, but the call succeeds.
      expect(result.isError, isFalse);
      expect(result.text, contains('"embeddedChunks": 0'));
      expect(result.text, contains('"pendingChunks": 0'));
    });

    test('unknown tool name yields an error result', () async {
      final result = await run('kb_bogus', const {});
      expect(result.isError, isTrue);
    });
  });
}
