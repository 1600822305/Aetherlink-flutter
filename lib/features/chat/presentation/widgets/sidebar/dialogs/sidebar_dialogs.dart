// Sidebar dialogs: add-assistant, create/add-to group, move-topic, text/confirm prompts.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/assistant_presets.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_avatar.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// The 添加助手 picker: a scrollable list of the 17 [kAssistantPresets].
Future<void> showAddAssistantDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('选择助手'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  '选择一个预设助手来添加到你的助手列表中',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: kAssistantPresets.length,
                  itemBuilder: (context, index) {
                    final preset = kAssistantPresets[index];
                    return ListTile(
                      leading: Text(
                        preset.emoji ?? '🤖',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(preset.name),
                      subtitle: preset.description == null
                          ? null
                          : Text(
                              preset.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () {
                        ref.read(assistantsProvider.notifier).addPreset(preset);
                        Navigator.of(dialogContext).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

/// Prompts for a folder name and creates the group (创建分组 / 创建话题分组).
Future<void> showCreateGroupDialog(
  BuildContext context,
  WidgetRef ref, {
  required GroupType type,
  String? assistantId,
}) async {
  final name = await promptText(
    context,
    title: type == GroupType.assistant ? '创建助手分组' : '创建话题分组',
    hint: '分组名称',
  );
  if (name == null) return;
  await ref
      .read(groupsProvider.notifier)
      .createGroup(type: type, name: name, assistantId: assistantId);
}

/// Lists same-scope folders to drop [itemId] into, plus a "新建分组" option.
Future<void> showAddToGroupDialog(
  BuildContext context,
  WidgetRef ref, {
  required GroupType type,
  String? assistantId,
  required String itemId,
}) async {
  final groups = type == GroupType.assistant
      ? ref.read(assistantGroupsProvider)
      : ref.read(topicGroupsProvider(assistantId!));
  final notifier = ref.read(groupsProvider.notifier);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: const Text('添加到分组'),
        children: [
          for (final g in groups)
            SimpleDialogOption(
              onPressed: () {
                notifier.addItemToGroup(g.id, itemId);
                Navigator.of(dialogContext).pop();
              },
              child: Row(
                children: [
                  const Icon(LucideIcons.folder, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(g.name)),
                ],
              ),
            ),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text('还没有分组，先新建一个吧'),
            ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final name = await promptText(
                context,
                title: '新建分组',
                hint: '分组名称',
              );
              if (name == null) return;
              final id = await notifier.createGroup(
                type: type,
                name: name,
                assistantId: assistantId,
              );
              if (id != null) await notifier.addItemToGroup(id, itemId);
            },
            child: const Row(
              children: [
                Icon(LucideIcons.folderPlus, size: 18),
                SizedBox(width: 12),
                Text('新建分组'),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Lists the other assistants to move [topic] into (移动到…).
Future<void> showMoveTopicDialog(
  BuildContext context,
  WidgetRef ref, {
  required Topic topic,
}) async {
  final all = ref.read(assistantsProvider).asData?.value ?? const <Assistant>[];
  final others = all.where((a) => a.id != topic.assistantId).toList();
  final notifier = ref.read(topicsProvider.notifier);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: const Text('移动到...'),
        children: [
          for (final a in others)
            SimpleDialogOption(
              onPressed: () {
                notifier.move(topic.id, a.id);
                Navigator.of(dialogContext).pop();
              },
              child: Row(
                children: [
                  Text(
                    assistantAvatarText(a),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.name)),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// A single-field text prompt; returns the trimmed text on 确定, else `null`.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _PromptTextDialog(title: title, hint: hint, initial: initial),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}

/// The single-field dialog backing [promptText]. It owns the text field's
/// [TextEditingController] so the controller lives exactly as long as the
/// dialog element and is disposed by the framework when the route unmounts.
class _PromptTextDialog extends StatefulWidget {
  const _PromptTextDialog({
    required this.title,
    required this.hint,
    this.initial,
  });

  final String title;
  final String hint;
  final String? initial;

  @override
  State<_PromptTextDialog> createState() => _PromptTextDialogState();
}

class _PromptTextDialogState extends State<_PromptTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// A destructive confirm dialog; returns `true` only when 确定 is pressed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: kSidebarDanger),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
