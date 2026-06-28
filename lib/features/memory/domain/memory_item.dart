import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_item.freezed.dart';
part 'memory_item.g.dart';

/// 记忆形态 — the hard-isolation axis. Chat memories and agent memories never
/// mix at recall time. Agent memory is reserved for the future agent chat
/// surface; only [MemoryKind.chat] is produced today.
enum MemoryKind {
  @JsonValue('chat')
  chat,
  @JsonValue('agent')
  agent,
}

/// 归属级别 — global memories apply to every assistant; owner memories are
/// private to a single assistant (the `ownerId`).
enum MemoryLevel {
  @JsonValue('global')
  global,
  @JsonValue('owner')
  owner,
}

/// 记忆类型 — episodic memories are raw, time-stamped events; semantic memories
/// are de-contextualised facts/preferences. Manual entries default to
/// [MemoryType.semantic].
enum MemoryType {
  @JsonValue('episodic')
  episodic,
  @JsonValue('semantic')
  semantic,
}

/// How the memory was written: hand-authored by the user vs. auto-extracted.
enum MemorySource {
  @JsonValue('manual')
  manual,
  @JsonValue('auto')
  auto,
}

/// A single long-term memory record (the unit persisted in the `memories`
/// table). [content] is the human-readable fact/event; [importance] is the
/// near-non-decaying storage strength (0..1); [accessCount] / [lastAccessedAt]
/// back the activation-based retrieval that will land in a later phase.
///
/// `embedding` is intentionally not modelled yet — this slice ships manual CRUD
/// and keyword search only; the vector column is added when retrieval lands.
@freezed
abstract class MemoryItem with _$MemoryItem {
  const factory MemoryItem({
    required String id,
    required String content,
    @Default(MemoryKind.chat) MemoryKind kind,
    @Default(MemoryLevel.global) MemoryLevel level,

    /// The owning assistant id when [level] is [MemoryLevel.owner]; null for
    /// global memories.
    String? ownerId,
    @Default(MemoryType.semantic) MemoryType type,
    String? category,
    @Default(0.5) double importance,
    @Default(MemorySource.manual) MemorySource source,
    @Default(0) int accessCount,

    /// Epoch milliseconds.
    @Default(0) int createdAt,
    @Default(0) int updatedAt,
    int? lastAccessedAt,
  }) = _MemoryItem;

  factory MemoryItem.fromJson(Map<String, dynamic> json) =>
      _$MemoryItemFromJson(json);
}

/// Stable string wire values for the scope enums, matching the `@JsonValue`
/// annotations. Used for the promoted scalar columns in the `memories` table.
extension MemoryKindWire on MemoryKind {
  String get wire => this == MemoryKind.chat ? 'chat' : 'agent';

  static MemoryKind parse(String value) =>
      value == 'agent' ? MemoryKind.agent : MemoryKind.chat;
}

extension MemoryLevelWire on MemoryLevel {
  String get wire => this == MemoryLevel.global ? 'global' : 'owner';

  static MemoryLevel parse(String value) =>
      value == 'owner' ? MemoryLevel.owner : MemoryLevel.global;
}
