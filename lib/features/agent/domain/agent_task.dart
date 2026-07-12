/// 智能体话题（=一次任务执行 = 一条事件流），归属某个 [AgentProfile]。
/// 状态机见 docs/智能体/智能体模式-设计初稿.md §四。
library;

/// 任务状态。色板（全局统一，UI 稿 §三）：running=primary（呼吸）、
/// waitingApproval=橙、waitingInput=蓝、paused=灰、done=绿、failed=红、
/// cancelled=灰删除线。
enum AgentTaskStatus {
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
    required this.createdAt,
    required this.updatedAt,
    this.modelLabel = '',
    this.rounds = 0,
    this.tokenCount = 0,
    this.elapsed = Duration.zero,
    this.lastEventSummary = '',
  });

  final String id;
  final String profileId;
  final String title;

  /// 工作区一律必选（已拍板"强制要求选择工作区"）。
  final String workspaceId;
  final String workspaceName;

  final AgentTaskStatus status;
  final AgentSessionMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 展示用：执行模型名（复用聊天模型选择，仅记录标签）。
  final String modelLabel;

  final int rounds;
  final int tokenCount;
  final Duration elapsed;

  /// 侧栏话题卡上的最近事件摘要。
  final String lastEventSummary;

  bool get isActive =>
      status == AgentTaskStatus.running ||
      status == AgentTaskStatus.waitingApproval ||
      status == AgentTaskStatus.waitingInput ||
      status == AgentTaskStatus.paused;
}
