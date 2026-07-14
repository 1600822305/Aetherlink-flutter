import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// ask_user 建议答案面板（RooCode ask_followup_question 风格）：任务
/// 等待回答时浮在输入框上方，问题 + 整行建议答案按钮，点选即提交；
/// 自定义回答走输入框。无待答提问时不占位。
class AgentFollowupPanel extends ConsumerStatefulWidget {
  const AgentFollowupPanel({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<AgentFollowupPanel> createState() =>
      _AgentFollowupPanelState();
}

class _AgentFollowupPanelState extends ConsumerState<AgentFollowupPanel> {
  bool _submitting = false;

  Future<void> _submit(UserQuestionEvent question, String answer) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .answerUserQuestion(widget.task, question, answer);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.status != AgentTaskStatus.waitingInput) {
      return const SizedBox.shrink();
    }
    final events =
        ref.watch(agentTaskEventsProvider(widget.task.id)).value ?? const [];
    final question = latestPendingUserQuestion(events);
    if (question == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.messageCircleQuestion,
                  size: 14,
                  color: cs.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    question.question,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_submitting)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            for (final (index, suggestion)
                in question.suggestions.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => _submit(question, suggestion),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: cs.primary.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: theme.textTheme.bodySmall,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          String.fromCharCode(0x41 + index),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(suggestion, textAlign: TextAlign.left),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '或在下方输入框输入自定义回答',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
