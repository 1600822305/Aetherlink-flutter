/// Skill → system-prompt assembly, the port of the web
/// `SkillPromptBuilder` (`src/shared/services/skills/SkillPromptBuilder.ts`).
///
/// Cascade style: every enabled, bound skill is injected as a compact plain-text
/// list (`- name: description`, ~50 chars each) at the very top of the system
/// prompt — full bodies are read on demand via the `read_skill` tool (a later
/// milestone), so there's no "activation" concept.
library;

import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// Builds the compact skills list injected into the system prompt (port of
/// `SkillPromptBuilder.buildSkillsSummary`). Empty when there are no skills.
String buildSkillsSummary(List<Skill> skills) {
  if (skills.isEmpty) return '';
  final entries = skills.map((s) => '- ${s.name}: ${s.description}').join('\n');
  return [
    'If a skill matches the user request, call read_skill with the skill name before using any other tool.',
    '',
    'Available skills:',
    entries,
  ].join('\n');
}

/// Assembles the system prompt from the assistant prompt, the bound enabled
/// skills and the optional topic prompt (port of
/// `SkillPromptBuilder.assembleSystemPrompt`). Skills go first (highest
/// priority), then the assistant prompt, then the topic prompt.
String assembleSkillSystemPrompt({
  required String assistantPrompt,
  required List<Skill> enabledSkills,
  String topicPrompt = '',
}) {
  var systemPrompt = '';
  if (enabledSkills.isNotEmpty) {
    systemPrompt = '${buildSkillsSummary(enabledSkills)}\n\n';
  }
  systemPrompt += assistantPrompt;
  if (topicPrompt.trim().isNotEmpty) {
    systemPrompt += '\n\n$topicPrompt';
  }
  return systemPrompt;
}
