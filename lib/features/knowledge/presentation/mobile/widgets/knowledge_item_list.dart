// 知识库详情页条目列表：条目行（状态着色 + 相对时间 + 多选）/ 空状态引导 /
// 关键词搜索结果。
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';

class KnowledgeItemListView extends StatelessWidget {
  const KnowledgeItemListView({
    super.key,
    required this.items,
    required this.theme,
    required this.onNote,
    required this.onFile,
    required this.onUrl,
    required this.onWorkspace,
    required this.onTapItem,
    required this.selectedIds,
    required this.selectionMode,
    required this.onToggleSelected,
  });

  final List<KnowledgeItem> items;
  final ThemeData theme;
  final VoidCallback onNote;
  final VoidCallback onFile;
  final VoidCallback onUrl;
  final VoidCallback onWorkspace;
  final ValueChanged<KnowledgeItem> onTapItem;
  final Set<String> selectedIds;
  final bool selectionMode;
  final ValueChanged<KnowledgeItem> onToggleSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return KnowledgeEmptyHint(
        theme: theme,
        onNote: onNote,
        onFile: onFile,
        onUrl: onUrl,
        onWorkspace: onWorkspace,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        KnowledgeSectionHeader(title: '条目 (${items.length})'),
        KnowledgeOutlinedCard(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.dividerColor),
                KnowledgeItemRow(
                  item: items[i],
                  theme: theme,
                  selectionMode: selectionMode,
                  selected: selectedIds.contains(items[i].id),
                  onTap: () => selectionMode
                      ? onToggleSelected(items[i])
                      : onTapItem(items[i]),
                  onLongPress: () => onToggleSelected(items[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class KnowledgeItemRow extends StatelessWidget {
  const KnowledgeItemRow({
    super.key,
    required this.item,
    required this.theme,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final KnowledgeItem item;
  final ThemeData theme;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status, theme);
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.35,
      ),
      trailing: selectionMode
          ? null
          : Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      leading: selectionMode
          ? Icon(
              selected ? LucideIcons.squareCheck : LucideIcons.square,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            )
          : Icon(
              LucideIcons.fileText,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      title: Text(
        item.title ?? item.source,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${_typeLabel(item.type)} · '),
            TextSpan(
              text: _statusLabel(item.status),
              style: statusColor == null
                  ? null
                  : TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' · ${_relativeTime(item.createdAt)}'),
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 状态着色（对齐 CS statusStyles）：失败=错误色、处理中=主色、就绪不着色。
  static Color? _statusColor(KnowledgeItemStatus status, ThemeData theme) =>
      switch (status) {
        KnowledgeItemStatus.failed => theme.colorScheme.error,
        KnowledgeItemStatus.reading ||
        KnowledgeItemStatus.chunking ||
        KnowledgeItemStatus.embedding => theme.colorScheme.primary,
        KnowledgeItemStatus.idle || KnowledgeItemStatus.completed => null,
      };

  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)}';
  }

  static String _typeLabel(KnowledgeItemType type) => switch (type) {
    KnowledgeItemType.note => '笔记',
    KnowledgeItemType.file => '文件',
    KnowledgeItemType.url => '链接',
    KnowledgeItemType.workspace => '工作区',
  };

  static String _statusLabel(KnowledgeItemStatus status) => switch (status) {
    KnowledgeItemStatus.idle => '待处理',
    KnowledgeItemStatus.reading => '读取中',
    KnowledgeItemStatus.chunking => '切块中',
    KnowledgeItemStatus.embedding => '嵌入中',
    KnowledgeItemStatus.completed => '就绪',
    KnowledgeItemStatus.failed => '失败',
  };
}

class KnowledgeSearchResultsView extends StatelessWidget {
  const KnowledgeSearchResultsView({
    super.key,
    required this.results,
    required this.theme,
  });

  final List<KnowledgeReferenceItem> results;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配内容',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        KnowledgeSectionHeader(title: '搜索结果 (${results.length})'),
        KnowledgeOutlinedCard(
          child: Column(
            children: [
              for (var i = 0; i < results.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.dividerColor),
                ListTile(
                  title: Text(
                    results[i].content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Text(
                    '${(results[i].similarity * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class KnowledgeEmptyHint extends StatelessWidget {
  const KnowledgeEmptyHint({
    super.key,
    required this.theme,
    required this.onNote,
    required this.onFile,
    required this.onUrl,
    required this.onWorkspace,
  });

  final ThemeData theme;
  final VoidCallback onNote;
  final VoidCallback onFile;
  final VoidCallback onUrl;
  final VoidCallback onWorkspace;

  @override
  Widget build(BuildContext context) {
    Widget source(IconData icon, String label, VoidCallback onTap) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.fileText,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('还没有任何条目', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '添加笔记、文件、网址或工作区目录，即可在此检索',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                source(LucideIcons.filePlus, '笔记', onNote),
                source(LucideIcons.upload, '文件', onFile),
                source(LucideIcons.link, '网址', onUrl),
                source(LucideIcons.folder, '工作区', onWorkspace),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
