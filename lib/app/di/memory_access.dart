import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_settings_controller.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';
import 'package:aetherlink_flutter/features/memory/data/embedding_service.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_consolidation.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_extraction.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_injection.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_scope.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_settings.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_vector.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'memory_access.g.dart';

/// App-level composition seam exposing the 普通聊天 memory store.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's
/// `application` / `data`; only its `domain` is allowed. [ChatMemoryStore] needs
/// the single app-wide Drift handle, which lives behind chat's
/// `appDatabaseProvider` (chat's `application`). So the store is composed here in
/// `app/` (the composition root, which may depend on any feature) and the memory
/// feature reaches it through this seam instead of importing `chat/application`
/// directly.
@Riverpod(keepAlive: true)
ChatMemoryStore chatMemoryStore(Ref ref) =>
    ChatMemoryStore(ref.watch(appDatabaseProvider).memoryDao);

/// The result of resolving what to inject for a turn: the `<user_memories>`
/// [section] string (null when nothing is injected) plus the exact memory
/// contents that went in ([memories], injection order: global then assistant).
/// The chat pipeline uses [section] for the system prompt and [memories] to
/// render the 对话内「本轮注入 N 条记忆」可展开块.
class ChatMemoryInjection {
  const ChatMemoryInjection({this.section, this.memories = const <String>[]});

  final String? section;
  final List<String> memories;

  bool get isEmpty => section == null || section!.isEmpty;
  int get count => memories.length;
}

/// Resolves the memories to inject for the assistant identified by [assistantId]
/// (null/empty → global only), retrieving against the current user [query].
/// Returns an empty result when memory is disabled or the injection mode is
/// [MemoryInjectionMode.off].
///
/// Branches by [MemorySettings.injectionMode]:
/// - `full` → every in-scope memory (global + assistant), unchanged behaviour.
/// - `auto` → global always full-dumped; the assistant pool is full-dumped when
///   the total collection is at/below `fullDumpThreshold`, otherwise narrowed to
///   the semantic top-k.
/// - `semantic` → vector top-k across global + assistant via the configured
///   embedding model (lazily embedding + caching any memory that lacks a current
///   vector); degrades to `keyword` when no embedding model is configured.
/// - `keyword` → local substring match against [query], no API call.
/// - `off` → nothing.
/// Retrieval modes fall back to a full dump when [query] is empty (e.g. a
/// regenerate with no fresh user turn) so they never silently inject nothing.
///
/// Retrieval selections (`keyword`/`semantic`/narrowed `auto`) are logged as
/// hits (`accessCount`/`lastAccessedAt`) for the 命中日志 / eval surface; full
/// dumps are not, since injecting everything indiscriminately isn't a recall.
///
/// Lives here (the composition root) because the chat feature must not import
/// `memory/application` or `memory/data` directly: it reads settings
/// ([MemorySettingsController]), the stored memories ([ChatMemoryStore]) and the
/// embedding model (the `models` store), then formats them with the pure
/// `memory/domain` helpers.
Future<ChatMemoryInjection> collectChatMemoryInjection(
  Ref ref, {
  String? assistantId,
  String? query,
}) async {
  final settings = ref.read(memorySettingsControllerProvider);
  final mode = settings.injectionMode;
  if (!settings.enabled || mode == MemoryInjectionMode.off) {
    return const ChatMemoryInjection();
  }
  final store = ref.read(chatMemoryStoreProvider);
  final global = await store.list(const MemoryScope.chatGlobal());
  final assistant = (assistantId == null || assistantId.isEmpty)
      ? const <MemoryItem>[]
      : await store.list(MemoryScope.chatAssistant(assistantId));

  final q = query?.trim() ?? '';

  // `full`, or any retrieval mode without a query to retrieve against, injects
  // the whole in-scope collection.
  if (mode == MemoryInjectionMode.full || q.isEmpty) {
    return _dump(global, assistant);
  }

  switch (mode) {
    case MemoryInjectionMode.keyword:
      final selected = _keywordTopK([...global, ...assistant], q, settings.topK);
      await store.recordHits(selected);
      return _dump(_globalOf(selected), _assistantOf(selected));
    case MemoryInjectionMode.semantic:
      final selected = await _semanticTopK(
        ref,
        [...global, ...assistant],
        q,
        settings,
      );
      await store.recordHits(selected);
      return _dump(_globalOf(selected), _assistantOf(selected));
    case MemoryInjectionMode.auto:
      // Global is always full-dumped (small by nature); the assistant pool is
      // narrowed only once the whole collection outgrows the threshold.
      if (global.length + assistant.length <= settings.fullDumpThreshold) {
        return _dump(global, assistant);
      }
      final selectedAssistant = await _semanticTopK(ref, assistant, q, settings);
      await store.recordHits(selectedAssistant);
      return _dump(global, selectedAssistant);
    case MemoryInjectionMode.full:
    case MemoryInjectionMode.off:
    case MemoryInjectionMode.tool:
      return _dump(global, assistant);
  }
}

ChatMemoryInjection _dump(
  List<MemoryItem> global,
  List<MemoryItem> assistant,
) {
  final section = buildMemoryPromptSection(global: global, assistant: assistant);
  final memories = <String>[
    for (final m in global)
      if (m.content.trim().isNotEmpty) m.content.trim(),
    for (final m in assistant)
      if (m.content.trim().isNotEmpty) m.content.trim(),
  ];
  return ChatMemoryInjection(section: section, memories: memories);
}

List<MemoryItem> _globalOf(List<MemoryItem> items) =>
    [for (final m in items) if (m.level == MemoryLevel.global) m];

List<MemoryItem> _assistantOf(List<MemoryItem> items) =>
    [for (final m in items) if (m.level != MemoryLevel.global) m];

/// Local substring ranking: keeps [candidates] whose content contains any
/// whitespace-split token of [query] (case-insensitive), ordered by how many
/// distinct tokens they match, capped at [topK]. Returns an empty list when
/// nothing matches (no API call, the no-embedding-model fallback).
List<MemoryItem> _keywordTopK(
  List<MemoryItem> candidates,
  String query,
  int topK,
) {
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toSet();
  if (tokens.isEmpty) return const <MemoryItem>[];
  final scored = <(MemoryItem, int)>[];
  for (final item in candidates) {
    final content = item.content.toLowerCase();
    final hits = tokens.where(content.contains).length;
    if (hits > 0) scored.add((item, hits));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final limit = topK < 1 ? 1 : topK;
  final kept = scored.length > limit ? scored.sublist(0, limit) : scored;
  return [for (final entry in kept) entry.$1];
}

/// Vector ranking of [candidates] against [query] using the configured embedding
/// model. Lazily embeds (and caches) any candidate missing a vector for the
/// current model, embeds the query, and returns the cosine top-k. Falls back to
/// [_keywordTopK] when no embedding model is configured or any embedding call
/// fails.
Future<List<MemoryItem>> _semanticTopK(
  Ref ref,
  List<MemoryItem> candidates,
  String query,
  MemorySettings settings,
) async {
  if (candidates.isEmpty) return const <MemoryItem>[];
  final modelKey = settings.embeddingModelKey;
  final providers = await ref.read(appModelProvidersProvider.future);
  final model = _resolveEmbeddingModel(providers, modelKey);
  if (model == null || modelKey == null) {
    return _keywordTopK(candidates, query, settings.topK);
  }

  try {
    final service = EmbeddingService(
      buildLlmDio(proxy: ref.read(appNetworkProxyConfigProvider)),
    );
    final store = ref.read(chatMemoryStoreProvider);

    // Lazily (re)embed any memory whose cached vector is missing or was produced
    // by a different model, then persist it so later turns reuse the vector.
    final stale = <MemoryItem>[
      for (final item in candidates)
        if (item.embedding == null ||
            item.embedding!.isEmpty ||
            item.embeddingModelId != modelKey)
          item,
    ];
    final resolved = <String, MemoryItem>{for (final m in candidates) m.id: m};
    if (stale.isNotEmpty) {
      final vectors = await service.embedAll(
        model,
        [for (final m in stale) m.content],
      );
      for (var i = 0; i < stale.length; i++) {
        final vector = i < vectors.length ? vectors[i] : const <double>[];
        if (vector.isEmpty) continue;
        final updated = stale[i].copyWith(
          embedding: vector,
          embeddingModelId: modelKey,
        );
        resolved[updated.id] = updated;
        await store.persistEmbedding(updated);
      }
    }

    final queryVector = await service.embed(model, query);
    if (queryVector.isEmpty) {
      return _keywordTopK(candidates, query, settings.topK);
    }
    final pool = resolved.values.toList();
    final ranked = settings.activationRanking
        ? rankByActivation(
            queryVector,
            pool,
            settings.topK,
            nowMillis: DateTime.now().millisecondsSinceEpoch,
          )
        : rankBySimilarity(queryVector, pool, settings.topK);
    if (ranked.isEmpty) {
      return _keywordTopK(candidates, query, settings.topK);
    }
    return [for (final scored in ranked) scored.item];
  } on Object {
    // Embedding is best-effort; never break a turn over a retrieval failure.
    return _keywordTopK(candidates, query, settings.topK);
  }
}

/// Resolves the persisted [key] to a send-ready embedding [Model] (provider
/// endpoint + credentials merged in), or `null` when the key is unset/malformed
/// or its provider/model no longer exists.
Model? _resolveEmbeddingModel(List<ModelProvider> providers, String? key) {
  final pair = decodeEmbeddingModelKey(key);
  if (pair == null) return null;
  final (providerId, modelId) = pair;
  for (final provider in providers) {
    if (provider.id != providerId) continue;
    for (final model in provider.models) {
      if (model.id == modelId) {
        return effectiveModelFor(
          CurrentModel(provider: provider, model: model),
        );
      }
    }
  }
  return null;
}

/// Builds just the `<user_memories>` system-prompt block — a thin wrapper over
/// [collectChatMemoryInjection] for callers that only need the prompt text.
Future<String?> buildChatMemoryInjection(
  Ref ref, {
  String? assistantId,
  String? query,
}) async =>
    (await collectChatMemoryInjection(
      ref,
      assistantId: assistantId,
      query: query,
    ))
        .section;

/// The 自动写入 gate for autoAnalyze, read from [MemorySettingsController].
/// Lives here because the chat feature (which drives extraction after a turn)
/// must not import `memory/application` directly.
({bool enabled, bool autoWritePrivate, bool autoWriteGlobal})
    readMemoryAutoWriteFlags(Ref ref) {
  final settings = ref.read(memorySettingsControllerProvider);
  return (
    enabled: settings.enabled,
    autoWritePrivate: settings.autoWritePrivate,
    autoWriteGlobal: settings.autoWriteGlobal,
  );
}

/// Persists auto-extracted memory [candidates] for the turn that just finished
/// on [assistantId]. Candidates are dropped when their level isn't permitted by
/// the 自动写入 toggles, or when an equal (case-insensitive) memory already
/// exists in the target bucket (dedupe). Each surviving candidate is written
/// with [MemorySource.auto]. Returns how many were stored, and invalidates the
/// 记忆 list/count providers when anything changed.
///
/// Composed in `app/` so the chat feature never reaches into `memory/data`.
Future<int> storeExtractedChatMemories(
  Ref ref, {
  required String assistantId,
  required List<MemoryExtractionCandidate> candidates,
}) async {
  if (candidates.isEmpty) return 0;
  final store = ref.read(chatMemoryStoreProvider);

  final existingGlobal = {
    for (final m in await store.list(const MemoryScope.chatGlobal()))
      m.content.trim().toLowerCase(),
  };
  final hasAssistant = assistantId.isNotEmpty;
  final existingAssistant = hasAssistant
      ? {
          for (final m in await store.list(
            MemoryScope.chatAssistant(assistantId),
          ))
            m.content.trim().toLowerCase(),
        }
      : <String>{};

  var written = 0;
  for (final candidate in candidates) {
    final isGlobal = candidate.level == MemoryLevel.global;
    // Owner candidates require a target assistant; skip them otherwise.
    if (!isGlobal && !hasAssistant) continue;
    final key = candidate.content.trim().toLowerCase();
    final seen = isGlobal ? existingGlobal : existingAssistant;
    if (seen.contains(key)) continue;
    seen.add(key);

    await store.create(
      MemoryItem(
        id: '',
        content: candidate.content.trim(),
        level: isGlobal ? MemoryLevel.global : MemoryLevel.owner,
        ownerId: isGlobal ? null : assistantId,
        type: candidate.type,
        importance: candidate.importance,
        source: MemorySource.auto,
      ),
    );
    written++;
  }

  if (written > 0) {
    ref.invalidate(memoryCountsProvider);
    ref.invalidate(globalMemoriesControllerProvider);
    if (hasAssistant) {
      ref.invalidate(assistantMemoryOwnerCountsProvider);
      ref.invalidate(assistantMemoriesControllerProvider(assistantId));
    }
  }
  return written;
}

/// Tally of an opportunistic 巩固 (Dream) run: how many semantic facts were
/// newly [created], how many existing ones were [updated] (再巩固), how many
/// episodic rows were [scannedEpisodic] across all buckets, and how many
/// soft-deleted memories were [purged] (permanently removed past retention).
class MemoryConsolidationResult {
  const MemoryConsolidationResult({
    required this.created,
    required this.updated,
    required this.scannedEpisodic,
    this.purged = 0,
  });

  final int created;
  final int updated;
  final int scannedEpisodic;
  final int purged;

  int get changed => created + updated;
}

/// A bucket needs at least this many episodic memories before consolidating —
/// distilling a single event into a "stable" fact is rarely worthwhile.
const int _minEpisodicToConsolidate = 3;

/// Exposes [consolidateChatMemories] to the UI (which only has a `WidgetRef`):
/// the notifier owns a `Ref`, so the 记忆 home page's 整理记忆 button calls
/// `ref.read(memoryConsolidatorProvider.notifier).run()`. Kept alive because it
/// is only `read` to fire a one-shot pass (no widget watches it).
@Riverpod(keepAlive: true)
class MemoryConsolidator extends _$MemoryConsolidator {
  @override
  void build() {}

  Future<MemoryConsolidationResult> run() => consolidateChatMemories(ref);
}

/// Runs an opportunistic 巩固 (Dream) pass over the 普通聊天 memories: for each
/// scope bucket (global + every assistant that owns memories) it asks the
/// auxiliary model to distil that bucket's episodic events into stable semantic
/// facts, then either adds a new fact (deduped, case-insensitive) or
/// re-consolidates (UPDATEs) an existing semantic fact in place. Episodic rows
/// are left intact — they fade through activation/decay (a later phase), not by
/// being deleted here.
///
/// Mobile has no reliable background scheduler, so this is triggered manually
/// via the 整理记忆 button rather than on a timer. Best-effort per bucket: a
/// bucket whose model call or parse fails is skipped without aborting the rest.
/// A no-op when memory is disabled or no auxiliary/chat model is configured.
/// Stamps [MemorySettingsController.setLastConsolidated] and invalidates the
/// 记忆 list/count providers when anything changed.
///
/// Composed in `app/` because it must read settings, the memory store and the
/// auxiliary model + LLM gateway across feature boundaries.
Future<MemoryConsolidationResult> consolidateChatMemories(Ref ref) async {
  const empty =
      MemoryConsolidationResult(created: 0, updated: 0, scannedEpisodic: 0);
  final settings = ref.read(memorySettingsControllerProvider);
  if (!settings.enabled) return empty;
  final store = ref.read(chatMemoryStoreProvider);

  // Purge soft-deleted memories past their retention window first — this needs
  // no model and reclaims space even when consolidation has nothing to do.
  final purged = await store.purge(retentionDays: settings.retentionDays);

  // Resolve the consolidation model: 快速 → 标题 → current chat model.
  final auxState = ref.read(auxiliaryModelControllerProvider);
  final providers = await ref.read(appModelProvidersProvider.future);
  var resolved = resolveAuxiliaryModel(auxState.fastModelKey, providers);
  resolved ??= resolveAuxiliaryModel(auxState.titleModelKey, providers);
  resolved ??= findCurrentModel(providers);
  // No model to consolidate with, but a purge may still have happened above —
  // surface it (and refresh the lists) instead of discarding the count.
  if (resolved == null) {
    if (purged > 0) {
      ref.invalidate(memoryCountsProvider);
      ref.invalidate(globalMemoriesControllerProvider);
      ref.invalidate(assistantMemoryOwnerCountsProvider);
    }
    return MemoryConsolidationResult(
      created: 0,
      updated: 0,
      scannedEpisodic: 0,
      purged: purged,
    );
  }
  final effective = effectiveModelFor(resolved);
  final gateway = ref.read(appLlmGatewayFactoryProvider).forModel(effective);

  // The buckets to consolidate: global + each assistant that owns memories.
  final scopes = <MemoryScope>[const MemoryScope.chatGlobal()];
  for (final ownerId in (await store.ownerCounts()).keys) {
    scopes.add(MemoryScope.chatAssistant(ownerId));
  }

  var created = 0;
  var updated = 0;
  var scanned = 0;
  var touchedGlobal = false;
  var touchedAssistant = false;

  for (final scope in scopes) {
    final all = await store.list(scope);
    final episodic = [
      for (final m in all)
        if (m.type == MemoryType.episodic) m,
    ];
    if (episodic.length < _minEpisodicToConsolidate) continue;
    final semantic = [
      for (final m in all)
        if (m.type == MemoryType.semantic) m,
    ];
    scanned += episodic.length;

    final ops = await _runConsolidationBucket(
      gateway: gateway,
      model: effective,
      episodic: episodic,
      semantic: semantic,
    );
    if (ops.isEmpty) continue;

    final isGlobal = scope.level == MemoryLevel.global;
    final seen = {for (final m in semantic) m.content.trim().toLowerCase()};

    for (final op in ops) {
      final idx = op.updatesIndex;
      if (idx != null && idx < semantic.length) {
        // 再巩固: refine an existing semantic fact in place (skip a no-op).
        final target = semantic[idx];
        if (target.content.trim() == op.content.trim()) continue;
        await store.update(
          target.copyWith(
            content: op.content,
            importance: op.importance,
            source: MemorySource.auto,
          ),
        );
        seen.add(op.content.trim().toLowerCase());
        updated++;
        isGlobal ? touchedGlobal = true : touchedAssistant = true;
        continue;
      }
      final key = op.content.trim().toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      await store.create(
        MemoryItem(
          id: '',
          content: op.content,
          level: isGlobal ? MemoryLevel.global : MemoryLevel.owner,
          ownerId: isGlobal ? null : scope.ownerId,
          type: MemoryType.semantic,
          importance: op.importance,
          source: MemorySource.auto,
        ),
      );
      created++;
      isGlobal ? touchedGlobal = true : touchedAssistant = true;
    }
  }

  ref
      .read(memorySettingsControllerProvider.notifier)
      .setLastConsolidated(DateTime.now().millisecondsSinceEpoch);

  if (created + updated > 0 || purged > 0) {
    ref.invalidate(memoryCountsProvider);
    if (touchedGlobal || purged > 0) {
      ref.invalidate(globalMemoriesControllerProvider);
    }
    if (touchedAssistant || purged > 0) {
      ref.invalidate(assistantMemoryOwnerCountsProvider);
    }
  }
  return MemoryConsolidationResult(
    created: created,
    updated: updated,
    scannedEpisodic: scanned,
    purged: purged,
  );
}

/// Runs one bucket's consolidation prompt through [gateway] and parses the
/// reply. Best-effort: any failure yields an empty op list so the caller can
/// move on to the next bucket.
Future<List<MemoryConsolidationOp>> _runConsolidationBucket({
  required LlmGateway gateway,
  required Model model,
  required List<MemoryItem> episodic,
  required List<MemoryItem> semantic,
}) async {
  try {
    final prompt = buildMemoryConsolidationPrompt(
      episodics: [for (final m in episodic) m.content],
      existingSemantic: [for (final m in semantic) m.content],
    );
    final request = LlmChatRequest(
      model: model,
      messages: [LlmMessage(role: MessageRole.user, content: prompt)],
      extraHeaders: model.providerExtraHeaders,
      extraBody: model.providerExtraBody,
    );
    final buffer = StringBuffer();
    await for (final chunk in gateway.streamChat(request)) {
      if (chunk is LlmTextDelta) buffer.write(chunk.text);
    }
    return parseMemoryConsolidationResponse(
      buffer.toString(),
      semanticCount: semantic.length,
    );
  } on Object {
    return const [];
  }
}
