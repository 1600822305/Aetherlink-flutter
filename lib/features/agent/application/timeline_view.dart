/// 事件流页面的推导视图：把时间线块、计划快照、待答提问等 UI 需要的
/// 全部推导集中到一个按任务缓存的增量折叠器里。事件流基本
/// append-only，只有未完结事件会原地变更；已被正文「收尾」的前缀
/// 只折叠一次，每个 delta 只重放尾部未收尾段，把流式期间每帧的
/// O(全部事件) 推导降到 O(尾部)。前缀完整性用事件实例的 identical
/// 校验（DAO 按行缓存解码对象，行未变即同实例），任何原地变更都会
/// 触发整体重折，保证与全量推导等价。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 一次事件发射推导出的时间线视图。
class AgentTimelineView {
  const AgentTimelineView({
    required this.blocks,
    required this.latestPlan,
    required this.hasLiveEvent,
    required this.userInputCount,
    required this.pendingQuestion,
    required this.answersByQuestionId,
    required this.latestActiveCompactionId,
    required this.latestFocus,
  });

  static const empty = AgentTimelineView(
    blocks: [],
    latestPlan: null,
    hasLiveEvent: false,
    userInputCount: 0,
    pendingQuestion: null,
    answersByQuestionId: {},
    latestActiveCompactionId: null,
    latestFocus: null,
  );

  final List<TimelineBlock> blocks;

  /// 最新非空计划快照（顶部计划纪要条）。
  final PlanUpdateEvent? latestPlan;

  /// 是否存在实况事件（流式文本/思考、执行中或待审批工具）。
  final bool hasLiveEvent;

  /// 用户消息 + 提问总数（新增即显式回底）。
  final int userInputCount;

  /// 最新未答提问（追问面板数据源）。
  final UserQuestionEvent? pendingQuestion;

  /// 提问 id → 回答消息（提问卡按自己的 id 取）。
  final Map<String, UserMessageEvent> answersByQuestionId;

  /// 当前唯一可撤销的压缩事件 id（最近一次未撤销的压缩）。
  final String? latestActiveCompactionId;

  /// 最新「有产物可看」的活动（工作台焦点 tab）。
  final AgentEvent? latestFocus;
}

/// 折叠过程中的推导累计量；前缀持有一份持久实例，尾部每次
/// delta 用临时实例重放。
class _Acc {
  PlanUpdateEvent? plan;
  int userInputCount = 0;
  int liveCount = 0;
  final questions = <UserQuestionEvent>[];
  final answers = <String, UserMessageEvent>{};
  CompactionEvent? latestActiveCompaction;
  AgentEvent? latestFocus;

  void add(AgentEvent e) {
    switch (e) {
      case UserMessageEvent():
        userInputCount++;
        final replyTo = e.replyToQuestionId;
        if (replyTo != null) answers[replyTo] = e;
        latestFocus = e;
      case UserQuestionEvent():
        userInputCount++;
        questions.add(e);
      case PlanUpdateEvent():
        plan = e;
        latestFocus = e;
      case CompactionEvent():
        if (!e.revoked) latestActiveCompaction = e;
      case AssistantTextEvent():
        if (e.streaming) liveCount++;
        latestFocus = e;
      case ReasoningEvent():
        if (e.streaming) liveCount++;
        latestFocus = e;
      case ToolCallEvent():
        if (e.state == AgentToolCallState.running ||
            e.state == AgentToolCallState.waitingApproval) {
          liveCount++;
        }
        latestFocus = e;
      default:
        break;
    }
  }
}

/// 段收尾判定（与 [buildTimelineBlocks] 的 flush 边界保持一致，
/// 改折叠规则两处要同步）。
bool _closesSegment(AgentEvent e) =>
    (e is AssistantTextEvent && !e.streaming) ||
    e is UserMessageEvent ||
    e is StatusChangeEvent;

/// 实况（会被后续 delta 原地变更的）事件：流式文本/思考、
/// 执行中或待审批的工具。前缀推进在第一个实况事件处停下，
/// 让高频原地变更只落在尾部重放里，不触发整体重折。
bool _isLiveEvent(AgentEvent e) => switch (e) {
  AssistantTextEvent(:final streaming) => streaming,
  ReasoningEvent(:final streaming) => streaming,
  ToolCallEvent(:final state) =>
    state == AgentToolCallState.running ||
        state == AgentToolCallState.waitingApproval,
  _ => false,
};

/// 段缓冲落块（与 [buildTimelineBlocks] 的 flush 语义一致）。
void _flushInto(
  List<TimelineBlock> blocks,
  List<AgentEvent> run,
  int runTools, {
  required bool collapse,
  required bool closed,
}) {
  if (run.isEmpty) return;
  if (collapse && closed && runTools >= 1) {
    blocks.add(SegmentBlock(run));
  } else {
    blocks.addAll(run.map(SingleBlock.new));
  }
}

class AgentTimelineFold {
  /// `[0, _prefixCount)` 已折叠：块、累计量与未收尾的段缓冲
  /// （[_prefixRun]）作为左折叠的进位保存，不再重算。
  var _prefixCount = 0;
  final _prefixBlocks = <TimelineBlock>[];
  var _prefixRun = <AgentEvent>[];
  var _prefixRunTools = 0;
  var _prefixAcc = _Acc();

  List<AgentEvent>? _lastEvents;
  bool? _collapse;
  AgentTimelineView _view = AgentTimelineView.empty;
  bool? _lastRunning;

  void _reset() {
    _prefixCount = 0;
    _prefixBlocks.clear();
    _prefixRun = [];
    _prefixRunTools = 0;
    _prefixAcc = _Acc();
  }

  /// 前缀内任一事件实例被替换（原地变更/删减/重排）即失效。
  /// DAO 按行缓存解码对象，未变更的行复用同一实例，这里只做
  /// 指针比较，代价可忽略。
  bool _prefixIntact(List<AgentEvent> events) {
    final last = _lastEvents;
    if (last == null || events.length < _prefixCount) return false;
    for (var i = 0; i < _prefixCount; i++) {
      if (!identical(events[i], last[i])) return false;
    }
    return true;
  }

  AgentTimelineView fold(
    List<AgentEvent> events, {
    required bool collapse,
    required bool running,
  }) {
    if (identical(events, _lastEvents) &&
        collapse == _collapse &&
        running == _lastRunning) {
      return _view;
    }
    if (collapse != _collapse || !_prefixIntact(events)) _reset();
    _collapse = collapse;
    _lastRunning = running;
    _lastEvents = events;

    // 推进前缀：折叠尾部新到的稳定事件，遇到第一个实况事件停下。
    while (_prefixCount < events.length &&
        !_isLiveEvent(events[_prefixCount])) {
      final e = events[_prefixCount];
      if (_isSegmentInline(e)) {
        if (e is ToolCallEvent) _prefixRunTools++;
        _prefixRun.add(e);
      } else {
        _flushInto(
          _prefixBlocks,
          _prefixRun,
          _prefixRunTools,
          collapse: collapse,
          closed: _closesSegment(e),
        );
        _prefixRun = [];
        _prefixRunTools = 0;
        _prefixBlocks.add(SingleBlock(e));
      }
      _prefixAcc.add(e);
      _prefixCount++;
    }

    // 重放尾部（第一个实况事件起）：从前缀的段缓冲副本继续折叠。
    final tailAcc = _Acc();
    final blocks = List<TimelineBlock>.of(_prefixBlocks);
    var tailRun = List<AgentEvent>.of(_prefixRun);
    var tailRunTools = _prefixRunTools;
    void flushTail({required bool closed}) {
      _flushInto(blocks, tailRun, tailRunTools,
          collapse: collapse, closed: closed);
      tailRun = [];
      tailRunTools = 0;
    }

    for (var j = _prefixCount; j < events.length; j++) {
      final e = events[j];
      tailAcc.add(e);
      if (_isSegmentInline(e)) {
        if (e is ToolCallEvent) tailRunTools++;
        tailRun.add(e);
      } else {
        flushTail(closed: _closesSegment(e));
        blocks.add(SingleBlock(e));
      }
    }
    flushTail(closed: !running);

    final pfx = _prefixAcc;
    // 与 [latestPlan] 语义一致：取最后一条计划快照，空快照视为无计划。
    final lastPlan = tailAcc.plan ?? pfx.plan;
    _view = AgentTimelineView(
      blocks: blocks,
      latestPlan:
          (lastPlan == null || lastPlan.items.isEmpty) ? null : lastPlan,
      hasLiveEvent: pfx.liveCount + tailAcc.liveCount > 0,
      userInputCount: pfx.userInputCount + tailAcc.userInputCount,
      pendingQuestion: _pendingQuestion(pfx, tailAcc),
      answersByQuestionId: tailAcc.answers.isEmpty
          ? pfx.answers
          : {...pfx.answers, ...tailAcc.answers},
      latestActiveCompactionId:
          (tailAcc.latestActiveCompaction ?? pfx.latestActiveCompaction)?.id,
      latestFocus: tailAcc.latestFocus ?? pfx.latestFocus,
    );
    return _view;
  }

  /// 事件是否随段内联（与 [buildTimelineBlocks] 的分支保持一致）：
  /// 已完结工具、已定稿思考、计划更新。
  static bool _isSegmentInline(AgentEvent e) {
    if (e is ToolCallEvent) {
      return e.state == AgentToolCallState.success ||
          e.state == AgentToolCallState.failure ||
          e.state == AgentToolCallState.denied;
    }
    return (e is ReasoningEvent && !e.streaming) || e is PlanUpdateEvent;
  }

  static UserQuestionEvent? _pendingQuestion(_Acc pfx, _Acc tail) {
    UserQuestionEvent? scan(List<UserQuestionEvent> qs) {
      for (var i = qs.length - 1; i >= 0; i--) {
        final q = qs[i];
        if (!pfx.answers.containsKey(q.id) && !tail.answers.containsKey(q.id)) {
          return q;
        }
      }
      return null;
    }

    return scan(tail.questions) ?? scan(pfx.questions);
  }
}

final _timelineFoldProvider = Provider.autoDispose
    .family<AgentTimelineFold, String>((ref, taskId) => AgentTimelineFold());

/// 某任务的时间线视图：事件 delta 增量推导，watch 时用 select 取
/// 自己的切片即可避免被无关 delta 重建。
final agentTimelineProvider = Provider.autoDispose
    .family<AgentTimelineView, String>((ref, taskId) {
      final fold = ref.watch(_timelineFoldProvider(taskId));
      final events =
          ref.watch(agentTaskEventsProvider(taskId)).value ??
          const <AgentEvent>[];
      final collapse = ref.watch(
        agentUiSettingsControllerProvider.select(
          (s) => s.autoCollapseWorkSessions,
        ),
      );
      final running = ref.watch(
        agentTasksProvider.select(
          (tasks) =>
              tasks
                  .where((t) => t.id == taskId)
                  .firstOrNull
                  ?.status ==
              AgentTaskStatus.running,
        ),
      );
      return fold.fold(events, collapse: collapse, running: running);
    });
