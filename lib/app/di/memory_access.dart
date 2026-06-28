import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_providers.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_settings_controller.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_extraction.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_injection.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_scope.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_settings.dart';

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
/// (null/empty → global only). Returns an empty result when memory is disabled
/// or the injection mode is [MemoryInjectionMode.off].
///
/// Lives here (the composition root) because the chat feature must not import
/// `memory/application` or `memory/data` directly: it reads the master switch +
/// injection mode ([MemorySettingsController]) and the stored memories
/// ([ChatMemoryStore]), then formats them with the pure `memory/domain` helper.
Future<ChatMemoryInjection> collectChatMemoryInjection(
  Ref ref, {
  String? assistantId,
}) async {
  final settings = ref.read(memorySettingsControllerProvider);
  if (!settings.enabled || settings.injectionMode == MemoryInjectionMode.off) {
    return const ChatMemoryInjection();
  }
  final store = ref.read(chatMemoryStoreProvider);
  final global = await store.list(const MemoryScope.chatGlobal());
  final assistant = (assistantId == null || assistantId.isEmpty)
      ? const <MemoryItem>[]
      : await store.list(MemoryScope.chatAssistant(assistantId));
  final section = buildMemoryPromptSection(global: global, assistant: assistant);
  final memories = <String>[
    for (final m in global)
      if (m.content.trim().isNotEmpty) m.content.trim(),
    for (final m in assistant)
      if (m.content.trim().isNotEmpty) m.content.trim(),
  ];
  return ChatMemoryInjection(section: section, memories: memories);
}

/// Builds just the `<user_memories>` system-prompt block — a thin wrapper over
/// [collectChatMemoryInjection] for callers that only need the prompt text.
Future<String?> buildChatMemoryInjection(Ref ref, {String? assistantId}) async =>
    (await collectChatMemoryInjection(ref, assistantId: assistantId)).section;

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
