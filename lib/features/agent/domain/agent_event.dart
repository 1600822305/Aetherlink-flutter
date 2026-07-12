/// 事件流：UI 与模型上下文的唯一事实来源（append-only，按 seq 排序）。
/// 类型清单见 docs/智能体模式-设计初稿.md §四；渲染形态见 UI 稿 §4.1。
library;

/// 计划条目状态（update_plan：TodoWrite 同款三态，全量覆盖）。
enum AgentPlanItemStatus { pending, inProgress, completed }

class AgentPlanItem {
  const AgentPlanItem({required this.content, required this.status});

  final String content;
  final AgentPlanItemStatus status;
}

/// 工具调用的审批/执行状态（驱动工具行与审批卡）。
enum AgentToolCallState { waitingApproval, running, success, failure, denied }

sealed class AgentEvent {
  const AgentEvent({required this.id, required this.seq, required this.at});

  final String id;

  /// 话题内单调递增的序号，重放/恢复的排序依据。
  final int seq;

  final DateTime at;
}

/// 用户指令（含排队追加的指令与附件）。
class UserMessageEvent extends AgentEvent {
  const UserMessageEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.text,
    this.queued = false,
  });

  final String text;

  /// true = 执行中排队注入的追加指令（事件流回显"已排队"态）。
  final bool queued;
}

/// 模型叙述文字（思考/汇报，流式渲染为贴左正文段落）。
class AssistantTextEvent extends AgentEvent {
  const AssistantTextEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.text,
    this.streaming = false,
  });

  final String text;
  final bool streaming;
}

/// 工具调用（含审批状态与结果摘要；完整参数/输出走底部抽屉查看）。
class ToolCallEvent extends AgentEvent {
  const ToolCallEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.toolName,
    required this.argSummary,
    required this.state,
    this.resultSummary = '',
    this.elapsed,
  });

  /// 例：`read_file` / `terminal_execute`。
  final String toolName;

  /// 单行关键参数（路径尾段/命令），UI 稿 §4.1 工具行。
  final String argSummary;

  final AgentToolCallState state;

  /// 例：`234 行 · 0.4s`、`失败 ✗`。
  final String resultSummary;

  final Duration? elapsed;
}

/// update_plan 产生的计划快照（全量覆盖）。
class PlanUpdateEvent extends AgentEvent {
  const PlanUpdateEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.items,
  });

  final List<AgentPlanItem> items;
}

/// 上下文压缩：旧事件被摘要替代参与后续上下文（原始事件仍可回看）。
class CompactionEvent extends AgentEvent {
  const CompactionEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.coveredCount,
    required this.summary,
  });

  final int coveredCount;
  final String summary;
}

/// 状态迁移记录（出错/用户暂停/超限……）。
class StatusChangeEvent extends AgentEvent {
  const StatusChangeEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.description,
  });

  final String description;
}
