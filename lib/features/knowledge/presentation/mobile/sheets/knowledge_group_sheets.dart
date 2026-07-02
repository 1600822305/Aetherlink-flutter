// 分组相关面板：分组选择（含新建 / 移出）+ 分组名输入。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// [KnowledgeGroupPickerSheet] 的选择结果；[groupName] 为 null 表示移出分组。包一层以区分
/// 「选了移出」和「直接关闭面板」。
class KnowledgeGroupPickResult {
  const KnowledgeGroupPickResult(this.groupName);

  final String? groupName;
}

/// 分组选择面板：已有分组列表 + 新建分组 +（已分组时）移出分组。
class KnowledgeGroupPickerSheet extends StatelessWidget {
  const KnowledgeGroupPickerSheet({
    super.key,
    required this.current,
    required this.groups,
  });

  final String? current;
  final List<String> groups;

  Future<void> _createGroup(BuildContext context) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const KnowledgeGroupNameSheet(title: '新建分组'),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (context.mounted) {
      Navigator.of(context).pop(KnowledgeGroupPickResult(trimmed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '移动到分组',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final group in groups)
              ListTile(
                leading: Icon(
                  LucideIcons.folder,
                  size: 20,
                  color: group == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(group),
                trailing: group == current
                    ? Icon(
                        LucideIcons.check,
                        size: 18,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(KnowledgeGroupPickResult(group)),
              ),
            ListTile(
              leading: Icon(
                LucideIcons.folderPlus,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                '新建分组…',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              onTap: () => _createGroup(context),
            ),
            if (current != null)
              ListTile(
                leading: Icon(
                  LucideIcons.folderMinus,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  '移出分组',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => Navigator.of(
                  context,
                ).pop(const KnowledgeGroupPickResult(null)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单输入框面板：新建 / 重命名分组共用，确认后 pop 输入的名字。
class KnowledgeGroupNameSheet extends StatefulWidget {
  const KnowledgeGroupNameSheet({super.key, required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<KnowledgeGroupNameSheet> createState() =>
      _KnowledgeGroupNameSheetState();
}

class _KnowledgeGroupNameSheetState extends State<KnowledgeGroupNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '分组名'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _controller.text.trim().isEmpty
                      ? null
                      : () =>
                            Navigator.of(context).pop(_controller.text.trim()),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
