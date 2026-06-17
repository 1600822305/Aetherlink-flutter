import 'package:aetherlink_flutter/features/chat/domain/agent_prompts_catalog.dart';

/// A preset system prompt — the port of the web `AgentPrompt`
/// (`src/shared/types/AgentPrompt.ts`). The catalog is built-in static data,
/// so this is an immutable value with a `const` constructor (`createdAt` /
/// `updatedAt` are user-prompt-only in the web and unused here).
class AgentPrompt {
  const AgentPrompt({
    required this.id,
    required this.name,
    required this.description,
    required this.content,
    required this.category,
    required this.tags,
    required this.emoji,
    this.isBuiltIn = true,
  });

  final String id;
  final String name;
  final String description;
  final String content;
  final String category;
  final List<String> tags;
  final String emoji;
  final bool isBuiltIn;
}

/// A preset category — the port of the web `AgentPromptCategory`.
class AgentPromptCategory {
  const AgentPromptCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.prompts,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final List<AgentPrompt> prompts;
}

/// All preset categories (the port of `getAgentPromptCategories`).
List<AgentPromptCategory> getAgentPromptCategories() => kAgentPromptCategories;

/// The category with [categoryId], or `null` (the port of
/// `getAgentPromptCategory`).
AgentPromptCategory? getAgentPromptCategory(String categoryId) {
  for (final category in kAgentPromptCategories) {
    if (category.id == categoryId) return category;
  }
  return null;
}

/// Every preset flattened across all categories (the port of
/// `getAllAgentPrompts`).
List<AgentPrompt> getAllAgentPrompts() => <AgentPrompt>[
  for (final category in kAgentPromptCategories) ...category.prompts,
];

/// The preset with [promptId], or `null` (the port of `getAgentPromptById`).
AgentPrompt? getAgentPromptById(String promptId) {
  for (final prompt in getAllAgentPrompts()) {
    if (prompt.id == promptId) return prompt;
  }
  return null;
}

/// Case-insensitive match over name / description / tags — the port of
/// `searchAgentPrompts`.
List<AgentPrompt> searchAgentPrompts(String query) {
  final lowercaseQuery = query.toLowerCase();
  return getAllAgentPrompts()
      .where(
        (prompt) =>
            prompt.name.toLowerCase().contains(lowercaseQuery) ||
            prompt.description.toLowerCase().contains(lowercaseQuery) ||
            prompt.tags.any(
              (tag) => tag.toLowerCase().contains(lowercaseQuery),
            ),
      )
      .toList();
}
