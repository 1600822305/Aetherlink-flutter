import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/shared/config/builtin_skills.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

part 'skills_controller.g.dart';

/// Storage key for the skill library (port of the web `dexieStorage.skills`
/// table). Persisted as a single JSON list in the Drift key/value store,
/// matching the web `Skill` shape so libraries round-trip.
const String kSkillsSettingKey = 'skills';

/// Upper bound on simultaneously-enabled skills (port of the web
/// `MAX_ENABLED_SKILLS`).
const int kMaxEnabledSkills = 20;

/// Outcome of a JSON import: how many skills were added plus how many entries
/// were skipped (mirrors the web `importSkills` result).
typedef SkillImportResult = ({int imported, int skipped});

/// The skill library, persisted through the app-level key/value store as a JSON
/// list — the port of the web `SkillManager` (CRUD / toggle / built-in
/// initialization / import-export / usage stats). The built-in catalog
/// ([kBuiltinSkills]) is seeded on first run and any newly-shipped built-in is
/// merged in on later builds; built-in skills can be disabled but not deleted.
///
/// Assistant binding lives in the chat-owned `Assistants` notifier (a skill is
/// bound by storing its id on `assistant.skillIds`); this controller only owns
/// the skills themselves.
@Riverpod(keepAlive: true)
class Skills extends _$Skills {
  @override
  Future<List<Skill>> build() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kSkillsSettingKey);
    final stored = _decode(raw);

    // Seed / merge built-ins: any catalog entry whose id isn't stored yet is
    // added (port of `SkillManager.initializeBuiltinSkills`).
    final ids = stored.map((s) => s.id).toSet();
    final missing = kBuiltinSkills.where((b) => !ids.contains(b.id)).toList();
    if (missing.isEmpty) return stored;

    final merged = <Skill>[...stored, ...missing];
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kSkillsSettingKey, _encode(merged));
    return merged;
  }

  List<Skill> get _current => state.asData?.value ?? const <Skill>[];

  /// Creates a new user skill (port of `SkillManager.createSkill`), enabled by
  /// default, and returns it.
  Future<Skill> create({
    String? name,
    String? description,
    String? emoji,
    List<String>? tags,
    String content = '',
    List<String>? triggerPhrases,
    String? mcpServerId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final skill = Skill(
      id: generateId('skill'),
      name: (name == null || name.trim().isEmpty) ? '新技能' : name.trim(),
      description: description?.trim() ?? '',
      emoji: (emoji == null || emoji.trim().isEmpty) ? '🔧' : emoji.trim(),
      tags: tags ?? const <String>[],
      content: content,
      triggerPhrases: triggerPhrases ?? const <String>[],
      mcpServerId: mcpServerId,
      source: SkillSource.user,
      version: '1.0.0',
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );
    await _commit(<Skill>[..._current, skill]);
    return skill;
  }

  /// Upserts [skill], stamping `updatedAt` (port of `SkillManager.saveSkill`).
  /// Replaces the entry sharing [skill.id], or appends when it's new.
  Future<void> save(Skill skill) async {
    final stamped = skill.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final exists = _current.any((s) => s.id == stamped.id);
    final next = exists
        ? _current.map((s) => s.id == stamped.id ? stamped : s).toList()
        : <Skill>[..._current, stamped];
    await _commit(next);
  }

  /// Removes the skill with [id] (port of `SkillManager.deleteSkill`). Built-in
  /// skills can't be deleted, so they're disabled instead.
  Future<void> remove(String id) async {
    final skill = _current.where((s) => s.id == id).firstOrNull;
    if (skill == null) return;
    if (skill.source == SkillSource.builtin) {
      await toggle(id, enabled: false);
      return;
    }
    await _commit(_current.where((s) => s.id != id).toList());
  }

  /// Flips a skill's `enabled` (port of `SkillManager.toggleSkill`). Returns
  /// `false` without changing anything when enabling would exceed
  /// [kMaxEnabledSkills].
  Future<bool> toggle(String id, {required bool enabled}) async {
    if (enabled) {
      final enabledCount = _current.where((s) => s.enabled).length;
      final already = _current.any((s) => s.id == id && s.enabled);
      if (!already && enabledCount >= kMaxEnabledSkills) return false;
    }
    final next = _current
        .map(
          (s) => s.id == id
              ? s.copyWith(
                  enabled: enabled,
                  updatedAt: DateTime.now().toUtc().toIso8601String(),
                )
              : s,
        )
        .toList();
    await _commit(next);
    return true;
  }

  /// Builds the JSON export document (port of `SkillManager.exportSkills`).
  /// Exports everything when [skillIds] is null/empty, otherwise the listed
  /// skills.
  Map<String, dynamic> exportToJson([List<String>? skillIds]) {
    final skills = (skillIds == null || skillIds.isEmpty)
        ? _current
        : _current.where((s) => skillIds.contains(s.id)).toList();
    return <String, dynamic>{
      'version': '1.0',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'skills': skills.map((s) => s.toJson()).toList(),
    };
  }

  /// Imports skills from an export document (port of `SkillManager.importSkills`).
  /// Every imported skill is forced to `source: user` with a fresh id to avoid
  /// collisions; malformed entries are skipped, not fatal. Imported skills stay
  /// enabled only while the [kMaxEnabledSkills] budget lasts — the rest come in
  /// disabled, matching what the toggle enforces.
  Future<SkillImportResult> importFromJson(String raw) async {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic> ? decoded['skills'] : decoded;
    if (list is! List) {
      throw const FormatException('JSON 格式错误：缺少 skills 字段');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final added = <Skill>[];
    var skipped = 0;
    var enabledBudget =
        kMaxEnabledSkills - _current.where((s) => s.enabled).length;
    for (final entry in list) {
      try {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('技能必须是对象');
        }
        final parsed = Skill.fromJson(entry);
        added.add(
          parsed.copyWith(
            id: generateId('skill'),
            source: SkillSource.user,
            enabled: enabledBudget-- > 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } catch (_) {
        skipped++;
      }
    }

    if (added.isNotEmpty) {
      await _commit(<Skill>[..._current, ...added]);
    }
    return (imported: added.length, skipped: skipped);
  }

  /// Increments a skill's usage counter and stamps `lastUsedAt` (port of
  /// `SkillManager.recordSkillUsage`).
  Future<void> recordUsage(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final next = _current
        .map(
          (s) => s.id == id
              ? s.copyWith(
                  usageCount: (s.usageCount ?? 0) + 1,
                  lastUsedAt: now,
                  updatedAt: now,
                )
              : s,
        )
        .toList();
    await _commit(next);
  }

  /// Re-seeds built-in skills whose shipped `version` differs from the stored
  /// copy, preserving the user's enabled state (port of
  /// `SkillManager.upgradeBuiltinSkills`). Returns how many were upgraded.
  Future<int> upgradeBuiltins() async {
    var upgraded = 0;
    final now = DateTime.now().toUtc().toIso8601String();
    final next = _current.map((existing) {
      if (existing.source != SkillSource.builtin) return existing;
      final latest = kBuiltinSkills
          .where((b) => b.id == existing.id)
          .firstOrNull;
      if (latest == null || latest.version == existing.version) return existing;
      upgraded++;
      return latest.copyWith(
        enabled: existing.enabled,
        usageCount: existing.usageCount,
        lastUsedAt: existing.lastUsedAt,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    }).toList();
    if (upgraded > 0) await _commit(next);
    return upgraded;
  }

  /// Publishes [next] to listeners synchronously, *then* persists it: rapid
  /// consecutive mutations (e.g. flipping two switches back to back) each
  /// compute from the freshest list instead of racing the storage write and
  /// losing the earlier change.
  Future<void> _commit(List<Skill> next) async {
    state = AsyncData<List<Skill>>(next);
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kSkillsSettingKey, _encode(next));
  }

  static String _encode(List<Skill> skills) =>
      jsonEncode(skills.map((s) => s.toJson()).toList());

  static List<Skill> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <Skill>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <Skill>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Skill.fromJson)
        .toList();
  }
}
