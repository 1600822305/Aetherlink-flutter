import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_event_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_input_bar.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 左页：事件流主视图（UI 稿 §4.1）——计划纪要条 + 时间线 + 底部输入区。
class EventStreamPage extends ConsumerWidget {
  const EventStreamPage({required this.task, super.key});

  final AgentTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(agentTaskEventsProvider(task.id));
    final plan = _latestPlan(events);
    final blocks = _buildBlocks(events);

    return Column(
      children: [
        if (plan != null) _PlanStrip(task: task, plan: plan),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: blocks.length,
            itemBuilder: (context, i) => switch (blocks[i]) {
              final _SegmentBlock b => WorkSegmentTile(events: b.events),
              final _SingleBlock b => AgentEventTile(event: b.event),
            },
          ),
        ),
        AgentInputBar(task: task),
      ],
    );
  }

  PlanUpdateEvent? _latestPlan(List<AgentEvent> events) {
    PlanUpdateEvent? plan;
    for (final e in events) {
      if (e is PlanUpdateEvent) plan = e;
    }
    return plan;
  }

  /// 工作段折叠（UI 稿 §4.1）：连续 ≥3 条**已完结**（success/failure/denied）
  /// 的工具调用折叠成摘要块；执行中/待审批的工具行保持实况展开。
  List<_TimelineBlock> _buildBlocks(List<AgentEvent> events) {
    final blocks = <_TimelineBlock>[];
    var run = <ToolCallEvent>[];

    void flush() {
      if (run.length >= 3) {
        blocks.add(_SegmentBlock(run));
      } else {
        blocks.addAll(run.map(_SingleBlock.new));
      }
      run = [];
    }

    for (final e in events) {
      final finishedTool = e is ToolCallEvent &&
          (e.state == AgentToolCallState.success ||
              e.state == AgentToolCallState.failure ||
              e.state == AgentToolCallState.denied);
      if (finishedTool) {
        run.add(e);
      } else {
        flush();
        if (e is! PlanUpdateEvent) blocks.add(_SingleBlock(e));
      }
    }
    flush();
    return blocks;
  }
}

sealed class _TimelineBlock {
  const _TimelineBlock();
}

class _SingleBlock extends _TimelineBlock {
  const _SingleBlock(this.event);

  final AgentEvent event;
}

class _SegmentBlock extends _TimelineBlock {
  const _SegmentBlock(this.events);

  final List<ToolCallEvent> events;
}

/// 计划纪要条（可折叠）：`▤ 计划 3/5 ▸`；点开=完整 todo + 任务信息卡
/// （UI 稿 §4.2，取代原独立计划页）。
class _PlanStrip extends StatefulWidget {
  const _PlanStrip({required this.task, required this.plan});

  final AgentTask task;
  final PlanUpdateEvent plan;

  @override
  State<_PlanStrip> createState() => _PlanStripState();
}

class _PlanStripState extends State<_PlanStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = widget.plan.items;
    final done =
        items.where((i) => i.status == AgentPlanItemStatus.completed).length;

    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.listTodo,
                      size: 15, color: cs.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(
                    '计划 $done/${items.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in items) _PlanItemRow(item: item),
                  const SizedBox(height: 8),
                  _TaskInfoCard(task: widget.task),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanItemRow extends StatelessWidget {
  const _PlanItemRow({required this.item});

  final AgentPlanItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (icon, color) = switch (item.status) {
      AgentPlanItemStatus.completed => (LucideIcons.circleCheck, Colors.green),
      AgentPlanItemStatus.inProgress => (LucideIcons.circleDot, cs.primary),
      AgentPlanItemStatus.pending => (
          LucideIcons.circle,
          cs.onSurface.withValues(alpha: 0.35)
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.content,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: item.status == AgentPlanItemStatus.inProgress
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: item.status == AgentPlanItemStatus.completed
                    ? cs.onSurface.withValues(alpha: 0.5)
                    : cs.onSurface,
                decoration: item.status == AgentPlanItemStatus.completed
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务信息卡：工作区/模型/模式/token 轮数累计（UI 稿 §4.2）。
class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.task});

  final AgentTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    Widget row(IconData icon, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, size: 13, color: muted),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(LucideIcons.folderTree, task.workspaceName),
          row(LucideIcons.brain, task.modelLabel),
          row(LucideIcons.keyboard, agentModeLabel(task.mode)),
          row(
            LucideIcons.activity,
            '第${task.rounds}轮 · ${formatTokens(task.tokenCount)} tokens · '
            '${formatElapsed(task.elapsed)}',
          ),
        ],
      ),
    );
  }
}
