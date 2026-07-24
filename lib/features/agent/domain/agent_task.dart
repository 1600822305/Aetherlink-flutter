/// 智能体话题（=一次任务执行 = 一条事件流），归属某个 [AgentProfile]。
/// 状态机见 docs/智能体/智能体模式-设计初稿.md §四。
library;

/// 任务状态。色板（全局统一，UI 稿 §三）：draft=灰、running=primary（呼吸）、
/// waitingApproval=橙、waitingInput=蓝、paused=灰、done=绿、failed=红、
/// cancelled=灰删除线。
enum AgentTaskStatus {
  /// 空白新话题（对齐聊天「新的对话」）：已在列表里占位，
  /// 发第一条消息才定标题并启动引擎。
  draft,
  running,
  waitingApproval,
  waitingInput,
  paused,
  done,
  failed,
  cancelled,
}

/// 输入区上沿快切的会话模式（与权限模式一一对应，UI 稿输入区）。
enum AgentSessionMode {
  /// 执行模式：写/终端全能力，走审批+白名单。
  code,

  /// 自动模式：绑定工作区内的写/执行免审批直通；越出工作区边界的
  /// 操作仍强制审批（与白名单同级的硬约束，不可覆盖）。
  auto,

  /// 只问答：仅只读工具，不改任何东西。
  ask,

  /// 只读规划：先出完整方案，确认后一键转 code 继续执行。
  plan,
}

class AgentTask {
  const AgentTask({
    required this.id,
    required this.profileId,
    required this.title,
    required this.workspaceId,
    required this.workspaceName,
    required this.status,
    required this.mode,
    this.prePlanMode,
    required this.createdAt,
    required this.updatedAt,
    this.modelLabel = '',
    this.rounds = 0,
    this.tokenCount = 0,
    this.contextTokens = 0,
    this.contextTokensRound = 0,
    this.elapsed = Duration.zero,
    this.lastEventSummary = '',
    this.parentTaskId = '',
    this.pinned = false,
  });

  final String id;
  final String profileId;
  final String title;

  /// 工作区一律必选（已拍板"强制要求选择工作区"）。
  final String workspaceId;
  final String workspaceName;

  final AgentTaskStatus status;
  final AgentSessionMode mode;

  /// 模型主动进入计划模式（enter_plan_mode）前的原模式；
  /// 方案批准退出时恢复到该模式（对标 CC prePlanMode）。
  final AgentSessionMode? prePlanMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 展示用：执行模型名（复用聊天模型选择，仅记录标签）。
  final String modelLabel;

  final int rounds;

  /// 累计 token 用量（计费口径：每轮输入+输出累加）。
  final int tokenCount;

  /// 当前上下文占用（最近一次 LLM 请求的总 token，对比窗口上限）。
  final int contextTokens;

  /// [contextTokens] 测得时的轮次：供应商不回 usage 时沿用旧值，
  /// 记住测量轮次才能在 UI 上提示可能滞后（0 = 未知）。
  final int contextTokensRound;
  final Duration elapsed;

  /// 侧栏话题卡上的最近事件摘要。
  final String lastEventSummary;

  /// 非空 = 子任务（subagent 派生的隐藏话题），不进侧栏话题列表，
  /// 只通过父时间线的子任务行展开查看。
  final String parentTaskId;

  /// 固定在侧栏话题列表顶部（对齐聊天话题的固定语义）。
  final bool pinned;

  bool get isSubtask => parentTaskId.isNotEmpty;

  bool get isActive =>
      status == AgentTaskStatus.running ||
      status == AgentTaskStatus.waitingApproval ||
      status == AgentTaskStatus.waitingInput ||
      status == AgentTaskStatus.paused;

  AgentTask copyWith({
    String? title,
    String? workspaceId,
    String? workspaceName,
    AgentTaskStatus? status,
    AgentSessionMode? mode,
    AgentSessionMode? prePlanMode,
    bool clearPrePlanMode = false,
    DateTime? updatedAt,
    String? modelLabel,
    int? rounds,
    int? tokenCount,
    int? contextTokens,
    int? contextTokensRound,
    Duration? elapsed,
    String? lastEventSummary,
    bool? pinned,
  }) {
    return AgentTask(
      id: id,
      profileId: profileId,
      title: title ?? this.title,
      workspaceId: workspaceId ?? this.workspaceId,
      workspaceName: workspaceName ?? this.workspaceName,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      prePlanMode: clearPrePlanMode ? null : (prePlanMode ?? this.prePlanMode),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modelLabel: modelLabel ?? this.modelLabel,
      rounds: rounds ?? this.rounds,
      tokenCount: tokenCount ?? this.tokenCount,
      contextTokens: contextTokens ?? this.contextTokens,
      contextTokensRound: contextTokensRound ?? this.contextTokensRound,
      elapsed: elapsed ?? this.elapsed,
      lastEventSummary: lastEventSummary ?? this.lastEventSummary,
      parentTaskId: parentTaskId,
      pinned: pinned ?? this.pinned,
    );
  }
}
