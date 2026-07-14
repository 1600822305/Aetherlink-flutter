/// 事件流：UI 与模型上下文的唯一事实来源（append-only，按 seq 排序）。
/// 类型清单见 docs/智能体/智能体模式-设计初稿.md §四；渲染形态见 UI 稿 §4.1。
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

/// 用户消息附件种类（输入栏＋菜单 / @ 引用注入）。
enum AgentAttachmentKind {
  /// 图片：base64 随多模态请求发送。
  image,

  /// 文件文本片段（工作区 @ 引用 / 设备文件）。
  file,

  /// 即时引用片段（Diff 改动清单、终端输出等）。
  snippet,
}

/// 用户消息附件：文本类附件走 [text]（随消息拼进上下文），
/// 图片走 [base64Data] + [mimeType]（多模态图片分部分）。
class AgentUserAttachment {
  const AgentUserAttachment({
    required this.kind,
    required this.name,
    this.text,
    this.mimeType,
    this.base64Data,
  });

  final AgentAttachmentKind kind;

  /// 展示名（文件相对路径 / 图片文件名 / 引用标题）。
  final String name;

  final String? text;
  final String? mimeType;
  final String? base64Data;
}

/// 用户指令（含排队追加的指令与附件）。
class UserMessageEvent extends AgentEvent {
  const UserMessageEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.text,
    this.queued = false,
    this.attachments = const [],
    this.replyToQuestionId,
    this.questionAnswers = const [],
  });

  final String text;

  /// true = 执行中排队注入的追加指令（事件流回显"已排队"态）。
  final bool queued;

  final List<AgentUserAttachment> attachments;

  /// 非空时表示这条消息是对某个 [UserQuestionEvent] 的结构化回答。
  final String? replyToQuestionId;

  final List<AgentUserQuestionAnswer> questionAnswers;
}

class AgentUserQuestion {
  const AgentUserQuestion({
    required this.question,
    this.options = const [],
    this.allowMultiple = false,
  });

  final String question;
  final List<String> options;
  final bool allowMultiple;
}

class AgentUserQuestionAnswer {
  const AgentUserQuestionAnswer({
    required this.questionIndex,
    required this.values,
  });

  final int questionIndex;
  final List<String> values;
}

/// ask_user 提问（引擎控制工具落地）：支持一次提交多个结构化问题，
/// 每题可配置单选/多选，并始终允许用户输入自定义回答。
class UserQuestionEvent extends AgentEvent {
  const UserQuestionEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.questions,
    this.toolCallId,
    this.argsJson,
  });

  final List<AgentUserQuestion> questions;

  /// 保留原始工具调用身份，恢复后可按 function-call 语义回放给模型。
  final String? toolCallId;
  final String? argsJson;

  /// 兼容单问题调用方与历史展示逻辑。
  String get question => questions.firstOrNull?.question ?? '需要你的输入';
  List<String> get options => questions.firstOrNull?.options ?? const [];
}

UserMessageEvent? userQuestionAnswer(
  UserQuestionEvent question,
  Iterable<AgentEvent> events,
) {
  final messages = events.whereType<UserMessageEvent>();
  final explicit = messages
      .where((event) => event.replyToQuestionId == question.id)
      .firstOrNull;
  if (explicit != null) return explicit;
  if (question.toolCallId == null) {
    return messages.where((event) => event.seq > question.seq).firstOrNull;
  }
  return null;
}

/// 结构化回答的统一文本形态（落库与恢复重放共用，保证两侧一致）：
/// 单问题直接给答案值，多问题按「问题 + 回答」分段；索引越界的条目
/// 跳过，全部无效时退回 [fallback]。
String formatQuestionAnswers(
  UserQuestionEvent question,
  List<AgentUserQuestionAnswer> answers, {
  String fallback = '',
}) {
  final lines = [
    for (final item in answers)
      if (item.questionIndex >= 0 &&
          item.questionIndex < question.questions.length)
        question.questions.length == 1
            ? item.values.join('、')
            : '${question.questions[item.questionIndex].question}\n'
                '回答：${item.values.join('、')}',
  ];
  if (lines.isEmpty) return fallback;
  return lines.join('\n\n');
}

UserQuestionEvent? latestPendingUserQuestion(Iterable<AgentEvent> events) {
  final list = events.toList();
  for (final question
      in list.whereType<UserQuestionEvent>().toList().reversed) {
    if (userQuestionAnswer(question, list) == null) return question;
  }
  return null;
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

/// 模型思考过程（reasoning/thinking，流式渲染为可折叠的"思考了 Xs"块，
/// 默认收起，点开看全文；不进后续上下文，仅供用户观察）。
class ReasoningEvent extends AgentEvent {
  const ReasoningEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.text,
    this.streaming = false,
    this.elapsed,
  });

  final String text;
  final bool streaming;

  /// 思考耗时（流式结束时定格，驱动"思考了 Xs"标题）。
  final Duration? elapsed;
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
    this.argsDetail,
    this.resultDetail,
    this.resultOverflowPath,
  });

  /// 例：`read_file` / `terminal_execute`。
  final String toolName;

  /// 单行关键参数（路径尾段/命令），UI 稿 §4.1 工具行。
  final String argSummary;

  final AgentToolCallState state;

  /// 例：`234 行 · 0.4s`、`失败 ✗`。
  final String resultSummary;

  final Duration? elapsed;

  /// 完整参数（底部抽屉展示；null 时抽屉回退显示 [argSummary]）。
  final String? argsDetail;

  /// 完整输出（底部抽屉展示，大输出截断落盘后这里存截断内容）。
  final String? resultDetail;

  /// 大输出全文落盘路径（详情面板「查看全文」数据源；未截断为 null）。
  final String? resultOverflowPath;
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

/// 检查点（初稿 §5.5 P2）：用户消息落地前对 git 工作区做的基线快照，
/// 事件流上渲染为可「回滚」的标记行。仅 git 工作区产生。
class CheckpointEvent extends AgentEvent {
  const CheckpointEvent({
    required super.id,
    required super.seq,
    required super.at,
    required this.commit,
    this.label = '',
  });

  /// 基线 commit 哈希（由 refs/aetherlink/checkpoints/… 保活，防 gc）。
  final String commit;

  /// 触发检查点的用户消息摘要（UI 标记行展示）。
  final String label;
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
