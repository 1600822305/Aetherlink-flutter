import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_settings.freezed.dart';
part 'memory_settings.g.dart';

/// How retrieved memories are provided to the model each turn.
///
/// The user picks one in the 记忆设置 sub-page (the original web kept this as a
/// single `memoryInjectionMode` setting). Defaults to [auto] — global memories
/// are injected in full while per-assistant memories go through vector top-k,
/// auto-downgrading to a full dump for small collections.
enum MemoryInjectionMode {
  /// Global in full + per-assistant vector top-k, auto full-dump when small.
  auto,

  /// Inject every in-scope memory into the prompt.
  full,

  /// Vector top-k only.
  semantic,

  /// Keyword / text match only (no embedding call).
  keyword,

  /// Expose a `search_memory` tool and let the model fetch on demand.
  tool,

  /// Disable injection for this turn.
  off,
}

/// The 聊天记忆 (chat memory) configuration backing the 记忆 settings pages.
///
/// [enabled] is the master switch — when off nothing is recorded or injected.
/// [autoWritePrivate] / [autoWriteGlobal] are the two independent auto-extract
/// toggles (private on by default, global opt-in) the user confirmed; both can
/// run, and the user can also move/mark a memory between 全局 ↔ 私有 by hand.
/// [injectionMode] plus [tokenBudget] / [topK] / [fullDumpThreshold] live on the
/// 记忆设置 sub-page and govern how memories are provided to the model.
///
/// Only the master + the two auto-write toggles are surfaced on the 记忆 home
/// page this milestone; the rest are persisted here for the sub-pages that land
/// alongside the memory store.
@freezed
abstract class MemorySettings with _$MemorySettings {
  const factory MemorySettings({
    @Default(false) bool enabled,
    @Default(true) bool autoWritePrivate,
    @Default(false) bool autoWriteGlobal,
    @Default(MemoryInjectionMode.auto) MemoryInjectionMode injectionMode,
    @Default(1500) int tokenBudget,
    @Default(5) int topK,
    @Default(30) int fullDumpThreshold,

    /// How many days a soft-deleted memory is kept before 整理记忆 (purge)
    /// permanently removes it. 0 → purge as soon as 整理记忆 runs.
    @Default(30) int retentionDays,

    /// When true, semantic top-k is ranked by the ACT-R activation score
    /// (cosine similarity dominant + recency/frequency/importance tie-breakers,
    /// with 保守遗忘衰减). When false, retrieval falls back to pure cosine.
    @Default(true) bool activationRanking,

    /// The `providerId:modelId` key of the embedding model used for semantic
    /// retrieval (null → not configured, semantic/auto fall back to keyword).
    String? embeddingModelKey,

    /// Epoch milliseconds of the last 整理记忆 (consolidation/Dream) run, or null
    /// if it has never run. Surfaced as 「最近整理」 on the 记忆 home page.
    int? lastConsolidatedAt,
  }) = _MemorySettings;

  factory MemorySettings.fromJson(Map<String, dynamic> json) =>
      _$MemorySettingsFromJson(json);
}
