import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// ask_user 提问卡：支持单选、多选、自定义文本和多问题一次提交。
class UserQuestionTile extends ConsumerStatefulWidget {
  const UserQuestionTile({
    required this.event,
    required this.taskId,
    super.key,
  });

  final UserQuestionEvent event;
  final String taskId;

  @override
  ConsumerState<UserQuestionTile> createState() => _UserQuestionTileState();
}

class _UserQuestionTileState extends ConsumerState<UserQuestionTile> {
  late final List<Set<String>> _selected = [
    for (final _ in widget.event.questions) <String>{},
  ];
  late final List<TextEditingController> _customControllers = [
    for (final _ in widget.event.questions) TextEditingController(),
  ];
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _customControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<AgentUserQuestionAnswer>? _answers() {
    final answers = <AgentUserQuestionAnswer>[];
    for (var i = 0; i < widget.event.questions.length; i++) {
      final values = <String>[..._selected[i]];
      final custom = _customControllers[i].text.trim();
      if (custom.isNotEmpty) values.add(custom);
      if (values.isEmpty) return null;
      answers.add(AgentUserQuestionAnswer(questionIndex: i, values: values));
    }
    return answers;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final answers = _answers();
    if (answers == null) return;
    final task = ref
        .read(agentTasksProvider)
        .where((task) => task.id == widget.taskId)
        .firstOrNull;
    if (task == null) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .answerUserQuestion(task, widget.event, answers);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _selectOption(int index, String option) async {
    final question = widget.event.questions[index];
    setState(() {
      if (question.allowMultiple) {
        if (!_selected[index].remove(option)) {
          _selected[index].add(option);
        }
      } else {
        _selected[index]
          ..clear()
          ..add(option);
        _customControllers[index].clear();
      }
    });
    if (widget.event.questions.length == 1 && !question.allowMultiple) {
      await _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final task = ref
        .watch(agentTasksProvider)
        .where((task) => task.id == widget.taskId)
        .firstOrNull;
    final events =
        ref.watch(agentTaskEventsProvider(widget.taskId)).value ?? const [];
    final answer = userQuestionAnswer(widget.event, events);
    final pending = latestPendingUserQuestion(events);
    final active = task?.status == AgentTaskStatus.waitingInput &&
        pending?.id == widget.event.id &&
        answer == null;

    return EventRail(
      node: Icon(
        answer == null ? LucideIcons.circleHelp : LucideIcons.circleCheck,
        size: 14,
        color: cs.primary,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.primary.withValues(alpha: active ? 0.55 : 0.25),
          ),
          color: cs.primary.withValues(alpha: active ? 0.07 : 0.035),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  answer == null
                      ? LucideIcons.messageCircleQuestion
                      : LucideIcons.messageCircleCheck,
                  size: 16,
                  color: cs.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  answer != null
                      ? '已回答'
                      : active
                          ? '需要你的回答'
                          : '提问',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (answer != null)
              _AnsweredQuestions(event: widget.event, answer: answer)
            else
              for (var i = 0; i < widget.event.questions.length; i++) ...[
                if (i > 0) const Divider(height: 28),
                _QuestionEditor(
                  index: i,
                  total: widget.event.questions.length,
                  question: widget.event.questions[i],
                  enabled: active && !_submitting,
                  selected: _selected[i],
                  customController: _customControllers[i],
                  onSelect: (option) => _selectOption(i, option),
                  onCustomChanged: (value) {
                    if (!widget.event.questions[i].allowMultiple &&
                        value.trim().isNotEmpty) {
                      setState(_selected[i].clear);
                    } else {
                      setState(() {});
                    }
                  },
                ),
              ],
            if (active) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: !_submitting && _answers() != null ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(_submitting ? '正在提交…' : '提交回答'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.total,
    required this.question,
    required this.enabled,
    required this.selected,
    required this.customController,
    required this.onSelect,
    required this.onCustomChanged,
  });

  final int index;
  final int total;
  final AgentUserQuestion question;
  final bool enabled;
  final Set<String> selected;
  final TextEditingController customController;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onCustomChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total > 1 ? '${index + 1}. ${question.question}' : question.question,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (question.allowMultiple) ...[
          const SizedBox(height: 3),
          Text(
            '可多选',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in question.options)
                FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: enabled ? (_) => onSelect(option) : null,
                  showCheckmark: question.allowMultiple,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: customController,
          enabled: enabled,
          minLines: 1,
          maxLines: 4,
          onChanged: onCustomChanged,
          decoration: InputDecoration(
            hintText: question.options.isEmpty ? '输入回答…' : '其他（自定义回答）',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _AnsweredQuestions extends StatelessWidget {
  const _AnsweredQuestions({required this.event, required this.answer});

  final UserQuestionEvent event;
  final UserMessageEvent answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answersByIndex = {
      for (final item in answer.questionAnswers)
        item.questionIndex: item.values,
    };
    if (answersByIndex.isEmpty) {
      return Text(answer.text, style: theme.textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < event.questions.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(event.questions[i].question, style: theme.textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(
            answersByIndex[i]?.join('、') ?? '未回答',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
