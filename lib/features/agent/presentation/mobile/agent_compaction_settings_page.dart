// 上下文压缩设置页（压缩设置页 v1）：自动压缩开关/触发比例/保留量、
// microcompact 开关/阈值、保护与熔断只读展示、手动压缩入口。
// 语义强调：压缩只影响进入模型的上下文视图，事件流原文保留可审计。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_compaction_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_guard.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 打开上下文压缩设置页（零动画，同 hooks 页）。
Future<void> showAgentCompactionSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const AgentCompactionSettingsPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// 手动压缩确认弹窗 + 执行 + toast（settings tab 与压缩设置页共用，
/// 两处行为一致）。
Future<void> confirmAndCompactNow(
  BuildContext context,
  WidgetRef ref,
  AgentTask task,
) async {
  final runner = ref.read(agentTaskRunnerProvider.notifier);
  final instructionsController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('立即压缩'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '把较早的执行过程压缩为一段摘要，释放上下文空间。'
            '摘要只影响进入模型的上下文，事件流原文保留可审计。'
            '运行中任务将在下一个安全点执行。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: instructionsController,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              labelText: '摘要关注点（可选）',
              hintText: '如：重点保留报错细节和文件路径',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('开始压缩'),
        ),
      ],
    ),
  );
  final instructions = instructionsController.text.trim();
  instructionsController.dispose();
  if (confirmed != true || !context.mounted) return;
  try {
    final message = await runner.compactNow(
      task,
      customInstructions: instructions.isEmpty ? null : instructions,
    );
    if (context.mounted) AppToast.success(context, message);
  } catch (e) {
    if (context.mounted) AppToast.error(context, '压缩失败 · $e');
  }
}

class AgentCompactionSettingsPage extends ConsumerWidget {
  const AgentCompactionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(agentCompactionSettingsProvider);
    final notifier = ref.read(agentCompactionSettingsProvider.notifier);
    final contextLimit = ref
        .watch(agentUiSettingsControllerProvider)
        .contextLimit;
    final taskId = ref.watch(selectedAgentTaskIdProvider);
    final task = ref
        .watch(agentTasksProvider)
        .where((t) => t.id == taskId)
        .firstOrNull;
    final compactableTask = task != null && task.status != AgentTaskStatus.draft
        ? task
        : null;

    final triggerTokens = compactionTriggerTokens(
      contextLimit,
      triggerRatio: settings.triggerRatio,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('上下文压缩'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '压缩只影响进入模型的上下文视图，事件流原文永远保留、可审计。'
            '自动压缩在上下文接近窗口上限时把较早内容摘要化；'
            '轻量清理不调模型，只把较旧的可重取工具输出替换成占位符。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '自动压缩',
            children: [
              _SwitchRow(
                title: '自动压缩',
                description:
                    '上下文达到触发阈值时自动摘要化较早内容；'
                    '关闭后仍会预警，手动压缩不受影响',
                value: settings.autoCompactEnabled,
                onChanged: (v) =>
                    notifier.set(settings.copyWith(autoCompactEnabled: v)),
              ),
              _ChipSelectRow<double>(
                title: '触发比例',
                description: '占有效窗口（窗口减摘要预留）的比例，达到即触发',
                value: settings.triggerRatio,
                options: const [
                  (0.85, '85%'),
                  (0.90, '90%'),
                  (0.92, '92%'),
                  (0.95, '95%'),
                ],
                onChanged: (v) =>
                    notifier.set(settings.copyWith(triggerRatio: v)),
              ),
              _ChipSelectRow<int>(
                title: '压缩保留量',
                description: '压缩后保留给近期内容的字符预算，其余摘要化',
                value: settings.keepChars,
                options: const [(20000, '20k'), (40000, '40k'), (60000, '60k')],
                onChanged: (v) => notifier.set(settings.copyWith(keepChars: v)),
              ),
              _ReadonlyRow(
                title: '当前换算',
                value:
                    '窗口 ${_formatK(contextLimit)} → '
                    '约 ${_formatK(triggerTokens)} tokens 触发',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '轻量清理（microcompact）',
            children: [
              _SwitchRow(
                title: '轻量清理',
                description:
                    '不调模型：超阈值时把较旧的可重取工具输出'
                    '（终端/读文件/搜索等）替换成占位符，事件流原文保留',
                value: settings.microCompactEnabled,
                onChanged: (v) =>
                    notifier.set(settings.copyWith(microCompactEnabled: v)),
              ),
              _ChipSelectRow<int>(
                title: '触发阈值',
                description:
                    '上下文字符量超过该值时开始清理（低于压缩阈值，'
                    '构成先轻量后摘要的两级降压）',
                value: settings.microCompactTriggerChars,
                options: const [
                  (60000, '60k'),
                  (80000, '80k'),
                  (100000, '100k'),
                ],
                onChanged: (v) => notifier.set(
                  settings.copyWith(microCompactTriggerChars: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '保护与熔断（固定策略）',
            children: [
              _ReadonlyRow(
                title: '压缩预警',
                value:
                    '达到触发阈值的 '
                    '${(kCompactionWarningRatio * 100).round()}% 时提示一次',
              ),
              const _ReadonlyRow(
                title: '失败熔断',
                value:
                    '连续 $kCompactionMaxConsecutiveFailures 次压缩失败后'
                    '本任务内停止重试',
              ),
              const _ReadonlyRow(
                title: '近期保护',
                value:
                    '最近 $kMicroCompactKeepRecentToolCalls 条工具输出'
                    '永不清除',
              ),
              _ReadonlyRow(
                title: '摘要预留',
                value:
                    '为压缩摘要输出预留 '
                    '${_formatK(kCompactionSummaryReserveTokens)} tokens'
                    '（小窗口按 1/4 封顶）',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '手动压缩',
            children: [
              _EntryRow(
                title: '立即压缩',
                description: compactableTask != null
                    ? '把当前话题较早内容压缩成摘要释放上下文'
                    : '没有可压缩的话题（先在智能体首页选择一个已开始的话题）',
                enabled: compactableTask != null,
                onTap: compactableTask == null
                    ? null
                    : () => confirmAndCompactNow(context, ref, compactableTask),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatK(int tokens) => tokens >= 1000000
    ? '${(tokens / 1000000).toStringAsFixed(tokens % 1000000 == 0 ? 0 : 1)}M'
    : tokens >= 1000
    ? '${(tokens / 1000).toStringAsFixed(tokens % 1000 == 0 ? 0 : 1)}k'
    : '$tokens';

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _RowText(title: title, description: description),
          ),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChipSelectRow<T> extends StatelessWidget {
  const _ChipSelectRow({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String description;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowText(title: title, description: description),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final (v, label) in options)
                ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: v == value ? FontWeight.w600 : null,
                      color: v == value ? cs.primary : null,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  selected: v == value,
                  selectedColor: cs.primary.withValues(alpha: 0.15),
                  checkmarkColor: cs.primary,
                  side: v == value
                      ? BorderSide(color: cs.primary)
                      : BorderSide(color: cs.onSurface.withValues(alpha: 0.15)),
                  onSelected: (_) => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  const _ReadonlyRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(title, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.title,
    required this.description,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Row(
            children: [
              Expanded(
                child: _RowText(title: title, description: description),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          description,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
