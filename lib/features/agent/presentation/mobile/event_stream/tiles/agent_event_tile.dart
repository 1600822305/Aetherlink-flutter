import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/finish_guards.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/approval_card.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/assistant_text_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/checkpoint_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/completion_card.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/compaction_divider.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/plan_approval_card.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/plan_update_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/reasoning_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/status_change_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/subagent_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/system_hint_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/tool_row.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/user_message_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/user_question_tile.dart';

/// 时间线事件行分发器（UI 稿 §4.1）：按事件类型路由到对应小件
/// （●助手文字 ○工具 ⚠审批 ✂压缩 ◆状态变化）。
class AgentEventTile extends StatelessWidget {
  const AgentEventTile({required this.event, required this.taskId, super.key});

  final AgentEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return switch (event) {
      // 引擎注入的 [系统] 提示是给模型看的：折叠成一行提示条，点开看全文。
      final UserMessageEvent e when FinishGuards.isEngineInjected(e.text) =>
        SystemHintTile(event: e),
      final UserMessageEvent e => UserMessageTile(event: e),
      final UserQuestionEvent e => UserQuestionTile(event: e, taskId: taskId),
      final AssistantTextEvent e => AssistantTextTile(event: e),
      final ReasoningEvent e => ReasoningTile(event: e),
      final ToolCallEvent e
          when e.state == AgentToolCallState.waitingApproval &&
              e.toolName == kToolExitPlanMode =>
        PlanApprovalCard(event: e, taskId: taskId),
      final ToolCallEvent e
          when e.state == AgentToolCallState.waitingApproval =>
        ApprovalCard(event: e, taskId: taskId),
      final ToolCallEvent e when e.toolName == kToolAttemptCompletion =>
        CompletionCard(key: ValueKey('completion_${e.id}'), event: e),
      final ToolCallEvent e when e.toolName == kToolSpawnSubagent =>
        SubagentTile(event: e),
      final ToolCallEvent e => ToolRow(event: e, taskId: taskId),
      final CompactionEvent e => CompactionDivider(event: e, taskId: taskId),
      final CheckpointEvent e => CheckpointTile(event: e, taskId: taskId),
      final StatusChangeEvent e => StatusChangeTile(event: e),
      final PlanUpdateEvent e => PlanUpdateTile(event: e),
    };
  }
}
