import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_binding.dart';

/// Result of [showWorldBookTopicSheet]: the topic's new `worldBookIds`
/// (`null` = 继承助手, `[]` = 关闭, otherwise 覆盖). Wrapped so a dismissed
/// sheet (`null` result) is distinct from choosing 继承.
class WorldBookTopicChoice {
  const WorldBookTopicChoice(this.worldBookIds);

  final List<String>? worldBookIds;
}

/// 话题级世界书覆盖面板：显示当前生效来源与激活书数，可切换继承 / 覆盖 / 关闭。
Future<WorldBookTopicChoice?> showWorldBookTopicSheet(
  BuildContext context, {
  required List<String> assistantBookIds,
  required List<String>? topicBookIds,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<WorldBookTopicChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _WorldBookTopicSheet(
      assistantBookIds: assistantBookIds,
      topicBookIds: topicBookIds,
    ),
  );
}

enum _Mode { inherit, override, disabled }

class _WorldBookTopicSheet extends ConsumerStatefulWidget {
  const _WorldBookTopicSheet({
    required this.assistantBookIds,
    required this.topicBookIds,
  });

  final List<String> assistantBookIds;
  final List<String>? topicBookIds;

  @override
  ConsumerState<_WorldBookTopicSheet> createState() =>
      _WorldBookTopicSheetState();
}

class _WorldBookTopicSheetState extends ConsumerState<_WorldBookTopicSheet> {
  late _Mode _mode = widget.topicBookIds == null
      ? _Mode.inherit
      : widget.topicBookIds!.isEmpty
      ? _Mode.disabled
      : _Mode.override;
  late final Set<String> _selected = {
    ...(widget.topicBookIds ?? widget.assistantBookIds),
  };

  List<String>? get _ids => switch (_mode) {
    _Mode.inherit => null,
    _Mode.disabled => const <String>[],
    _Mode.override => _selected.toList(),
  };

  String _status(List<WorldBook> books) {
    final binding = resolveWorldBookBinding(
      assistantBookIds: widget.assistantBookIds,
      topicBookIds: _ids,
      globalBookIds: _globalIds,
    );
    final active = activeWorldBooks(binding, books).length;
    return switch (binding.source) {
      WorldBookBindingSource.assistant => '继承助手 · 生效 $active 本',
      WorldBookBindingSource.globalDefault =>
        '继承全局默认（助手未绑定）· 生效 $active 本',
      WorldBookBindingSource.topicOverride => '话题覆盖 · 生效 $active 本',
      WorldBookBindingSource.topicDisabled => '本话题已关闭世界书',
    };
  }

  List<String> _globalIds = const <String>[];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books =
        ref.watch(worldBookLibraryProvider).asData?.value ??
        const <WorldBook>[];
    _globalIds =
        ref.watch(worldBookGlobalDefaultProvider).value ?? const <String>[];
    // 覆盖模式下一本都不选等同关闭，确认按钮直接提交 [] 以免含义模糊。
    final ids = _mode == _Mode.override && _selected.isEmpty
        ? const <String>[]
        : _ids;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '本话题的世界书',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _status(books),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.inherit, label: Text('继承助手')),
                  ButtonSegment(value: _Mode.override, label: Text('单独选择')),
                  ButtonSegment(value: _Mode.disabled, label: Text('关闭')),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(child: _list(theme, books)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(WorldBookTopicChoice(ids)),
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

  Widget _list(ThemeData theme, List<WorldBook> books) {
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '暂无世界书\n请先在设置 → 世界书中创建或导入',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final editable = _mode == _Mode.override;
    final shown = switch (_mode) {
      _Mode.inherit =>
        (widget.assistantBookIds.isEmpty ? _globalIds : widget.assistantBookIds)
            .toSet(),
      _Mode.disabled => const <String>{},
      _Mode.override => _selected,
    };
    return ListView(
      shrinkWrap: true,
      children: [
        for (final book in books)
          CheckboxListTile(
            value: shown.contains(book.id),
            enabled: editable,
            onChanged: editable
                ? (v) => setState(
                    () => v == true
                        ? _selected.add(book.id)
                        : _selected.remove(book.id),
                  )
                : null,
            secondary: Icon(
              LucideIcons.bookMarked,
              size: 20,
              color: book.enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              book.name.isEmpty ? '未命名世界书' : book.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              book.enabled
                  ? '已启用 ${book.enabledEntryCount}/${book.entries.length} 条'
                  : '已停用（不会注入）',
            ),
          ),
      ],
    );
  }
}
