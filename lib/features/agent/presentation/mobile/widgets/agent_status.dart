import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 状态色板（全局统一，UI 稿 §三）。
Color agentStatusColor(BuildContext context, AgentTaskStatus status) {
  final cs = Theme.of(context).colorScheme;
  return switch (status) {
    AgentTaskStatus.draft => cs.onSurface.withValues(alpha: 0.25),
    AgentTaskStatus.running => cs.primary,
    AgentTaskStatus.waitingApproval => Colors.orange,
    AgentTaskStatus.waitingInput => Colors.blue,
    AgentTaskStatus.paused => cs.onSurface.withValues(alpha: 0.4),
    AgentTaskStatus.done => Colors.green,
    AgentTaskStatus.failed => cs.error,
    AgentTaskStatus.cancelled => cs.onSurface.withValues(alpha: 0.4),
  };
}

String agentStatusLabel(AgentTaskStatus status) => switch (status) {
      AgentTaskStatus.draft => '未开始',
      AgentTaskStatus.running => '运行中',
      AgentTaskStatus.waitingApproval => '等待授权',
      AgentTaskStatus.waitingInput => '等待回答',
      AgentTaskStatus.paused => '已暂停',
      AgentTaskStatus.done => '已完成',
      AgentTaskStatus.failed => '失败',
      AgentTaskStatus.cancelled => '已取消',
    };

String agentModeLabel(AgentSessionMode mode) => switch (mode) {
      AgentSessionMode.code => 'Code',
      AgentSessionMode.auto => 'Auto',
      AgentSessionMode.ask => 'Ask',
      AgentSessionMode.plan => 'Plan',
    };

/// auto 模式醒目徽标（琥珀色胶囊）：提醒当前任务在工作区内
/// 免审批执行，挂在状态条、输入区等显示位。
class AgentAutoBadge extends StatelessWidget {
  const AgentAutoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.shade700, width: 0.8),
      ),
      child: Text(
        'AUTO',
        style: TextStyle(
          fontSize: 9,
          height: 1.3,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.amber.shade800,
        ),
      ),
    );
  }
}

String formatTokens(int tokens) => tokens >= 1000
    ? '${(tokens / 1000).toStringAsFixed(1)}k'
    : tokens.toString();

String formatElapsed(Duration d) {
  if (d.inMinutes >= 1) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}

/// 顶栏下的常驻状态条：`● 运行中 · 第12轮 · 累计8.4k · 上下文12k/128k · 6m`
/// （UI 稿 §4.1）。
class AgentStatusLine extends ConsumerWidget {
  const AgentStatusLine({required this.task, super.key});

  final AgentTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = agentStatusColor(context, task.status);
    final limit = ref.watch(
      agentUiSettingsControllerProvider.select((s) => s.contextLimit),
    );
    final contextInfo = task.contextTokens > 0
        ? ' · 上下文${formatTokens(task.contextTokens)}/${formatTokens(limit)}'
        : '';
    // 运行中且计划有进行中条目时，状态文案改为该条目
    // （对标 CC spinner 用 activeForm 驱动动词）。
    String statusText = agentStatusLabel(task.status);
    if (task.status == AgentTaskStatus.running) {
      final events =
          ref.watch(agentTaskEventsProvider(task.id)).value ?? const [];
      PlanUpdateEvent? plan;
      for (final e in events) {
        if (e is PlanUpdateEvent) plan = e;
      }
      final active = plan?.items
          .where((it) => it.status == AgentPlanItemStatus.inProgress)
          .firstOrNull;
      if (active != null && active.content.isNotEmpty) {
        statusText = active.content;
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(color: color, breathing: task.status == AgentTaskStatus.running),
        const SizedBox(width: 5),
        if (task.mode == AgentSessionMode.auto) ...[
          const AgentAutoBadge(),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            '$statusText · 第${task.rounds}轮'
            '$contextInfo · '
            '${formatElapsed(task.elapsed)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// 状态色点；running 时呼吸动效。
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.breathing});

  final Color color;
  final bool breathing;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.breathing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breathing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.breathing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.breathing
          ? Tween(begin: 0.35, end: 1.0).animate(_controller)
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
