import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 计划纪要条（可折叠）：`▤ 计划 3/5 ▸`；点开=完整 todo + 任务信息卡
/// （UI 稿 §4.2，取代原独立计划页）。
class PlanPanel extends StatefulWidget {
  const PlanPanel({required this.task, required this.plan, super.key});

  final AgentTask task;
  final PlanUpdateEvent plan;

  @override
  State<PlanPanel> createState() => _PlanPanelState();
}

class _PlanPanelState extends State<PlanPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = widget.plan.items;
    final done = items
        .where((i) => i.status == AgentPlanItemStatus.completed)
        .length;

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.listTodo,
                    size: 15,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '计划 $done/${items.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
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
        cs.onSurface.withValues(alpha: 0.35),
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
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
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
