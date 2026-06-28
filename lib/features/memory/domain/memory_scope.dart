import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// A recall/query filter that pins reads and writes to exactly one memory
/// bucket. The two axes ([MemoryKind] × [MemoryLevel]) yield four buckets;
/// stores must always pass a scope so chat and agent memories never cross.
class MemoryScope {
  const MemoryScope({
    required this.kind,
    required this.level,
    this.ownerId,
  });

  /// All-assistant chat memories.
  const MemoryScope.chatGlobal()
      : kind = MemoryKind.chat,
        level = MemoryLevel.global,
        ownerId = null;

  /// Chat memories private to a single assistant.
  const MemoryScope.chatAssistant(String assistantId)
      : kind = MemoryKind.chat,
        level = MemoryLevel.owner,
        ownerId = assistantId;

  final MemoryKind kind;
  final MemoryLevel level;
  final String? ownerId;
}
