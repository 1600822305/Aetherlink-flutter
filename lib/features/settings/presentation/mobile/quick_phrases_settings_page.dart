import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/quick_phrases_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/domain/quick_phrase.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_button_catalog.dart';

/// The 快捷短语管理 page (设置 → 快捷方式 → 快捷短语), a port of the original
/// `src/components/quick-phrase/QuickPhraseSettings.tsx`.
///
/// Manages the global (assistant-independent) phrases — full CRUD plus the
/// 在输入框显示快捷短语按钮 display toggle — recomposed into the project's compact
/// settings style. The list and toggle persist to the Drift KV store via
/// [GlobalQuickPhrases] / [ShowQuickPhraseButton]; assistant-scoped phrases are
/// managed separately (on the assistant) and are not shown here.
class QuickPhrasesSettingsPage extends ConsumerWidget {
  const QuickPhrasesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final phrases = ref.watch(globalQuickPhrasesProvider);
    final showButton = ref.watch(showQuickPhraseButtonProvider);
    final list = phrases.asData?.value ?? const <QuickPhrase>[];

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: '快捷短语管理',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
      ),
      floatingActionButton: list.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openEditor(context, ref),
              tooltip: '添加快捷短语',
              child: const Icon(LucideIcons.plus),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              '管理您的快捷短语，在聊天时快速插入常用内容。',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _displaySettingsCard(context, ref, showButton),
          const SizedBox(height: 16),
          if (phrases.isLoading && list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            _emptyState(context, ref)
          else
            for (final phrase in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PhraseCard(
                  phrase: phrase,
                  onEdit: () => _openEditor(context, ref, editing: phrase),
                  onDelete: () => _confirmDelete(context, ref, phrase),
                ),
              ),
        ],
      ),
    );
  }

  Widget _displaySettingsCard(
    BuildContext context,
    WidgetRef ref,
    bool showButton,
  ) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '显示设置',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '在输入框显示快捷短语按钮',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              CustomSwitch(
                value: showButton,
                onChanged: (v) => ref
                    .read(showQuickPhraseButtonProvider.notifier)
                    .setShown(v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '控制是否在聊天输入框中显示快捷短语按钮',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Opacity(
            opacity: 0.3,
            child: inputBoxMenuIcon(
              InputBoxAction.quickPhrase,
              color: theme.colorScheme.onSurface,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有快捷短语',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '创建您的第一个快捷短语，让聊天更高效',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context, ref),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('添加快捷短语'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    QuickPhrase? editing,
  }) async {
    final result = await showDialog<_PhraseDraft>(
      context: context,
      builder: (_) => _PhraseDialog(editing: editing),
    );
    if (result == null) return;
    final notifier = ref.read(globalQuickPhrasesProvider.notifier);
    if (editing == null) {
      await notifier.add(title: result.title, content: result.content);
    } else {
      await notifier.edit(
        editing.id,
        title: result.title,
        content: result.content,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    QuickPhrase phrase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('确定要删除这个快捷短语吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(globalQuickPhrasesProvider.notifier).delete(phrase.id);
    }
  }
}

/// One phrase row (the original's bordered `ListItem`): 标题 + a 字符数 chip, a
/// 2-line content preview and the 编辑 / 删除 actions.
class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.phrase,
    required this.onEdit,
    required this.onDelete,
  });

  final QuickPhrase phrase;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        phrase.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CountChip(count: phrase.content.length),
                  ],
                ),
                if (phrase.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    phrase.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.squarePen,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.trash2,
              size: 18,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// The outlined 「N 字符」 chip next to a phrase's title.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        '$count 字符',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PhraseDraft {
  const _PhraseDraft({required this.title, required this.content});

  final String title;
  final String content;
}

/// The 添加 / 编辑快捷短语 form (port of the original's dialog): a 标题 / 内容 pair, a
/// live 内容长度 info banner and 保存 disabled until both fields are non-blank.
class _PhraseDialog extends StatefulWidget {
  const _PhraseDialog({this.editing});

  final QuickPhrase? editing;

  @override
  State<_PhraseDialog> createState() => _PhraseDialogState();
}

class _PhraseDialogState extends State<_PhraseDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.editing?.title ?? '',
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.editing?.content ?? '',
  );

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
    _content.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _title.text.trim().isNotEmpty && _content.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      _PhraseDraft(title: _title.text.trim(), content: _content.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.editing != null;
    final contentLength = _content.text.length;

    return AlertDialog(
      title: Text(isEdit ? '编辑快捷短语' : '添加快捷短语'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '为您的快捷短语起个名字',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '输入快捷短语的内容...',
                alignLabelWithHint: true,
              ),
            ),
            if (contentLength > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '内容长度：$contentLength 字符',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(isEdit ? '更新' : '添加'),
        ),
      ],
    );
  }
}
