import 'package:freezed_annotation/freezed_annotation.dart';

part 'world_book_entry.freezed.dart';

/// 注入位置，取值与 SillyTavern `world_info_position` 一致（JSON 里存数字）。
///
/// 0 / 1 / 4 / 7 已生效；作者注释、示例消息先只保存（本应用还没有对应概念），
/// 见 [isImplemented]。
enum WorldBookInjectionPosition {
  /// 0 · 角色定义之前（本应用：系统提示词之前）。
  beforeSystemPrompt(0),

  /// 1 · 角色定义之后（本应用：系统提示词之后）。
  afterSystemPrompt(1),

  /// 2 · 作者注释顶部。
  authorNoteTop(2),

  /// 3 · 作者注释底部。
  authorNoteBottom(3),

  /// 4 · @深度：作为一条消息插在倒数第 [WorldBookEntry.depth] 处。
  atDepth(4),

  /// 5 · 示例消息之前。
  examplesBefore(5),

  /// 6 · 示例消息之后。
  examplesAfter(6),

  /// 7 · Outlet：不自动注入，在系统提示词里用 `{{outlet::名字}}` 取出。
  outlet(7);

  const WorldBookInjectionPosition(this.value);

  final int value;

  /// 引擎当前是否会注入这个位置。
  bool get isImplemented =>
      this == beforeSystemPrompt ||
      this == afterSystemPrompt ||
      this == atDepth ||
      this == outlet;

  static WorldBookInjectionPosition fromJson(Object? raw) {
    final v = raw is num ? raw.toInt() : int.tryParse('$raw');
    for (final p in values) {
      if (p.value == v) return p;
    }
    return beforeSystemPrompt;
  }
}

/// @深度注入的消息角色，取值与 ST `extension_prompt_roles` 一致。
enum WorldBookInjectionRole {
  system(0),
  user(1),
  assistant(2);

  const WorldBookInjectionRole(this.value);

  final int value;

  static WorldBookInjectionRole fromJson(Object? raw) {
    final v = raw is num ? raw.toInt() : int.tryParse('$raw');
    for (final r in values) {
      if (r.value == v) return r;
    }
    return system;
  }
}

/// 次级关键词的组合逻辑，取值与 ST `world_info_logic` 一致。
enum WorldBookSecondaryLogic {
  /// 0 · 主关键词命中，且任一次级关键词命中。
  andAny(0),

  /// 1 · 主关键词命中，且次级关键词**没有全部**命中。
  notAll(1),

  /// 2 · 主关键词命中，且次级关键词**一个都没**命中。
  notAny(2),

  /// 3 · 主关键词命中，且次级关键词**全部**命中。
  andAll(3);

  const WorldBookSecondaryLogic(this.value);

  final int value;

  static WorldBookSecondaryLogic fromJson(Object? raw) {
    final v = raw is num ? raw.toInt() : int.tryParse('$raw');
    for (final l in values) {
      if (l.value == v) return l;
    }
    return andAny;
  }
}

/// 一个世界书条目，字段与 SillyTavern `newWorldInfoEntryDefinition` 一一对应
/// （JSON 键名即 ST 键名，默认值相同）。可空字段 `null` = 跟随全局设置。
///
/// 本应用不认识的键原样放进 [extra]，[toJson] 时写回，保证与 ST 往返无损。
/// 列表顺序即编辑器显示顺序（写出为 `displayIndex`）；注入顺序只看 [order]。
@freezed
abstract class WorldBookEntry with _$WorldBookEntry {
  const factory WorldBookEntry({
    /// ST `uid`。本应用新建的条目用数字字符串；导入时原样转成字符串。
    required String id,

    /// ST `comment`：标题 / 备注，不参与匹配。
    @Default('') String name,

    /// ST `!disable`。
    @Default(true) bool enabled,
    @Default('') String content,

    /// ST `key`：主关键词。写成 `/pattern/flags` 的按正则匹配。
    @Default(<String>[]) List<String> keywords,

    /// ST `keysecondary`。
    @Default(<String>[]) List<String> secondaryKeywords,

    /// ST `selective`：是否启用次级关键词。
    @Default(true) bool selective,
    @Default(WorldBookSecondaryLogic.andAny)
    WorldBookSecondaryLogic secondaryLogic,

    /// ST `constant`：常驻。
    @Default(false) bool constant,
    @Default(false) bool vectorized,
    @Default(false) bool addMemo,

    /// ST `order`：越大越靠近提示词末尾。
    @Default(100) int order,
    @Default(WorldBookInjectionPosition.beforeSystemPrompt)
    WorldBookInjectionPosition position,

    /// ST `depth`：仅 [WorldBookInjectionPosition.atDepth] 有效。
    @Default(4) int depth,

    /// ST `role`：仅 [WorldBookInjectionPosition.atDepth] 有效。
    @Default(WorldBookInjectionRole.system) WorldBookInjectionRole role,

    /// ST `outletName`：仅 [WorldBookInjectionPosition.outlet] 有效。
    @Default('') String outletName,
    @Default(100) int probability,
    @Default(true) bool useProbability,

    /// ST `group`：逗号分隔，可同时属于多个包含组（见 [groups]）。
    @Default('') String group,
    @Default(false) bool groupOverride,
    @Default(100) int groupWeight,
    bool? useGroupScoring,
    int? scanDepth,
    bool? caseSensitive,
    bool? matchWholeWords,
    @Default(false) bool excludeRecursion,
    @Default(false) bool preventRecursion,

    /// ST `delayUntilRecursion`：0 = 关闭；ST 的 `true` 读作 1（第一层递归）。
    @Default(0) int delayUntilRecursion,
    @Default(false) bool matchPersonaDescription,
    @Default(false) bool matchCharacterDescription,
    @Default(false) bool matchCharacterPersonality,
    @Default(false) bool matchCharacterDepthPrompt,
    @Default(false) bool matchScenario,
    @Default(false) bool matchCreatorNotes,
    int? sticky,
    int? cooldown,
    int? delay,
    @Default(false) bool ignoreBudget,
    @Default('') String automationId,

    /// ST `triggers`：限定生成类型；空 = 所有类型。
    @Default(<String>[]) List<String> triggers,

    /// ST `characterFilter`：`{isExclude, names[], tags[]}`，原样保存。
    Map<String, dynamic>? characterFilter,

    /// 本应用不认识的键，原样保留。
    @Default(<String, dynamic>{}) Map<String, dynamic> extra,
  }) = _WorldBookEntry;

  const WorldBookEntry._();

  /// ST `MAX_SCAN_DEPTH`。
  static const int kMaxScanDepth = 1000;

  /// 编辑器里深度 / 计时器 / 顺序的输入上限（ST 本身不设上限）。
  static const int kMaxNumber = 10000;

  /// [group] 拆成组名列表。
  List<String> get groups => [
    for (final g in group.split(','))
      if (g.trim().isNotEmpty) g.trim(),
  ];

  /// 本应用识别并在 [toJson] 中写出的 ST 键（其余进 [extra]）。
  static const Set<String> knownKeys = {
    'uid',
    'key',
    'keysecondary',
    'comment',
    'content',
    'constant',
    'vectorized',
    'selective',
    'selectiveLogic',
    'addMemo',
    'order',
    'position',
    'disable',
    'excludeRecursion',
    'preventRecursion',
    'delayUntilRecursion',
    'probability',
    'useProbability',
    'depth',
    'outletName',
    'group',
    'groupOverride',
    'groupWeight',
    'scanDepth',
    'caseSensitive',
    'matchWholeWords',
    'useGroupScoring',
    'automationId',
    'role',
    'sticky',
    'cooldown',
    'delay',
    'ignoreBudget',
    'triggers',
    'characterFilter',
    'matchPersonaDescription',
    'matchCharacterDescription',
    'matchCharacterPersonality',
    'matchCharacterDepthPrompt',
    'matchScenario',
    'matchCreatorNotes',
    'displayIndex',
  };

  /// ST 条目 JSON。[displayIndex] 由书在写出时按列表顺序填入。
  Map<String, dynamic> toJson({int? displayIndex}) => <String, dynamic>{
    ...extra,
    'uid': int.tryParse(id) ?? id,
    'key': keywords,
    'keysecondary': secondaryKeywords,
    'comment': name,
    'content': content,
    'constant': constant,
    'vectorized': vectorized,
    'selective': selective,
    'selectiveLogic': secondaryLogic.value,
    'addMemo': addMemo,
    'order': order,
    'position': position.value,
    'disable': !enabled,
    'excludeRecursion': excludeRecursion,
    'preventRecursion': preventRecursion,
    'delayUntilRecursion': delayUntilRecursion,
    'probability': probability,
    'useProbability': useProbability,
    'depth': depth,
    'outletName': outletName,
    'group': group,
    'groupOverride': groupOverride,
    'groupWeight': groupWeight,
    'scanDepth': scanDepth,
    'caseSensitive': caseSensitive,
    'matchWholeWords': matchWholeWords,
    'useGroupScoring': useGroupScoring,
    'automationId': automationId,
    'role': role.value,
    'sticky': sticky,
    'cooldown': cooldown,
    'delay': delay,
    'ignoreBudget': ignoreBudget,
    'triggers': triggers,
    if (characterFilter != null) 'characterFilter': characterFilter,
    'matchPersonaDescription': matchPersonaDescription,
    'matchCharacterDescription': matchCharacterDescription,
    'matchCharacterPersonality': matchCharacterPersonality,
    'matchCharacterDepthPrompt': matchCharacterDepthPrompt,
    'matchScenario': matchScenario,
    'matchCreatorNotes': matchCreatorNotes,
    'displayIndex': ?displayIndex,
  };

  /// 读 ST 条目 JSON；缺失字段取 ST 默认值，类型不对的字段同样回退默认值，
  /// 从不抛异常。[fallbackId] 用于没有 `uid` 的条目（取其在 `entries` 中的键）。
  static WorldBookEntry fromJson(
    Map<String, dynamic> json, {
    String fallbackId = '',
  }) {
    final rawUid = json['uid'];
    return WorldBookEntry(
      id: rawUid == null ? fallbackId : '$rawUid',
      name: _str(json['comment']),
      enabled: !_bool(json['disable'], false),
      content: _str(json['content']),
      keywords: _strings(json['key']),
      secondaryKeywords: _strings(json['keysecondary']),
      selective: _bool(json['selective'], true),
      secondaryLogic: WorldBookSecondaryLogic.fromJson(json['selectiveLogic']),
      constant: _bool(json['constant'], false),
      vectorized: _bool(json['vectorized'], false),
      addMemo: _bool(json['addMemo'], false),
      order: _int(json['order']) ?? 100,
      position: WorldBookInjectionPosition.fromJson(json['position']),
      depth: _int(json['depth']) ?? 4,
      role: WorldBookInjectionRole.fromJson(json['role']),
      outletName: _str(json['outletName']),
      probability: _int(json['probability']) ?? 100,
      useProbability: _bool(json['useProbability'], true),
      group: _str(json['group']),
      groupOverride: _bool(json['groupOverride'], false),
      groupWeight: _int(json['groupWeight']) ?? 100,
      useGroupScoring: _boolOrNull(json['useGroupScoring']),
      scanDepth: _int(json['scanDepth']),
      caseSensitive: _boolOrNull(json['caseSensitive']),
      matchWholeWords: _boolOrNull(json['matchWholeWords']),
      excludeRecursion: _bool(json['excludeRecursion'], false),
      preventRecursion: _bool(json['preventRecursion'], false),
      delayUntilRecursion: switch (json['delayUntilRecursion']) {
        true => 1,
        final num n when n > 0 => n.toInt(),
        _ => 0,
      },
      matchPersonaDescription: _bool(json['matchPersonaDescription'], false),
      matchCharacterDescription: _bool(
        json['matchCharacterDescription'],
        false,
      ),
      matchCharacterPersonality: _bool(
        json['matchCharacterPersonality'],
        false,
      ),
      matchCharacterDepthPrompt: _bool(
        json['matchCharacterDepthPrompt'],
        false,
      ),
      matchScenario: _bool(json['matchScenario'], false),
      matchCreatorNotes: _bool(json['matchCreatorNotes'], false),
      sticky: _int(json['sticky']),
      cooldown: _int(json['cooldown']),
      delay: _int(json['delay']),
      ignoreBudget: _bool(json['ignoreBudget'], false),
      automationId: _str(json['automationId']),
      triggers: _strings(json['triggers']),
      characterFilter: json['characterFilter'] is Map<dynamic, dynamic>
          ? (json['characterFilter'] as Map<dynamic, dynamic>)
                .cast<String, dynamic>()
          : null,
      extra: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!knownKeys.contains(key)) key: value,
      },
    );
  }

  /// 列表、注入记录里显示的标题。[name]（ST `comment`）为空时依次用：内容里的
  /// `<Name>…</Name>` / `<name>`、第一个主关键词、内容第一行（截到 30 字）；
  /// 都没有时为空串。只用于显示，不写回 [name]。
  String get displayTitle {
    final own = name.trim();
    if (own.isNotEmpty) return own;
    final tag = RegExp(
      r'<name>\s*([^<\n]{1,60}?)\s*</name>',
      caseSensitive: false,
    ).firstMatch(content);
    if (tag != null) return tag.group(1)!.trim();
    for (final k in keywords) {
      if (k.trim().isNotEmpty) return k.trim();
    }
    for (final line in content.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('@@')) continue;
      final runes = t.runes.toList();
      return runes.length > 30 ? '${String.fromCharCodes(runes.take(30))}…' : t;
    }
    return '';
  }

  /// [name] 为空、[displayTitle] 是推断出来的。
  bool get hasInferredTitle => name.trim().isEmpty && displayTitle.isNotEmpty;

  static String _str(Object? v) => v is String ? v : '';

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  static bool? _boolOrNull(Object? v) => v is bool ? v : null;

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static List<String> _strings(Object? v) => v is List<dynamic>
      ? [
          for (final e in v)
            if (e is String && e.trim().isNotEmpty) e,
        ]
      : const <String>[];
}
