/// Skills domain model — the port of the web `Skill`
/// (`src/shared/types/Skill.ts`). A skill is a lightweight, structured
/// instruction pack (a SKILL.md body) that gives the assistant on-demand
/// expertise. Pure Dart value type with a `const` constructor so the built-in
/// catalog ([kBuiltinSkills]) can be `const` static data.
///
/// UI-only milestone: enable/CRUD/import-export/binding aren't wired yet, so
/// the persistence-only fields (`usageCount`, `lastUsedAt`, timestamps) are
/// carried for parity but not yet mutated.
library;

/// Where a skill comes from. Mirrors the web `SkillSource`; the string values
/// match the source verbatim so configs round-trip with the web app.
enum SkillSource { builtin, user, community }

/// A single skill. Mirrors the web `Skill` interface field-for-field.
class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    this.emoji,
    this.tags = const <String>[],
    this.content = '',
    this.triggerPhrases = const <String>[],
    this.mcpServerId,
    this.modelOverride,
    this.temperatureOverride,
    this.version,
    this.author,
    this.enabled = false,
    this.usageCount,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final SkillSource source;

  final String? emoji;
  final List<String> tags;

  /// SKILL.md body (Markdown instructions). Consumed by the editor, not the
  /// list page.
  final String content;

  /// Trigger phrase examples, e.g. `['审查代码', 'review PR']`.
  final List<String> triggerPhrases;

  /// Associated MCP server id.
  final String? mcpServerId;

  /// Recommended model / temperature.
  final String? modelOverride;
  final double? temperatureOverride;

  final String? version;
  final String? author;
  final bool enabled;

  /// Usage statistics.
  final int? usageCount;
  final String? lastUsedAt;

  final String? createdAt;
  final String? updatedAt;
}
