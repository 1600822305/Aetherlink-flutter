import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

/// Pure helpers for the 建议模型 (chat follow-up suggestions) feature: building
/// the conversation context to feed the suggestion model and robustly parsing
/// its free-form text reply into a clean list of suggestions.
///
/// Stateless and Ref-free (mirrors kelivo's `ChatSuggestionService`) so it can
/// be unit-tested in isolation; the generation orchestration lives in
/// `ChatController` next to title generation.
class SuggestionService {
  const SuggestionService._();

  /// Maximum number of suggestions to surface.
  static const int maxSuggestionCount = 3;

  /// Suggestions longer than this many characters are dropped (a model that
  /// ignored the "be concise" instruction shouldn't produce a giant bubble).
  static const int maxSuggestionChars = 300;

  /// Builds the conversation text handed to the suggestion model: the most
  /// recent [maxMessages] non-empty user/assistant turns, capped at [maxChars]
  /// (keeping the tail), formatted as `User: …` / `Assistant: …` lines.
  static String buildContent(
    List<ChatMessageView> messages, {
    int maxMessages = 8,
    int maxChars = 4000,
  }) {
    final recent = <ChatMessageView>[
      for (final m in messages)
        if ((m.role == MessageRole.user || m.role == MessageRole.assistant) &&
            m.text.trim().isNotEmpty)
          m,
    ];
    final selected = recent.length > maxMessages
        ? recent.sublist(recent.length - maxMessages)
        : recent;
    final joined = selected
        .map((m) {
          final role = m.role == MessageRole.user ? 'User' : 'Assistant';
          return '$role: ${m.text.trim()}';
        })
        .join('\n\n');
    if (joined.length <= maxChars) return joined;
    return joined.substring(joined.length - maxChars);
  }

  /// Parses the model's raw reply into at most [maxCount] de-duplicated
  /// suggestions. Splits on newlines and sentence terminators, strips list
  /// markers (`-`, `*`, `•`, `1.`) and surrounding quotes, drops empties and
  /// over-long lines.
  static List<String> parseSuggestions(
    String raw, {
    int maxCount = maxSuggestionCount,
    int maxChars = maxSuggestionChars,
  }) {
    final seen = <String>{};
    final suggestions = <String>[];
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .expand((line) => line.split(RegExp(r'(?<=[。！？!?])\s+')));

    for (final line in lines) {
      var text = line.trim();
      if (text.isEmpty) continue;
      text = text
          .replaceFirst(RegExp(r'^\s*[-*•]\s*'), '')
          .replaceFirst(RegExp(r'^\s*\d+[.)、]\s*'), '')
          .trim();
      if ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith("'") && text.endsWith("'")) ||
          (text.startsWith('“') && text.endsWith('”'))) {
        text = text.substring(1, text.length - 1).trim();
      }
      if (text.isEmpty || text.length > maxChars) continue;
      if (!seen.add(text)) continue;
      suggestions.add(text);
      if (suggestions.length >= maxCount) break;
    }
    return suggestions;
  }
}
