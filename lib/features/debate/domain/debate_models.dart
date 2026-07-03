/// AI 辩论的领域模型：角色、设置与场景快照。
///
/// Framework-free（同 `NotionSettings` 的手写 JSON 风格），设置页、引擎与
/// 组合缝共享。模型引用统一用 `providerId/modelId` 组合键（同 模型组合 的
/// `ModelComboEntry.modelId` 约定），空串表示未配置。
library;

/// 角色立场。web 版的 `DebateRole.stance` 一比一迁移，颜色由立场固定
/// （web 的自定义颜色选择器不迁移）。
enum DebateStance {
  pro('pro', '正方', 0xFF4CAF50),
  con('con', '反方', 0xFFF44336),
  neutral('neutral', '中立', 0xFFFF9800),
  moderator('moderator', '主持人', 0xFF9C27B0),
  summary('summary', '总结', 0xFF607D8B);

  const DebateStance(this.storageValue, this.label, this.colorValue);

  final String storageValue;
  final String label;

  /// 立场徽章色（ARGB），presentation 层用 `Color(colorValue)` 渲染。
  final int colorValue;

  static DebateStance fromStorage(String? value) =>
      DebateStance.values.firstWhere(
        (s) => s.storageValue == value,
        orElse: () => DebateStance.neutral,
      );
}

/// 一个辩论角色：人设提示词 + 立场 + 指定模型。
class DebateRole {
  const DebateRole({
    required this.id,
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.modelKey = '',
    this.stance = DebateStance.neutral,
  });

  factory DebateRole.fromJson(Map<String, dynamic> json) => DebateRole(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    systemPrompt: json['systemPrompt']?.toString() ?? '',
    modelKey: json['modelKey']?.toString() ?? '',
    stance: DebateStance.fromStorage(json['stance']?.toString()),
  );

  final String id;
  final String name;
  final String description;
  final String systemPrompt;

  /// `providerId/modelId` 组合键；空串 = 未配置模型。
  final String modelKey;
  final DebateStance stance;

  bool get hasModel => modelKey.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'systemPrompt': systemPrompt,
    'modelKey': modelKey,
    'stance': stance.storageValue,
  };

  DebateRole copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    String? modelKey,
    DebateStance? stance,
  }) => DebateRole(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    modelKey: modelKey ?? this.modelKey,
    stance: stance ?? this.stance,
  );
}

/// 命名的配置快照（web `DebateConfigGroup` 的迁移）：把一组角色 + 关键参数
/// 存成场景，随时加载。
class DebateScene {
  const DebateScene({
    required this.id,
    required this.name,
    this.description = '',
    this.roles = const <DebateRole>[],
    this.maxRounds = 3,
    this.moderatorEnabled = true,
    this.summaryEnabled = true,
  });

  factory DebateScene.fromJson(Map<String, dynamic> json) => DebateScene(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    roles: [
      for (final r in (json['roles'] as List? ?? const []))
        DebateRole.fromJson((r as Map).cast<String, dynamic>()),
    ],
    maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 3,
    moderatorEnabled: json['moderatorEnabled'] != false,
    summaryEnabled: json['summaryEnabled'] != false,
  );

  final String id;
  final String name;
  final String description;
  final List<DebateRole> roles;
  final int maxRounds;
  final bool moderatorEnabled;
  final bool summaryEnabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'roles': [for (final r in roles) r.toJson()],
    'maxRounds': maxRounds,
    'moderatorEnabled': moderatorEnabled,
    'summaryEnabled': summaryEnabled,
  };
}

/// 持久化的 AI 辩论设置（web `aiDebateConfig` + `aiDebateConfigGroups` 合并）。
///
/// web 的 `autoEndConditions`（每轮 token 上限 / 超时分钟）是引擎从未读取的
/// 死配置，不迁移；新增 [turnGapSeconds]（web 硬编码 3 秒）与
/// [historyWindow] / [maxCharsPerTurn]（web 硬编码 6 条 / 200 字）为可配项。
class DebateSettings {
  const DebateSettings({
    this.maxRounds = 3,
    this.turnGapSeconds = 3,
    this.historyWindow = 6,
    this.maxCharsPerTurn = 200,
    this.moderatorEnabled = true,
    this.summaryEnabled = true,
    this.roles = const <DebateRole>[],
    this.scenes = const <DebateScene>[],
  });

  factory DebateSettings.fromJson(Map<String, dynamic> json) => DebateSettings(
    maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 3,
    turnGapSeconds: (json['turnGapSeconds'] as num?)?.toInt() ?? 3,
    historyWindow: (json['historyWindow'] as num?)?.toInt() ?? 6,
    maxCharsPerTurn: (json['maxCharsPerTurn'] as num?)?.toInt() ?? 200,
    moderatorEnabled: json['moderatorEnabled'] != false,
    summaryEnabled: json['summaryEnabled'] != false,
    roles: [
      for (final r in (json['roles'] as List? ?? const []))
        DebateRole.fromJson((r as Map).cast<String, dynamic>()),
    ],
    scenes: [
      for (final s in (json['scenes'] as List? ?? const []))
        DebateScene.fromJson((s as Map).cast<String, dynamic>()),
    ],
  );

  final int maxRounds;

  /// 每个角色发言后的间隔秒数（0 = 不等待）。
  final int turnGapSeconds;

  /// 构建上下文时携带的最近发言条数。
  final int historyWindow;

  /// 单次发言的建议字数上限（写进提示词的软约束）。
  final int maxCharsPerTurn;

  final bool moderatorEnabled;
  final bool summaryEnabled;
  final List<DebateRole> roles;
  final List<DebateScene> scenes;

  /// 至少两个发言角色（不含总结角色）才能开始辩论。
  bool get isConfigured =>
      roles.where((r) => r.stance != DebateStance.summary).length >= 2;

  Map<String, dynamic> toJson() => {
    'maxRounds': maxRounds,
    'turnGapSeconds': turnGapSeconds,
    'historyWindow': historyWindow,
    'maxCharsPerTurn': maxCharsPerTurn,
    'moderatorEnabled': moderatorEnabled,
    'summaryEnabled': summaryEnabled,
    'roles': [for (final r in roles) r.toJson()],
    'scenes': [for (final s in scenes) s.toJson()],
  };

  DebateSettings copyWith({
    int? maxRounds,
    int? turnGapSeconds,
    int? historyWindow,
    int? maxCharsPerTurn,
    bool? moderatorEnabled,
    bool? summaryEnabled,
    List<DebateRole>? roles,
    List<DebateScene>? scenes,
  }) => DebateSettings(
    maxRounds: maxRounds ?? this.maxRounds,
    turnGapSeconds: turnGapSeconds ?? this.turnGapSeconds,
    historyWindow: historyWindow ?? this.historyWindow,
    maxCharsPerTurn: maxCharsPerTurn ?? this.maxCharsPerTurn,
    moderatorEnabled: moderatorEnabled ?? this.moderatorEnabled,
    summaryEnabled: summaryEnabled ?? this.summaryEnabled,
    roles: roles ?? this.roles,
    scenes: scenes ?? this.scenes,
  );
}
