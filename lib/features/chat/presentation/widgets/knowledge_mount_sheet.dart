import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';

/// Opens the 挂载知识库 picker（功能缺口⑫）: a multi-select sheet listing every
/// 知识库 with checkboxes. Returns the chosen base ids on 确定
/// (an empty list clears the mount), or `null` if dismissed/cancelled.
/// [initial] pre-checks the currently-mounted bases so re-opening edits the
/// selection. Mirrors [showMultiModelSelectorSheet].
Future<List<String>?> showKnowledgeMountSheet(
  BuildContext context, {
  List<String> initial = const <String>[],
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _KnowledgeMountSheet(initial: initial),
  );
}

/// Opens the 存入知识库 single-select picker（对比 CS 的 SaveToKnowledgePopup）:
/// lists every 知识库, tapping one returns it. Returns `null` if
/// dismissed/cancelled.
Future<KnowledgeBase?> showKnowledgeSavePickerSheet(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<KnowledgeBase>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => const _KnowledgeSavePickerSheet(),
  );
}

class _KnowledgeSavePickerSheet extends ConsumerStatefulWidget {
  const _KnowledgeSavePickerSheet();

  @override
  ConsumerState<_KnowledgeSavePickerSheet> createState() =>
      _KnowledgeSavePickerSheetState();
}

class _KnowledgeSavePickerSheetState
    extends ConsumerState<_KnowledgeSavePickerSheet> {
  late final Future<List<KnowledgeBase>> _bases =
      listChatEnabledKnowledgeBases(ref);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '存入知识库',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择一个知识库，把这条消息以笔记形式摄取进去',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<KnowledgeBase>>(
                future: _bases,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final bases = snapshot.data!;
                  if (bases.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '暂无知识库\n请先在知识库页面创建',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final base in bases)
                        ListTile(
                          onTap: () => Navigator.of(context).pop(base),
                          dense: true,
                          leading: Icon(
                            LucideIcons.bookOpen,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            base.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeMountSheet extends ConsumerStatefulWidget {
  const _KnowledgeMountSheet({required this.initial});

  final List<String> initial;

  @override
  ConsumerState<_KnowledgeMountSheet> createState() =>
      _KnowledgeMountSheetState();
}

class _KnowledgeMountSheetState extends ConsumerState<_KnowledgeMountSheet> {
  late final Set<String> _selected = {...widget.initial};
  late final Future<List<KnowledgeBase>> _bases =
      listChatEnabledKnowledgeBases(ref);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '挂载知识库',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Text(
                      '已选 ${_selected.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '挂载后，每次发送都会先检索所选库，把命中的资料注入本轮上下文',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<KnowledgeBase>>(
                future: _bases,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final bases = snapshot.data!;
                  if (bases.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '暂无知识库\n请先在知识库页面创建',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final base in bases) _baseTile(theme, base),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baseTile(ThemeData theme, KnowledgeBase base) {
    final checked = _selected.contains(base.id);
    return CheckboxListTile(
      value: checked,
      onChanged: (_) => setState(() {
        if (checked) {
          _selected.remove(base.id);
        } else {
          _selected.add(base.id);
        }
      }),
      controlAffinity: ListTileControlAffinity.trailing,
      dense: true,
      secondary: Icon(
        LucideIcons.bookOpen,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      title: Text(base.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
