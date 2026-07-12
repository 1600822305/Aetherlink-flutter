import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/plan_panel.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/agent_event_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/work_segment_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/working_indicator_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_input_bar.dart';

/// 左页：事件流主视图（UI 稿 §4.1）——计划纪要条 + 时间线 + 底部输入区。
class EventStreamPage extends ConsumerWidget {
  const EventStreamPage({required this.task, super.key});

  final AgentTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(agentTaskEventsProvider(task.id)).value ?? const [];
    final plan = latestPlan(events);
    final blocks = buildTimelineBlocks(events);
    final showWorking = task.status == AgentTaskStatus.running &&
        needsWorkingIndicator(events);

    return Column(
      children: [
        if (plan != null) PlanPanel(task: task, plan: plan),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: blocks.length + (showWorking ? 1 : 0),
            itemBuilder: (context, i) => i >= blocks.length
                ? const WorkingIndicatorTile()
                : switch (blocks[i]) {
                    final SegmentBlock b => WorkSegmentTile(events: b.events),
                    final SingleBlock b => AgentEventTile(event: b.event),
                  },
          ),
        ),
        AgentInputBar(task: task),
      ],
    );
  }
}
