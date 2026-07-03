// 知识库列表页的列表相关小部件：库列表卡片 / 分组标题 / 库行 / 空状态 /
// 存储占用提示。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_dao.dart'
    show KnowledgeStorageStats;
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart'
    show KnowledgeService;
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';

/// 存储占用提示（设计文档 §11.1 软配额）：展示正文/索引占用，超过软上限时变色
/// 提醒但不拦截。
class KnowledgeStorageUsageCard extends StatelessWidget {
  const KnowledgeStorageUsageCard({
    super.key,
    required this.usage,
    required this.theme,
  });

  final ({KnowledgeStorageStats stats, bool overSoftLimit}) usage;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final stats = usage.stats;
    final over = usage.overSoftLimit;
    final color = over
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return KnowledgeOutlinedCard(
      child: ListTile(
        leading: Icon(
          over ? LucideIcons.triangleAlert : LucideIcons.database,
          color: over ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(
          '存储占用 ${_formatBytes(stats.totalBytes)}'
          '${over ? '（已超软上限 ${_formatBytes(KnowledgeService.softStorageLimitBytes)}）' : ''}',
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
        subtitle: Text(
          '${stats.itemCount} 个条目 · ${stats.chunkCount} 个切块 · '
          '${stats.embeddingCount} 个向量'
          '${over ? '，建议清理不再使用的库或条目' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

/// 一组库的卡片列表（分组内 / 未分组共用）。
class KnowledgeBaseListCard extends StatelessWidget {
  const KnowledgeBaseListCard({
    super.key,
    required this.bases,
    required this.onOpen,
    required this.onPickGroup,
    required this.onDelete,
  });

  final List<KnowledgeBase> bases;
  final ValueChanged<KnowledgeBase> onOpen;
  final ValueChanged<KnowledgeBase> onPickGroup;
  final ValueChanged<KnowledgeBase> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KnowledgeOutlinedCard(
      child: Column(
        children: [
          for (var i = 0; i < bases.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.dividerColor),
            KnowledgeBaseRow(
              base: bases[i],
              onOpen: () => onOpen(bases[i]),
              onPickGroup: () => onPickGroup(bases[i]),
              onDelete: () => onDelete(bases[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// 分组小标题：名称 + 数量，具名分组带重命名 / 解散菜单。
class KnowledgeGroupHeader extends StatelessWidget {
  const KnowledgeGroupHeader({
    super.key,
    required this.name,
    required this.count,
    this.onRename,
    this.onDissolve,
  });

  final String name;
  final int count;
  final VoidCallback? onRename;
  final VoidCallback? onDissolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            LucideIcons.folder,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$name ($count)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRename != null || onDissolve != null)
            PopupMenuButton<String>(
              popUpAnimationStyle: AnimationStyle.noAnimation,
              icon: Icon(
                LucideIcons.ellipsis,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: '分组操作',
              onSelected: (value) {
                if (value == 'rename') onRename?.call();
                if (value == 'dissolve') onDissolve?.call();
              },
              itemBuilder: (ctx) => [
                if (onRename != null)
                  const PopupMenuItem(value: 'rename', child: Text('重命名分组')),
                if (onDissolve != null)
                  const PopupMenuItem(value: 'dissolve', child: Text('解散分组')),
              ],
            )
          else
            const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class KnowledgeBaseRow extends StatelessWidget {
  const KnowledgeBaseRow({
    super.key,
    required this.base,
    required this.onOpen,
    required this.onPickGroup,
    required this.onDelete,
  });

  final KnowledgeBase base;
  final VoidCallback onOpen;
  final VoidCallback onPickGroup;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onOpen,
      leading: Icon(LucideIcons.bookOpen, color: theme.colorScheme.primary),
      title: Text(base.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_modeLabel(base.searchMode)} · ${_statusLabel(base.status)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.folderInput, size: 18),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '移动到分组',
            onPressed: onPickGroup,
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 18),
            color: theme.colorScheme.error,
            tooltip: '删除',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  static String _modeLabel(KnowledgeSearchMode mode) => switch (mode) {
    KnowledgeSearchMode.keyword => '关键词检索',
    KnowledgeSearchMode.vector => '向量检索',
    KnowledgeSearchMode.hybrid => '混合检索',
  };

  static String _statusLabel(KnowledgeBaseStatus status) => switch (status) {
    KnowledgeBaseStatus.idle => '空闲',
    KnowledgeBaseStatus.indexing => '索引中',
    KnowledgeBaseStatus.completed => '就绪',
    KnowledgeBaseStatus.failed => '失败',
  };
}

class KnowledgeBasesEmptyHint extends StatelessWidget {
  const KnowledgeBasesEmptyHint({
    super.key,
    required this.theme,
    required this.onCreate,
  });

  final ThemeData theme;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return KnowledgeOutlinedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(
              LucideIcons.bookOpen,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('还没有任何知识库', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '新建知识库并添加笔记后，即可关键词搜索',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('新建知识库'),
            ),
          ],
        ),
      ),
    );
  }
}
