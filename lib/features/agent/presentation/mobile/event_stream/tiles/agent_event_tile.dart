import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/approval_card.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/assistant_text_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/compaction_divider.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/status_change_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/tool_row.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/user_message_tile.dart';

/// 时间线事件行分发器（UI 稿 §4.1）：按事件类型路由到对应小件
/// （●助手文字 ○工具 ⚠审批 ✂压缩 ◆状态变化）。
class AgentEventTile extends StatelessWidget {
  const AgentEventTile({required this.event, super.key});

  final AgentEvent event;

  @override
  Widget build(BuildContext context) {
    return switch (event) {
      final UserMessageEvent e => UserMessageTile(event: e),
      final AssistantTextEvent e => AssistantTextTile(event: e),
      final ToolCallEvent e
          when e.state == AgentToolCallState.waitingApproval =>
        ApprovalCard(event: e),
      final ToolCallEvent e => ToolRow(event: e),
      final CompactionEvent e => CompactionDivider(event: e),
      final StatusChangeEvent e => StatusChangeTile(event: e),
      PlanUpdateEvent() => const SizedBox.shrink(), // 由顶部计划纪要条渲染
    };
  }
}
