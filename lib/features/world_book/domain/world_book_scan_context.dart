import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// 本次评估的「角色」，用于 ST 的角色筛选（`characterFilter`）。
/// 本应用里角色 = 当前助手：[names] 里放助手名与 id（ST 用角色文件名），
/// [tags] 为助手标签；null 表示没有标签信息（ST 此时跳过标签筛选）。
class WorldBookCharacter {
  const WorldBookCharacter({this.names = const <String>[], this.tags});

  final List<String> names;
  final List<String>? tags;
}

/// ST `WIGlobalScanData`：条目勾选「额外匹配源」时追加到扫描文本的非聊天内容。
/// 本应用的对应关系见 `docs/世界书-SillyTavern对齐调研.md`；没有对应的为空串。
class WorldBookScanSources {
  const WorldBookScanSources({
    this.personaDescription = '',
    this.characterDescription = '',
    this.characterPersonality = '',
    this.characterDepthPrompt = '',
    this.scenario = '',
    this.creatorNotes = '',
  });

  static const WorldBookScanSources none = WorldBookScanSources();

  final String personaDescription;
  final String characterDescription;
  final String characterPersonality;
  final String characterDepthPrompt;
  final String scenario;
  final String creatorNotes;

  /// [entry] 勾选的、内容非空的来源，按 ST `WorldInfoBuffer.get` 的顺序。
  List<String> forEntry(WorldBookEntry entry) => [
    if (entry.matchPersonaDescription && personaDescription.isNotEmpty)
      personaDescription,
    if (entry.matchCharacterDescription && characterDescription.isNotEmpty)
      characterDescription,
    if (entry.matchCharacterPersonality && characterPersonality.isNotEmpty)
      characterPersonality,
    if (entry.matchCharacterDepthPrompt && characterDepthPrompt.isNotEmpty)
      characterDepthPrompt,
    if (entry.matchScenario && scenario.isNotEmpty) scenario,
    if (entry.matchCreatorNotes && creatorNotes.isNotEmpty) creatorNotes,
  ];
}

/// ST 的生成类型（`triggers` 取值）。
abstract final class WorldBookTrigger {
  static const String normal = 'normal';
  static const String continueGeneration = 'continue';
  static const String impersonate = 'impersonate';
  static const String swipe = 'swipe';
  static const String regenerate = 'regenerate';
  static const String quiet = 'quiet';
}

/// ST `checkWorldInfo` 的生成类型筛选：条目限定了生成类型、且不含 [trigger]
/// 时不参与。
bool worldBookTriggerAllows(WorldBookEntry entry, String trigger) =>
    entry.triggers.isEmpty || entry.triggers.contains(trigger);

/// ST 的角色筛选：按名字、再按标签；`isExclude` 时反过来。[character] 为
/// null（不知道当前角色）时不筛选。
bool worldBookCharacterAllows(
  WorldBookEntry entry,
  WorldBookCharacter? character,
) {
  final filter = entry.characterFilter;
  if (filter == null || character == null) return true;
  final exclude = filter['isExclude'] == true;
  List<String> list(Object? v) => v is List<dynamic>
      ? [
          for (final x in v)
            if ('$x'.trim().isNotEmpty) '$x'.trim(),
        ]
      : const <String>[];
  final names = list(filter['names']);
  if (names.isNotEmpty) {
    final included = character.names.any(
      (n) => names.any((f) => f.toLowerCase() == n.trim().toLowerCase()),
    );
    if (exclude ? included : !included) return false;
  }
  final tags = list(filter['tags']);
  final own = character.tags;
  if (tags.isNotEmpty && own != null) {
    final included = own.any(
      (t) => tags.any((f) => f.toLowerCase() == t.trim().toLowerCase()),
    );
    if (exclude ? included : !included) return false;
  }
  return true;
}
