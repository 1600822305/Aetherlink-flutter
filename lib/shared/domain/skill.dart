/// Skills domain model — the port of the web `Skill`
/// (`src/shared/types/Skill.ts`). A skill is a lightweight, structured
/// instruction pack (a SKILL.md body) that gives the assistant on-demand
/// expertise. Freezed value type with `toJson`/`fromJson` so the
/// [SkillsController] can persist the whole library as a single JSON blob; the
/// `const` factory keeps the built-in catalog ([kBuiltinSkills]) `const`.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill.freezed.dart';
part 'skill.g.dart';

/// Where a skill comes from. Mirrors the web `SkillSource`; the JSON values
/// match the source verbatim so configs round-trip with the web app.
enum SkillSource {
  @JsonValue('builtin')
  builtin,
  @JsonValue('user')
  user,
  @JsonValue('community')
  community,
}

/// A single skill. Mirrors the web `Skill` interface field-for-field.
@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String id,
    required String name,
    required String description,
    required SkillSource source,
    String? emoji,
    @Default(<String>[]) List<String> tags,

    /// SKILL.md body (Markdown instructions). Consumed by the editor, not the
    /// list page.
    @Default('') String content,

    /// Trigger phrase examples, e.g. `['审查代码', 'review PR']`.
    @Default(<String>[]) List<String> triggerPhrases,

    /// Associated MCP server id.
    String? mcpServerId,

    /// Recommended model / temperature.
    String? modelOverride,
    double? temperatureOverride,
    String? version,
    String? author,
    @Default(false) bool enabled,

    /// Usage statistics.
    int? usageCount,
    String? lastUsedAt,
    String? createdAt,
    String? updatedAt,
  }) = _Skill;

  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);
}
