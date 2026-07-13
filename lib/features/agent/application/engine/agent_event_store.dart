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
  });

  /// 安全点消费排队消息：queued=true → false，正式进上下文（L3）。
  Future<void> consumeQueuedUserMessages(String taskId);

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

  Future<CheckpointEvent> appendCheckpoint(
    String taskId, {
    required String commit,
    String label = '',
  });

  Future<CompactionEvent> appendCompaction(
    String taskId, {
    required int coveredCount,
    required String summary,
  });

  /// 删除话题内 seq 大于 [seq] 的全部事件（回滚对话到检查点）。
  Future<void> truncateEventsAfter(String taskId, int seq);
}

/// drift 实现：AgentDao 之上的薄封装，seq 从库内最大值续增。
class DriftAgentEventStore implements AgentEventStore {
  DriftAgentEventStore(this._dao);

  final AgentDao _dao;
  final Map<String, int> _seqCache = {};
  int _idCounter = 0;

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Future<int> _nextSeq(String taskId) async {
    final cached = _seqCache[taskId];
    final next = cached != null ? cached + 1 : await _dao.maxSeq(taskId) + 1;
    _seqCache[taskId] = next;
    return next;
  }

  @override
  Future<List<AgentEvent>> getEvents(String taskId) => _dao.getEvents(taskId);

  @override
  Future<UserMessageEvent> appendUserMessage(
    String taskId,
    String text, {
    bool queued = false,
  }) async {
    final event = UserMessageEvent(
      id: _newId('um'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      queued: queued,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<void> consumeQueuedUserMessages(String taskId) async {
    final events = await _dao.getEvents(taskId);
    final consumed = [
      for (final e in events)
        if (e is UserMessageEvent && e.queued)
          UserMessageEvent(id: e.id, seq: e.seq, at: e.at, text: e.text),
    ];
    if (consumed.isNotEmpty) {
      await _dao.upsertEvents(taskId, consumed);
    }
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
  Future<CheckpointEvent> appendCheckpoint(
    String taskId, {
    required String commit,
    String label = '',
  }) async {
    final event = CheckpointEvent(
      id: _newId('ck'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      commit: commit,
      label: label,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }

  @override
  Future<void> truncateEventsAfter(String taskId, int seq) async {
    await _dao.deleteEventsAfterSeq(taskId, seq);
    // 后续事件从检查点处续增，不能沿用截断前的缓存。
    _seqCache[taskId] = seq;
  }

  @override
  Future<CompactionEvent> appendCompaction(
    String taskId, {
    required int coveredCount,
    required String summary,
  }) async {
    final event = CompactionEvent(
      id: _newId('cp'),
      seq: await _nextSeq(taskId),
      at: DateTime.now(),
      coveredCount: coveredCount,
      summary: summary,
    );
    await _dao.upsertEvents(taskId, [event]);
    return event;
  }
}
