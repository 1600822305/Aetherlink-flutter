import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/quick_phrases_access.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/domain/quick_phrase.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_button_catalog.dart';

/// Opens the 快捷短语 selector as a bottom sheet — the parity port of the web
/// `QuickPhraseButton` panel. [onInsert] receives the chosen phrase's content
/// (the host inserts it at the composer caret).
Future<void> showQuickPhraseSheet(
  BuildContext context, {
  required void Function(String content) onInsert,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => QuickPhraseSheet(onInsert: onInsert),
  );
}

/// The 快捷短语 selector list (port of `QuickPhraseButton`'s panel): the current
/// assistant's `regularPhrases` first, then the global phrases, then a 添加快捷短语…
/// row that opens the add dialog. Tapping a phrase inserts its content via
/// [onInsert] and closes the sheet. Styled like the sibling [InputBoxMenuSheet]
/// (drag handle + title + list) for design-system consistency.
class QuickPhraseSheet extends ConsumerWidget {
  const QuickPhraseSheet({super.key, required this.onInsert});

  final void Function(String content) onInsert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assistant = ref.watch(currentAssistantProvider);
    final assistantPhrases = assistant?.regularPhrases ?? const <QuickPhrase>[];
    final globalPhrases =
        ref.watch(globalQuickPhrasesProvider).asData?.value ??
        const <QuickPhrase>[];
    final hasAny = assistantPhrases.isNotEmpty || globalPhrases.isNotEmpty;

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
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '快捷短语',
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
                  for (final phrase in assistantPhrases)
                    _phraseTile(context, theme, phrase, assistant: true),
                  for (final phrase in globalPhrases)
                    _phraseTile(context, theme, phrase, assistant: false),
                  if (hasAny) const Divider(height: 8),
                  ListTile(
                    leading: Icon(
                      LucideIcons.plus,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    title: const Text('添加快捷短语...'),
                    onTap: () => _openAddDialog(context, ref, assistant?.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phraseTile(
    BuildContext context,
    ThemeData theme,
    QuickPhrase phrase, {
    required bool assistant,
  }) {
    final preview = phrase.content.length > 50
        ? '${phrase.content.substring(0, 50)}...'
        : phrase.content;
    return ListTile(
      leading: assistant
          ? Icon(
              LucideIcons.botMessageSquare,
              size: 20,
              color: theme.colorScheme.onSurface,
            )
          : inputBoxMenuIcon(
              InputBoxAction.quickPhrase,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
      title: Text(phrase.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: preview.isEmpty
          ? null
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        onInsert(phrase.content);
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _openAddDialog(
    BuildContext context,
    WidgetRef ref,
    String? assistantId,
  ) async {
    final result = await showDialog<_AddPhraseResult>(
      context: context,
      builder: (_) => _AddQuickPhraseDialog(hasAssistant: assistantId != null),
    );
    if (result == null) return;
    if (result.location == _PhraseLocation.assistant && assistantId != null) {
      await ref
          .read(assistantsProvider.notifier)
          .addRegularPhrase(
            assistantId,
            title: result.title,
            content: result.content,
          );
    } else {
      await ref
          .read(globalQuickPhrasesProvider.notifier)
          .add(title: result.title, content: result.content);
    }
  }
}

enum _PhraseLocation { global, assistant }

class _AddPhraseResult {
  const _AddPhraseResult({
    required this.title,
    required this.content,
    required this.location,
  });

  final String title;
  final String content;
  final _PhraseLocation location;
}

/// The 添加快捷短语 form (port of `QuickPhraseButton`'s add dialog): a 标题 / 内容 pair
/// plus a 添加位置 radio (全局快捷短语 / 助手提示词, the latter only when an assistant is
/// current). 保存 stays disabled until both fields are non-blank.
class _AddQuickPhraseDialog extends StatefulWidget {
  const _AddQuickPhraseDialog({required this.hasAssistant});

  final bool hasAssistant;

  @override
  State<_AddQuickPhraseDialog> createState() => _AddQuickPhraseDialogState();
}

class _AddQuickPhraseDialogState extends State<_AddQuickPhraseDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  _PhraseLocation _location = _PhraseLocation.global;

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
      _AddPhraseResult(
        title: _title.text.trim(),
        content: _content.text.trim(),
        location: _location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('添加快捷短语'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '标题', isDense: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '内容',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Text('添加位置', style: theme.textTheme.bodySmall),
            RadioGroup<_PhraseLocation>(
              groupValue: _location,
              onChanged: (value) {
                if (value != null) setState(() => _location = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<_PhraseLocation>(
                    value: _PhraseLocation.global,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        inputBoxMenuIcon(
                          InputBoxAction.quickPhrase,
                          color: theme.colorScheme.onSurface,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text('全局快捷短语'),
                      ],
                    ),
                  ),
                  if (widget.hasAssistant)
                    RadioListTile<_PhraseLocation>(
                      value: _PhraseLocation.assistant,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.botMessageSquare,
                            size: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 6),
                          const Text('助手提示词'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
          child: const Text('保存'),
        ),
      ],
    );
  }
}
