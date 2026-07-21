import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_dao.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 事件落库抽象（企业级红线：任何路径不得跳过事件落库直接产生副作用；
/// 每步先落库再继续——循环设计稿 §2.1 / §2.2）。
/// 流式文本/工具状态更新按 id 原位 upsert（seq 不变），事件表不膨胀。
abstract class AgentEventStore {
  Future<List<AgentEvent>> getEvents(String taskId);

  Future<UserMessageEvent> appendUserMessage(
    String taskId,
    String text, {
    bool queued = false,
    List<AgentUserAttachment> attachments = const [],
    String? replyToQuestionId,
  });

  /// 安全点消费排队消息：queued=true → false，正式进上下文（L3）。
  Future<void> consumeQueuedUserMessages(String taskId);

  /// ask_user 提问：问题 + 建议答案，UI 渲染为可交互提问卡。
  Future<UserQuestionEvent> appendUserQuestion(
    String taskId,
    String question, {
    List<String> suggestions = const [],
    String? toolCallId,
    String? argsJson,
  });

  Future<AssistantTextEvent> appendAssistantText(
    String taskId,
    String text, {
    required bool streaming,
  });

  /// 流式原位覆盖（id/seq 不变，L6）。
  Future<AssistantTextEvent> updateAssistantText(
    String taskId,
    AssistantTextEvent event,
    String text, {
    required bool streaming,
  });

  Future<ReasoningEvent> appendReasoning(
    String taskId,
    String text, {
    required bool streaming,
  });

  /// 流式原位覆盖（id/seq 不变）；[elapsed] 在收尾时定格思考耗时。
  Future<ReasoningEvent> updateReasoning(
    String taskId,
    ReasoningEvent event,
    String text, {
    required bool streaming,
    Duration? elapsed,
  });

  Future<ToolCallEvent> appendToolCall(
    String taskId,
    AgentToolCallRequest call,
    AgentToolCallState state,
  );

  Future<ToolCallEvent> updateToolCall(
    String taskId,
    ToolCallEvent event, {
    required AgentToolCallState state,
    String? argSummary,
    String? argsDetail,
    String? resultSummary,
    String? resultDetail,
    String? resultOverflowPath,
    Duration? elapsed,
  });

  Future<PlanUpdateEvent> appendPlanUpdate(
    String taskId,
    List<AgentPlanItem> items,
  );

  Future<StatusChangeEvent> appendStatusChange(
    String taskId,
    String description,
  );

  /// 状态行原位改写（id/seq 不变）：hook 运行状态「运行中 → 结果」。
  Future<StatusChangeEvent> updateStatusChange(
    String taskId,
    StatusChangeEvent event,
    String description,
  );

  Future<CheckpointEvent> appendCheckpoint(
    String taskId, {
    required Map<String, String> commits,
    String label = '',
  });

  /// 检查点 commits 原位补写（id/seq 不变）：占位检查点先落库让用户
  /// 消息立即显示，耗时的 git 快照完成后回填。
  Future<CheckpointEvent> updateCheckpoint(
    String taskId,
    CheckpointEvent event, {
    required Map<String, String> commits,
  });

  /// 占位检查点快照失败/不可用时原位降级为状态行（沿用 id/seq），
  /// 避免留下永远不可回滚的空检查点。
  Future<StatusChangeEvent> replaceCheckpointWithStatus(
    String taskId,
    CheckpointEvent event,
    String description,
  );

  /// 删除单个事件（占位检查点静默降级：提示已经出过一次时直接移除，
  /// 不每条消息刷一行状态）。
  Future<void> removeEvent(String taskId, AgentEvent event);

  Future<CompactionEvent> appendCompaction(
    String taskId, {
    required int coveredCount,
    required String summary,
    List<CompactionRestoredFile> restoredFiles = const [],
  });

  /// 压缩撤销标记原位改写（id/seq 不变）：撤销后不再参与上下文
  /// 视图折叠，事件行保留作审计痕迹。
  Future<CompactionEvent> updateCompaction(
    String taskId,
    CompactionEvent event, {
    required bool revoked,
  });

  /// 删除话题内 seq 大于 [seq] 的全部事件（回滚对话到检查点）。
  Future<void> truncateEventsAfter(String taskId, int seq);
}

/// drift 实现：AgentDao 之上的薄封装，seq 从库内最大值续增。
class DriftAgentEventStore implements AgentEventStore {
  DriftAgentEventStore(this._dao);

  final AgentDao _dao;
  final Map<String, int> _seqCache = {};

  /// 按 taskId 串行化 seq 分配：缓存未命中时 `maxSeq` 是异步查询，
  /// 多入口（引擎/插队消息）并发进入会拿到相同 seq；用尾链把同任务的
  /// 分配排队执行。
  final Map<String, Future<void>> _seqLocks = {};
  int _idCounter = 0;

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Future<int> _nextSeq(String taskId) {
    final prev = _seqLocks[taskId] ?? Future<void>.value();
    final next = prev.then((_) async {
      final cached = _seqCache[taskId];
      final value =
          cached != null ? cached + 1 : await _dao.maxSeq(taskId) + 1;
      _seqCache[taskId] = value;
      return value;
    });
    _seqLocks[taskId] = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<List<AgentEvent>> getEvents(String taskId) => _dao.getEvents(taskId);

  @override
  Future<UserMessageEvent> appendUserMessage(
    String taskId,
    String text, {
    bool queued = false,
    List<AgentUserAttachment> attachments = const [],
    String? replyToQuestionId,
  }) async {
    final event = UserMessageEvent(
      id: _newId('um'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      queued: queued,
      attachments: attachments,
      replyToQuestionId: replyToQuestionId,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<void> consumeQueuedUserMessages(String taskId) async {
    final events = await _dao.getEventsOfKind(taskId, 'user_message');
    final consumed = [
      for (final e in events)
        if (e is UserMessageEvent && e.queued)
          UserMessageEvent(
            id: e.id,
            seq: e.seq,
            at: e.at,
            text: e.text,
            attachments: e.attachments,
            replyToQuestionId: e.replyToQuestionId,
          ),
    ];
    if (consumed.isNotEmpty) {
      await _dao.upsertEvents(taskId, consumed);
    }
  }

  @override
  Future<UserQuestionEvent> appendUserQuestion(
    String taskId,
    String question, {
    List<String> suggestions = const [],
    String? toolCallId,
    String? argsJson,
  }) async {
    final event = UserQuestionEvent(
      id: _newId('uq'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      question: question,
      suggestions: suggestions,
      toolCallId: toolCallId,
      argsJson: argsJson,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<AssistantTextEvent> appendAssistantText(
    String taskId,
    String text, {
    required bool streaming,
  }) async {
    final event = AssistantTextEvent(
      id: _newId('at'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      streaming: streaming,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<AssistantTextEvent> updateAssistantText(
    String taskId,
    AssistantTextEvent event,
    String text, {
    required bool streaming,
  }) async {
    final updated = AssistantTextEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      text: text,
      streaming: streaming,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }

  @override
  Future<ReasoningEvent> appendReasoning(
    String taskId,
    String text, {
    required bool streaming,
  }) async {
    final event = ReasoningEvent(
      id: _newId('rs'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      streaming: streaming,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<ReasoningEvent> updateReasoning(
    String taskId,
    ReasoningEvent event,
    String text, {
    required bool streaming,
    Duration? elapsed,
  }) async {
    final updated = ReasoningEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      text: text,
      streaming: streaming,
      elapsed: elapsed ?? event.elapsed,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }

  @override
  Future<ToolCallEvent> appendToolCall(
    String taskId,
    AgentToolCallRequest call,
    AgentToolCallState state,
  ) async {
    final event = ToolCallEvent(
      id: _newId('tc'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      toolName: call.name,
      argSummary: call.argSummary,
      state: state,
      argsDetail: call.argsJson,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<ToolCallEvent> updateToolCall(
    String taskId,
    ToolCallEvent event, {
    required AgentToolCallState state,
    String? argSummary,
    String? argsDetail,
    String? resultSummary,
    String? resultDetail,
    String? resultOverflowPath,
    Duration? elapsed,
  }) async {
    final updated = ToolCallEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      toolName: event.toolName,
      argSummary: argSummary ?? event.argSummary,
      state: state,
      resultSummary: resultSummary ?? event.resultSummary,
      elapsed: elapsed ?? event.elapsed,
      argsDetail: argsDetail ?? event.argsDetail,
      resultDetail: resultDetail ?? event.resultDetail,
      resultOverflowPath: resultOverflowPath ?? event.resultOverflowPath,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }

  @override
  Future<PlanUpdateEvent> appendPlanUpdate(
    String taskId,
    List<AgentPlanItem> items,
  ) async {
    final event = PlanUpdateEvent(
      id: _newId('pu'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      items: items,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<StatusChangeEvent> appendStatusChange(
    String taskId,
    String description,
  ) async {
    final event = StatusChangeEvent(
      id: _newId('sc'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      description: description,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<StatusChangeEvent> updateStatusChange(
    String taskId,
    StatusChangeEvent event,
    String description,
  ) async {
    final updated = StatusChangeEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      description: description,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }

  @override
  Future<CheckpointEvent> appendCheckpoint(
    String taskId, {
    required Map<String, String> commits,
    String label = '',
  }) async {
    final event = CheckpointEvent(
      id: _newId('ck'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      commits: commits,
      label: label,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<CheckpointEvent> updateCheckpoint(
    String taskId,
    CheckpointEvent event, {
    required Map<String, String> commits,
  }) async {
    final updated = CheckpointEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      commits: commits,
      label: event.label,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }

  @override
  Future<StatusChangeEvent> replaceCheckpointWithStatus(
    String taskId,
    CheckpointEvent event,
    String description,
  ) async {
    // 同 id/seq 覆写（主键是 id，insertOrReplace 会一并改写 kind 列）。
    final updated = StatusChangeEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      description: description,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }

  @override
  Future<void> removeEvent(String taskId, AgentEvent event) =>
      _dao.deleteEventById(taskId, event.id);

  @override
  Future<void> truncateEventsAfter(String taskId, int seq) {
    // 挂进同任务的 seq 尾链：与在途 _nextSeq 串行化，缓存重置不会
    // 与并发分配交错产生重复 seq。
    final prev = _seqLocks[taskId] ?? Future<void>.value();
    final next = prev.then((_) async {
      await _dao.deleteEventsAfterSeq(taskId, seq);
      // 后续事件从检查点处续增，不能沿用截断前的缓存。
      _seqCache[taskId] = seq;
    });
    _seqLocks[taskId] = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<CompactionEvent> appendCompaction(
    String taskId, {
    required int coveredCount,
    required String summary,
    List<CompactionRestoredFile> restoredFiles = const [],
  }) async {
    final event = CompactionEvent(
      id: _newId('cp'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      coveredCount: coveredCount,
      summary: summary,
      restoredFiles: restoredFiles,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<CompactionEvent> updateCompaction(
    String taskId,
    CompactionEvent event, {
    required bool revoked,
  }) async {
    final updated = CompactionEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      coveredCount: event.coveredCount,
      summary: event.summary,
      revoked: revoked,
      restoredFiles: event.restoredFiles,
    );
    await _dao.upsertEvents(taskId, [updated]);
    return updated;
  }
}
