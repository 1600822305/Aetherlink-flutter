/// 智能体领域模型 ↔ JSON 编解码（设计初稿 §4.3）。
/// profile/task 整体存 JSON blob（对齐 chat 的 Topic 存法）；
/// 事件按 kind + payload_json 拆列存（可按类型查询/重放）。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

// ---------------------------------------------------------------------------
// AgentProfile
// ---------------------------------------------------------------------------

class AgentProfileConverter extends TypeConverter<AgentProfile, String> {
  const AgentProfileConverter();

  @override
  AgentProfile fromSql(String fromDb) {
    final json = jsonDecode(fromDb) as Map<String, dynamic>;
    return AgentProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🤖',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      tools: {
        for (final name in (json['tools'] as List<dynamic>? ?? const []))
          AgentToolGroup.values.byName(name as String),
      },
      workspaceId: json['workspaceId'] as String?,
      workspaceName: json['workspaceName'] as String?,
      builtin: json['builtin'] as bool? ?? false,
    );
  }

  @override
  String toSql(AgentProfile value) => jsonEncode({
        'id': value.id,
        'name': value.name,
        'emoji': value.emoji,
        'systemPrompt': value.systemPrompt,
        'tools': [for (final t in value.tools) t.name],
        'workspaceId': value.workspaceId,
        'workspaceName': value.workspaceName,
        'builtin': value.builtin,
      });
}

// ---------------------------------------------------------------------------
// AgentTask
// ---------------------------------------------------------------------------

class AgentTaskConverter extends TypeConverter<AgentTask, String> {
  const AgentTaskConverter();

  @override
  AgentTask fromSql(String fromDb) {
    final json = jsonDecode(fromDb) as Map<String, dynamic>;
    return AgentTask(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      title: json['title'] as String,
      workspaceId: json['workspaceId'] as String? ?? '',
      workspaceName: json['workspaceName'] as String? ?? '',
      status: AgentTaskStatus.values.byName(json['status'] as String),
      mode: AgentSessionMode.values.byName(json['mode'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      modelLabel: json['modelLabel'] as String? ?? '',
      rounds: json['rounds'] as int? ?? 0,
      tokenCount: json['tokenCount'] as int? ?? 0,
      elapsed: Duration(milliseconds: json['elapsedMs'] as int? ?? 0),
      lastEventSummary: json['lastEventSummary'] as String? ?? '',
    );
  }

  @override
  String toSql(AgentTask value) => jsonEncode({
        'id': value.id,
        'profileId': value.profileId,
        'title': value.title,
        'workspaceId': value.workspaceId,
        'workspaceName': value.workspaceName,
        'status': value.status.name,
        'mode': value.mode.name,
        'createdAt': value.createdAt.millisecondsSinceEpoch,
        'updatedAt': value.updatedAt.millisecondsSinceEpoch,
        'modelLabel': value.modelLabel,
        'rounds': value.rounds,
        'tokenCount': value.tokenCount,
        'elapsedMs': value.elapsed.inMilliseconds,
        'lastEventSummary': value.lastEventSummary,
      });
}

// ---------------------------------------------------------------------------
// AgentEvent（kind + payload_json；id/seq/at 是表的独立列，不进 payload）
// ---------------------------------------------------------------------------

String agentEventKind(AgentEvent event) => switch (event) {
      UserMessageEvent() => 'user_message',
      AssistantTextEvent() => 'assistant_text',
      ReasoningEvent() => 'reasoning',
      ToolCallEvent() => 'tool_call',
      PlanUpdateEvent() => 'plan_update',
      CompactionEvent() => 'compaction',
      StatusChangeEvent() => 'status_change',
    };

String encodeAgentEventPayload(AgentEvent event) {
  final payload = switch (event) {
    UserMessageEvent(:final text, :final queued) => {
        'text': text,
        'queued': queued,
      },
    AssistantTextEvent(:final text, :final streaming) => {
        'text': text,
        'streaming': streaming,
      },
    ReasoningEvent(:final text, :final streaming, :final elapsed) => {
        'text': text,
        'streaming': streaming,
        'elapsedMs': elapsed?.inMilliseconds,
      },
    ToolCallEvent(
      :final toolName,
      :final argSummary,
      :final state,
      :final resultSummary,
      :final elapsed,
      :final argsDetail,
      :final resultDetail,
    ) =>
      {
        'toolName': toolName,
        'argSummary': argSummary,
        'state': state.name,
        'resultSummary': resultSummary,
        'elapsedMs': elapsed?.inMilliseconds,
        'argsDetail': argsDetail,
        'resultDetail': resultDetail,
      },
    PlanUpdateEvent(:final items) => {
        'items': [
          for (final item in items)
            {'content': item.content, 'status': item.status.name},
        ],
      },
    CompactionEvent(:final coveredCount, :final summary) => {
        'coveredCount': coveredCount,
        'summary': summary,
      },
    StatusChangeEvent(:final description) => {'description': description},
  };
  return jsonEncode(payload);
}

AgentEvent decodeAgentEvent({
  required String id,
  required int seq,
  required DateTime at,
  required String kind,
  required String payloadJson,
}) {
  final p = jsonDecode(payloadJson) as Map<String, dynamic>;
  switch (kind) {
    case 'user_message':
      return UserMessageEvent(
        id: id,
        seq: seq,
        at: at,
        text: p['text'] as String? ?? '',
        queued: p['queued'] as bool? ?? false,
      );
    case 'assistant_text':
      return AssistantTextEvent(
        id: id,
        seq: seq,
        at: at,
        text: p['text'] as String? ?? '',
        streaming: p['streaming'] as bool? ?? false,
      );
    case 'reasoning':
      final elapsedMs = p['elapsedMs'] as int?;
      return ReasoningEvent(
        id: id,
        seq: seq,
        at: at,
        text: p['text'] as String? ?? '',
        streaming: p['streaming'] as bool? ?? false,
        elapsed: elapsedMs == null ? null : Duration(milliseconds: elapsedMs),
      );
    case 'tool_call':
      final elapsedMs = p['elapsedMs'] as int?;
      return ToolCallEvent(
        id: id,
        seq: seq,
        at: at,
        toolName: p['toolName'] as String? ?? '',
        argSummary: p['argSummary'] as String? ?? '',
        state: AgentToolCallState.values.byName(p['state'] as String),
        resultSummary: p['resultSummary'] as String? ?? '',
        elapsed: elapsedMs == null ? null : Duration(milliseconds: elapsedMs),
        argsDetail: p['argsDetail'] as String?,
        resultDetail: p['resultDetail'] as String?,
      );
    case 'plan_update':
      return PlanUpdateEvent(
        id: id,
        seq: seq,
        at: at,
        items: [
          for (final item in (p['items'] as List<dynamic>? ?? const []))
            AgentPlanItem(
              content: (item as Map<String, dynamic>)['content'] as String,
              status:
                  AgentPlanItemStatus.values.byName(item['status'] as String),
            ),
        ],
      );
    case 'compaction':
      return CompactionEvent(
        id: id,
        seq: seq,
        at: at,
        coveredCount: p['coveredCount'] as int? ?? 0,
        summary: p['summary'] as String? ?? '',
      );
    case 'status_change':
      return StatusChangeEvent(
        id: id,
        seq: seq,
        at: at,
        description: p['description'] as String? ?? '',
      );
    default:
      // 前向兼容：未知事件类型（旧版本读新库）降级为状态行展示。
      return StatusChangeEvent(
        id: id,
        seq: seq,
        at: at,
        description: '未知事件类型：$kind',
      );
  }
}
