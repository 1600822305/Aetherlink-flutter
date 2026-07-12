import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// Plan 模式收尾后的「方案已就绪」卡（设计初稿 §七）：Plan 任务 done 时
/// 展示在事件流末尾，一键转 Code 继续执行；需要改方案直接在下方输入继续讨论。
class PlanReadyCard extends ConsumerWidget {
  const PlanReadyCard({required this.task, super.key});

  final AgentTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.clipboardCheck,
                      size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '方案已就绪',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '确认后切换到 Code 模式按方案执行；需要修改方案，直接在下方输入继续讨论。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(agentTaskRunnerProvider.notifier)
                      .convertPlanToCode(task),
                  icon: const Icon(LucideIcons.play, size: 16),
                  label: const Text('转 Code 执行'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
