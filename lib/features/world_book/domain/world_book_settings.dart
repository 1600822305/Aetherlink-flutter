/// 世界书全局设置，字段与默认值与 SillyTavern `world_info_*` 一致。
/// 条目上为 `null` 的扫描深度 / 区分大小写 / 全词匹配 / 组评分跟随这里。
///
/// 存在应用设置的 KV 里（键 [kWorldBookSettingsKey]），由世界书页的「全局设置」
/// 编辑。最少激活数与最大扫描次数互斥（同 ST），见 [copyWith] 的调用方。
/// 应用设置 KV 里保存全局设置的键。
const String kWorldBookSettingsKey = 'worldBookSettings';

class WorldBookSettings {
  const WorldBookSettings({
    this.scanDepth = 2,
    this.minActivations = 0,
    this.minActivationsDepthMax = 0,
    this.budgetPercent = 25,
    this.budgetCap = 0,
    this.includeNames = false,
    this.recursive = false,
    this.maxRecursionSteps = 0,
    this.caseSensitive = false,
    this.matchWholeWords = false,
    this.useGroupScoring = false,
    this.overflowAlert = false,
  });

  /// ST 的默认值。
  static const WorldBookSettings defaults = WorldBookSettings();

  /// `world_info_depth`：条目未设扫描深度时扫描最近多少条消息。
  final int scanDepth;

  /// `world_info_min_activations`：激活数不足时继续往前扫描；0 = 关闭。
  final int minActivations;

  /// `world_info_min_activations_depth_max`：补扫的最大深度；0 = 到聊天开头。
  final int minActivationsDepthMax;

  /// `world_info_budget`：预算占上下文的百分比。
  final int budgetPercent;

  /// `world_info_budget_cap`：预算上限（token）；0 = 不限。
  final int budgetCap;

  /// `world_info_include_names`：扫描文本里带「名字:」前缀。本应用默认关闭（ST
  /// 默认开）：助手名常常就是角色名，开着时以助手名为关键词的条目每轮都会触发。
  final bool includeNames;

  /// `world_info_recursive`：递归扫描。
  final bool recursive;

  /// `world_info_max_recursion_steps`：0 = 只受预算限制。
  final int maxRecursionSteps;

  final bool caseSensitive;
  final bool matchWholeWords;
  final bool useGroupScoring;

  /// `world_info_overflow_alert`：超出预算时提示。
  final bool overflowAlert;

  WorldBookSettings copyWith({
    int? scanDepth,
    int? minActivations,
    int? minActivationsDepthMax,
    int? budgetPercent,
    int? budgetCap,
    bool? includeNames,
    bool? recursive,
    int? maxRecursionSteps,
    bool? caseSensitive,
    bool? matchWholeWords,
    bool? useGroupScoring,
    bool? overflowAlert,
  }) => WorldBookSettings(
    scanDepth: scanDepth ?? this.scanDepth,
    minActivations: minActivations ?? this.minActivations,
    minActivationsDepthMax:
        minActivationsDepthMax ?? this.minActivationsDepthMax,
    budgetPercent: budgetPercent ?? this.budgetPercent,
    budgetCap: budgetCap ?? this.budgetCap,
    includeNames: includeNames ?? this.includeNames,
    recursive: recursive ?? this.recursive,
    maxRecursionSteps: maxRecursionSteps ?? this.maxRecursionSteps,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    matchWholeWords: matchWholeWords ?? this.matchWholeWords,
    useGroupScoring: useGroupScoring ?? this.useGroupScoring,
    overflowAlert: overflowAlert ?? this.overflowAlert,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'world_info_depth': scanDepth,
    'world_info_min_activations': minActivations,
    'world_info_min_activations_depth_max': minActivationsDepthMax,
    'world_info_budget': budgetPercent,
    'world_info_budget_cap': budgetCap,
    'world_info_include_names': includeNames,
    'world_info_recursive': recursive,
    'world_info_max_recursion_steps': maxRecursionSteps,
    'world_info_case_sensitive': caseSensitive,
    'world_info_match_whole_words': matchWholeWords,
    'world_info_use_group_scoring': useGroupScoring,
    'world_info_overflow_alert': overflowAlert,
  };

  /// 键名沿用 ST 的 `world_info_*`；缺失或类型不对的取默认值。
  static WorldBookSettings fromJson(Object? raw) {
    if (raw is! Map<dynamic, dynamic>) return defaults;
    int n(String k, int d) => raw[k] is num ? (raw[k] as num).toInt() : d;
    bool b(String k, bool d) => raw[k] is bool ? raw[k] as bool : d;
    return WorldBookSettings(
      scanDepth: n('world_info_depth', 2),
      minActivations: n('world_info_min_activations', 0),
      minActivationsDepthMax: n('world_info_min_activations_depth_max', 0),
      budgetPercent: n('world_info_budget', 25),
      budgetCap: n('world_info_budget_cap', 0),
      includeNames: b('world_info_include_names', false),
      recursive: b('world_info_recursive', false),
      maxRecursionSteps: n('world_info_max_recursion_steps', 0),
      caseSensitive: b('world_info_case_sensitive', false),
      matchWholeWords: b('world_info_match_whole_words', false),
      useGroupScoring: b('world_info_use_group_scoring', false),
      overflowAlert: b('world_info_overflow_alert', false),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorldBookSettings &&
      other.scanDepth == scanDepth &&
      other.minActivations == minActivations &&
      other.minActivationsDepthMax == minActivationsDepthMax &&
      other.budgetPercent == budgetPercent &&
      other.budgetCap == budgetCap &&
      other.includeNames == includeNames &&
      other.recursive == recursive &&
      other.maxRecursionSteps == maxRecursionSteps &&
      other.caseSensitive == caseSensitive &&
      other.matchWholeWords == matchWholeWords &&
      other.useGroupScoring == useGroupScoring &&
      other.overflowAlert == overflowAlert;

  @override
  int get hashCode => Object.hash(
    scanDepth,
    minActivations,
    minActivationsDepthMax,
    budgetPercent,
    budgetCap,
    includeNames,
    recursive,
    maxRecursionSteps,
    caseSensitive,
    matchWholeWords,
    useGroupScoring,
    overflowAlert,
  );
}
