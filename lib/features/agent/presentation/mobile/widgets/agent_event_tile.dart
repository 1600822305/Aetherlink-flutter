import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 时间线事件行（UI 稿 §4.1）：左轨节点区分事件类型
/// （●助手文字 ○工具 ⚠审批 ✂压缩 ◆状态变化），工具行默认收起单行。
class AgentEventTile extends StatelessWidget {
  const AgentEventTile({required this.event, this.onTap, super.key});

  final AgentEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (event) {
      final UserMessageEvent e => _UserMessageTile(event: e),
      final AssistantTextEvent e => _AssistantTextTile(event: e),
      final ToolCallEvent e when e.state == AgentToolCallState.waitingApproval =>
        _ApprovalCard(event: e),
      final ToolCallEvent e => _ToolRow(event: e, onTap: onTap),
      final CompactionEvent e => _CompactionDivider(event: e),
      final StatusChangeEvent e => _StatusChangeTile(event: e),
      PlanUpdateEvent() => const SizedBox.shrink(), // 由顶部计划纪要条渲染
    };
  }
}

/// 左轨：一条纵线 + 节点。
class _Rail extends StatelessWidget {
  const _Rail({required this.node, required this.child});

  final Widget node;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                node,
                Expanded(child: Container(width: 1.5, color: lineColor)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageTile extends StatelessWidget {
  const _UserMessageTile({required this.event});

  final UserMessageEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _Rail(
      node: Icon(LucideIcons.user, size: 14, color: cs.primary),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.queued)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '已排队 · 下一轮生效',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.primary),
                ),
              ),
            Text(event.text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _AssistantTextTile extends StatelessWidget {
  const _AssistantTextTile({required this.event});

  final AssistantTextEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Rail(
      node: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      child: Text(
        event.streaming ? '${event.text}▍' : event.text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }
}

/// 工具行（collapsed 单行）：图标+名称+关键参数+结果摘要；
/// 点击 → 底部抽屉看完整参数/输出（UI 阶段先占位）。
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.event, this.onTap});

  final ToolCallEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final (icon, iconColor) = switch (event.state) {
      AgentToolCallState.running => (LucideIcons.loaderCircle, cs.primary),
      AgentToolCallState.success => (LucideIcons.circleCheck, Colors.green),
      AgentToolCallState.failure => (LucideIcons.circleX, cs.error),
      AgentToolCallState.denied => (LucideIcons.ban, muted),
      AgentToolCallState.waitingApproval => (
          LucideIcons.circleAlert,
          Colors.orange
        ),
    };
    return _Rail(
      node: event.state == AgentToolCallState.running
          ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.primary),
            )
          : Icon(icon, size: 14, color: iconColor),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    event.toolName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.argSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (event.resultSummary.isNotEmpty)
                Text(
                  '↳ ${event.resultSummary}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: event.state == AgentToolCallState.failure
                        ? cs.error
                        : muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 审批卡（内嵌事件流）：摘要 + 批准/拒绝/白名单▾（UI 稿 §五）。
class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.event});

  final ToolCallEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const orange = Colors.orange;
    return _Rail(
      node: const Icon(LucideIcons.triangleAlert, size: 14, color: orange),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: orange.withValues(alpha: 0.5)),
          color: orange.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠ 等待授权',
              style: theme.textTheme.labelMedium?.copyWith(
                color: orange,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${event.toolName} ${event.argSummary}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('批准'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('拒绝'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('白名单 ▾'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactionDivider extends StatelessWidget {
  const _CompactionDivider({required this.event});

  final CompactionEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '✂ 已压缩 ${event.coveredCount} 条早期事件',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
          Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

class _StatusChangeTile extends StatelessWidget {
  const _StatusChangeTile({required this.event});

  final StatusChangeEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return _Rail(
      node: Icon(LucideIcons.diamond, size: 12, color: muted),
      child: Text(
        event.description,
        style: theme.textTheme.labelSmall?.copyWith(color: muted),
      ),
    );
  }
}

/// 已完成工作段的折叠摘要块：「▸ 工作了 36s · 14 个操作 · +17−7」，
/// 点开可回看每一行（UI 稿 §4.1 工作段折叠）。
class WorkSegmentTile extends StatefulWidget {
  const WorkSegmentTile({required this.events, super.key});

  final List<ToolCallEvent> events;

  @override
  State<WorkSegmentTile> createState() => _WorkSegmentTileState();
}

class _WorkSegmentTileState extends State<WorkSegmentTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasFailure =
        widget.events.any((e) => e.state == AgentToolCallState.failure);
    var totalMs = 0;
    for (final e in widget.events) {
      totalMs += e.elapsed?.inMilliseconds ?? 500;
    }
    final elapsed = formatElapsed(Duration(milliseconds: totalMs));
    final summaryColor =
        hasFailure ? cs.error : cs.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(left: 28, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronRight,
                  size: 14,
                  color: summaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '工作了 $elapsed · ${widget.events.length} 个操作'
                  '${hasFailure ? ' · ✗' : ''}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: summaryColor),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final e in widget.events) AgentEventTile(event: e),
      ],
    );
  }
}
