import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/memory/application/memory_settings_controller.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';
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

/// Builds the `<user_memories>` block the chat pipeline appends to the system
/// prompt for the assistant identified by [assistantId] (null/empty → global
/// only). Returns null when memory is disabled, the injection mode is
/// [MemoryInjectionMode.off], or there is nothing to inject.
///
/// Lives here (the composition root) because the chat feature must not import
/// `memory/application` or `memory/data` directly: it reads the master switch +
/// injection mode ([MemorySettingsController]) and the stored memories
/// ([ChatMemoryStore]), then formats them with the pure `memory/domain` helper.
Future<String?> buildChatMemoryInjection(Ref ref, {String? assistantId}) async {
  final settings = ref.read(memorySettingsControllerProvider);
  if (!settings.enabled || settings.injectionMode == MemoryInjectionMode.off) {
    return null;
  }
  final store = ref.read(chatMemoryStoreProvider);
  final global = await store.list(const MemoryScope.chatGlobal());
  final assistant = (assistantId == null || assistantId.isEmpty)
      ? const <MemoryItem>[]
      : await store.list(MemoryScope.chatAssistant(assistantId));
  return buildMemoryPromptSection(global: global, assistant: assistant);
}
