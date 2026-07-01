// 「知识库」 page (设置 → 数据与知识 → 知识库设置, route /settings/knowledge).
//
// Lives in the knowledge feature (not settings) because it reaches knowledge
// `application` directly — the cross-feature import-boundary guard only allows
// settings to reference its route string via AppRouter, never the page class.
//
// 轨道 A / UI 的入口（设计文档 §10）：建库 / 进入某库 / 删库。语义检索、聊天工具、
// 智能体绑定等留待后续阶段。UI 对齐工作区管理页（工作区/记忆同款卡片式设置）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class KnowledgeBasePage extends ConsumerWidget {
  const KnowledgeBasePage({super.key});

  Future<void> _createBase(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建知识库'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(knowledgeBasesControllerProvider.notifier).createBase(name);
    if (context.mounted) AppToast.success(context, '已创建知识库「$name」');
  }

  Future<void> _deleteBase(
    BuildContext context,
    WidgetRef ref,
    KnowledgeBase base,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除知识库'),
        content: Text('将删除「${base.name}」及其全部条目与索引。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(knowledgeBasesControllerProvider.notifier)
        .deleteBase(base.id);
    if (context.mounted) AppToast.success(context, '已删除「${base.name}」');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final basesAsync = ref.watch(knowledgeBasesControllerProvider);
    final bases = basesAsync.asData?.value ?? const <KnowledgeBase>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.settingsPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('知识库'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 22),
            color: theme.colorScheme.primary,
            tooltip: '新建知识库',
            onPressed: () => _createBase(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: basesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败 · $err')),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: '知识库 (${bases.length})'),
            if (bases.isEmpty)
              _EmptyHint(theme: theme, onCreate: () => _createBase(context, ref))
            else
              _OutlinedCard(
                child: Column(
                  children: [
                    for (var i = 0; i < bases.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: theme.dividerColor),
                      _BaseRow(
                        base: bases[i],
                        onOpen: () => context.push(
                          '/settings/knowledge/${bases[i].id}',
                          extra: bases[i].name,
                        ),
                        onDelete: () => _deleteBase(context, ref, bases[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BaseRow extends StatelessWidget {
  const _BaseRow({
    required this.base,
    required this.onOpen,
    required this.onDelete,
  });

  final KnowledgeBase base;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onOpen,
      leading: Icon(
        LucideIcons.bookOpen,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        base.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_modeLabel(base.searchMode)} · ${_statusLabel(base.status)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(LucideIcons.trash2, size: 18),
        color: theme.colorScheme.error,
        tooltip: '删除',
        onPressed: onDelete,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.theme, required this.onCreate});

  final ThemeData theme;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCard(
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

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
