import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 状态色板（全局统一，UI 稿 §三）。
Color agentStatusColor(BuildContext context, AgentTaskStatus status) {
  final cs = Theme.of(context).colorScheme;
  return switch (status) {
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
      AgentSessionMode.ask => 'Ask',
      AgentSessionMode.plan => 'Plan',
    };

String formatTokens(int tokens) => tokens >= 1000
    ? '${(tokens / 1000).toStringAsFixed(1)}k'
    : tokens.toString();

String formatElapsed(Duration d) {
  if (d.inMinutes >= 1) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}

/// 顶栏下的常驻状态条：`● 运行中 · 第12轮 · 8.4k · 6m`（UI 稿 §4.1）。
class AgentStatusLine extends StatelessWidget {
  const AgentStatusLine({required this.task, super.key});

  final AgentTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = agentStatusColor(context, task.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(color: color, breathing: task.status == AgentTaskStatus.running),
        const SizedBox(width: 5),
        Text(
          '${agentStatusLabel(task.status)} · 第${task.rounds}轮 · '
          '${formatTokens(task.tokenCount)} · ${formatElapsed(task.elapsed)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
