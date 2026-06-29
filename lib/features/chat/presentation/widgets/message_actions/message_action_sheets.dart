import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';

/// The bottom sheets and tiles shared by every message-action surface (toolbar
/// 模式 and 气泡模式). They were extracted verbatim from the original
/// `message_toolbar.dart` so both rendering layers can open the same 编辑 /
/// 翻译 / 版本历史 UIs through [MessageActionsBuilder].

/// The 编辑 bottom drawer (`MessageEditor`): one multiline field per `main_text`
/// block with 取消/保存 actions. Pops a `{blockId: content}` map on save.
class MessageEditorSheet extends StatefulWidget {
  const MessageEditorSheet({
    required this.isUser,
    required this.blocks,
    super.key,
  });

  final bool isUser;
  final List<MainTextBlock> blocks;

  @override
  State<MessageEditorSheet> createState() => _MessageEditorSheetState();
}

class _MessageEditorSheetState extends State<MessageEditorSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final block in widget.blocks)
        TextEditingController(text: block.content),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasContent =>
      _controllers.any((controller) => controller.text.trim().isNotEmpty);

  void _save() {
    final result = <String, String>{};
    for (var i = 0; i < widget.blocks.length; i++) {
      final text = _controllers[i].text.trim();
      if (text.isNotEmpty) result[widget.blocks[i].id] = text;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multi = widget.blocks.length > 1;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '编辑${widget.isUser ? '消息' : '回复'}',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (multi) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${widget.blocks.length} 个文本块)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _controllers.length; i++) ...[
                      if (multi)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '文本块 ${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      TextField(
                        controller: _controllers[i],
                        autofocus: i == 0,
                        minLines: multi ? 3 : 6,
                        maxLines: multi ? 8 : 12,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '请输入内容...',
                        ),
                      ),
                      if (i != _controllers.length - 1)
                        const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _hasContent ? _save : null,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 翻译 language picker (`MessageTranslateButton`'s anchored Menu, rendered
/// as a bottom sheet). Lists the builtin languages with emoji + label and pops
/// the chosen [TranslateLanguage].
class TranslateLanguageSheet extends StatelessWidget {
  const TranslateLanguageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '翻译为',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final lang in builtinTranslateLanguages)
                    ListTile(
                      leading: Text(
                        lang.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(lang.label),
                      onTap: () => Navigator.of(context).pop(lang),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 版本历史 bottom sheet (`MessageActions` version Popover). Lists the saved
/// versions plus a 最新版本 entry, highlights the one on display, and wires 切换 /
/// 删除 / 保存当前 to [ChatController]. Watches the conversation so the list
/// reflects saves/deletes without closing; switching pops the sheet.
class MessageVersionHistorySheet extends ConsumerWidget {
  const MessageVersionHistorySheet({required this.messageId, super.key});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(chatControllerProvider).value;
    ChatMessageView? view;
    if (state != null) {
      for (final candidate in state.messages) {
        if (candidate.id == messageId) {
          view = candidate;
          break;
        }
      }
    }
    final versions = view?.versions ?? const <MessageVersion>[];
    final currentVersionId = view?.currentVersionId;

    // Nothing left to show (e.g. the last version was deleted): close the sheet.
    if (view == null || versions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
      return const SizedBox.shrink();
    }

    final notifier = ref.read(chatControllerProvider.notifier);
    final latestNumber = versions.length + 1;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    '消息版本历史',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => notifier.createManualVersion(messageId),
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('保存当前'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ),
            if (versions.length > 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '已保存 ${versions.length}/20 个版本',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            const Divider(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < versions.length; i++)
                    _VersionTile(
                      label: '版本 ${i + 1}',
                      sourceText: _sourceText(versions[i]),
                      timeText: _formatTime(versions[i].createdAt),
                      isCurrent: versions[i].id == currentVersionId,
                      onTap: () async {
                        await notifier.switchToVersion(
                          messageId,
                          versions[i].id,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      onDelete: () =>
                          notifier.deleteVersion(messageId, versions[i].id),
                    ),
                  _VersionTile(
                    label: '版本 $latestNumber',
                    sourceText: '最新',
                    timeText: '最新版本',
                    isCurrent: currentVersionId == null,
                    onTap: () async {
                      await notifier.switchToLatest(messageId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    onDelete: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mirrors `getVersionSourceText`: maps a version's `source` metadata to the
  /// label chip shown beside it.
  String _sourceText(MessageVersion version) {
    final source = version.metadata?['source'];
    if (source is! String) return '';
    switch (source) {
      case 'regenerate':
        return '重新生成';
      case 'manual':
        return '手动保存';
      case 'auto_before_switch':
        return '自动保存';
      default:
        return '';
    }
  }

  /// A short relative timestamp like the original `dayjs().fromNow()`.
  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.label,
    required this.sourceText,
    required this.timeText,
    required this.isCurrent,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final String sourceText;
  final String timeText;
  final bool isCurrent;
  final Future<void> Function() onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: isCurrent
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: ListTile(
        onTap: isCurrent ? null : onTap,
        title: Row(
          children: [
            Flexible(
              child: Text(
                isCurrent ? '$label (当前)' : label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (sourceText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sourceText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(timeText),
        trailing: onDelete == null
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.trash2, size: 16),
                tooltip: '删除版本',
                onPressed: onDelete,
              ),
      ),
    );
  }
}
