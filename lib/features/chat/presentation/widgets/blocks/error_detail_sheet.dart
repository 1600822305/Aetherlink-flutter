import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/chat_error.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens the 错误详情 sheet for [error]: a one-tap 复制全部 (the Markdown report
/// from [ChatError.toReport]) at the top, then the summary / context / retries /
/// stack trace as separately copyable sections.
Future<void> showErrorDetailSheet(BuildContext context, ChatError error) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ErrorDetailSheet(error: error),
  );
}

Future<void> copyErrorReport(BuildContext context, ChatError error) async {
  await Clipboard.setData(ClipboardData(text: error.toReport()));
  if (context.mounted) AppToast.info(context, '已复制错误报告');
}

class ErrorDetailSheet extends StatelessWidget {
  const ErrorDetailSheet({required this.error, super.key});

  final ChatError error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = <_Section>[
      _Section(
        title: '错误信息',
        body: error.message,
        rows: [
          ('异常类型', error.type),
          if (error.statusCode != null) ('HTTP 状态', '${error.statusCode}'),
          ('阶段', _phaseLabel(error.phase)),
          ('时间', error.occurredAt.toLocal().toString()),
        ],
      ),
      _Section(
        title: '上下文',
        rows: [
          if (error.providerLabel != null) ('提供商', error.providerLabel!),
          if (error.modelLabel != null) ('模型', error.modelLabel!),
          if (error.round != null) ('轮次', '${error.round}'),
          if (error.toolName != null) ('工具', error.toolName!),
          if (error.appVersion != null) ('应用版本', error.appVersion!),
          if (error.platform != null) ('平台', error.platform!),
        ],
      ),
      if (error.toolArguments != null)
        _Section(title: '工具参数', body: error.toolArguments, monospace: true),
      if (error.attempts.isNotEmpty)
        _Section(
          title: '之前的重试',
          body: [
            for (final a in error.attempts)
              '#${a.attempt}${a.keyId != null ? ' (key ${a.keyId})' : ''} '
                  '${a.type}: ${a.message}',
          ].join('\n'),
        ),
      _Section(
        title: '堆栈',
        body: error.stackTrace ?? '（未捕获到堆栈）',
        monospace: true,
        copyable: error.stackTrace != null,
      ),
    ].where((s) => s.body != null || s.rows.isNotEmpty).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Icon(LucideIcons.circleAlert, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('错误详情', style: theme.textTheme.titleMedium),
                ),
                FilledButton.icon(
                  onPressed: () => copyErrorReport(context, error),
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const Text('复制全部'),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  _SectionView(section: sections[index]),
            ),
          ),
        ],
      ),
    );
  }

  static String _phaseLabel(ChatErrorPhase phase) => switch (phase) {
    ChatErrorPhase.request => '请求（尚未收到内容）',
    ChatErrorPhase.stream => '流式响应',
    ChatErrorPhase.tool => '工具执行',
    ChatErrorPhase.media => '媒体生成',
    ChatErrorPhase.interrupted => '应用退出中断',
  };
}

class _Section {
  const _Section({
    required this.title,
    this.body,
    this.rows = const [],
    this.monospace = false,
    this.copyable = true,
  });

  final String title;
  final String? body;
  final List<(String, String)> rows;
  final bool monospace;
  final bool copyable;

  String get clipboardText =>
      [for (final (k, v) in rows) '$k: $v', if (body != null) body!].join('\n');
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bodyStyle = section.monospace
        ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
        : theme.textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                section.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (section.copyable)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '复制本节',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: section.clipboardText),
                  );
                  if (context.mounted) {
                    AppToast.info(context, '已复制「${section.title}」');
                  }
                },
                icon: const Icon(LucideIcons.copy, size: 16),
              ),
          ],
        ),
        for (final (label, value) in section.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 72, child: Text(label, style: labelStyle)),
                Expanded(child: SelectableText(value)),
              ],
            ),
          ),
        if (section.body != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(section.body!, style: bodyStyle),
          ),
      ],
    );
  }
}
