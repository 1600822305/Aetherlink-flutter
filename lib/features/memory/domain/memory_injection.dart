import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// Builds the `<user_memories>` block appended to the system prompt so the model
/// can use the user's long-term memories this turn.
///
/// [global] are the chat-global memories (shared across assistants); [assistant]
/// are the current assistant's private memories. Both are injected in full (the
/// 全量注入 path) — vector / keyword retrieval (the other [MemoryInjectionMode]s)
/// is not wired yet, so any non-off mode falls back to a full dump for now.
///
/// Returns null when there is nothing to inject so the caller can leave the
/// prompt untouched.
String? buildMemoryPromptSection({
  required List<MemoryItem> global,
  required List<MemoryItem> assistant,
}) {
  final lines = <String>[
    for (final m in global)
      if (m.content.trim().isNotEmpty) m.content.trim(),
    for (final m in assistant)
      if (m.content.trim().isNotEmpty) m.content.trim(),
  ];
  if (lines.isEmpty) return null;

  final buffer = StringBuffer()
    ..writeln('<user_memories>')
    ..writeln('以下是关于用户的长期记忆，请在回答时自然地参考；若与本轮对话明显冲突，以本轮对话为准。')
    ..writeln();
  for (final line in lines) {
    buffer.writeln('- $line');
  }
  buffer.write('</user_memories>');
  return buffer.toString();
}
