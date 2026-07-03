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
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_create_base_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_group_sheets.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_base_list.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_common.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class KnowledgeBasePage extends ConsumerWidget {
  const KnowledgeBasePage({super.key});

  Future<void> _createBase(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<KnowledgeCreateBaseResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const KnowledgeCreateBaseSheet(),
    );
    if (result == null || result.name.isEmpty) return;
    await ref
        .read(knowledgeBasesControllerProvider.notifier)
        .createBase(
          result.name,
          embeddingModelKey: result.embeddingModelKey,
          searchMode: result.searchMode,
        );
    if (context.mounted) {
      AppToast.success(context, '已创建知识库「${result.name}」');
    }
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

  /// 打开分组选择面板，把 [base] 挂到选中的分组（或移出分组）。
  Future<void> _pickGroup(
    BuildContext context,
    WidgetRef ref,
    KnowledgeBase base,
    List<String> groups,
  ) async {
    final result = await showModalBottomSheet<KnowledgeGroupPickResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) =>
          KnowledgeGroupPickerSheet(current: base.groupName, groups: groups),
    );
    if (result == null) return;
    await ref
        .read(knowledgeBasesControllerProvider.notifier)
        .setBaseGroup(base.id, result.groupName);
    if (context.mounted) {
      AppToast.success(
        context,
        result.groupName == null
            ? '已将「${base.name}」移出分组'
            : '已将「${base.name}」移入「${result.groupName}」',
      );
    }
  }

  Future<void> _renameGroup(
    BuildContext context,
    WidgetRef ref,
    String group,
  ) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => KnowledgeGroupNameSheet(title: '重命名分组', initial: group),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == group) return;
    await ref
        .read(knowledgeBasesControllerProvider.notifier)
        .renameGroup(group, trimmed);
    if (context.mounted) AppToast.success(context, '已重命名为「$trimmed」');
  }

  Future<void> _dissolveGroup(
    BuildContext context,
    WidgetRef ref,
    String group,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解散分组'),
        content: Text('将解散「$group」，组内知识库移回未分组（库本身保留）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('解散'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(knowledgeBasesControllerProvider.notifier)
        .dissolveGroup(group);
    if (context.mounted) AppToast.success(context, '已解散「$group」');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final basesAsync = ref.watch(knowledgeBasesControllerProvider);
    final bases = basesAsync.asData?.value ?? const <KnowledgeBase>[];
    final usage = ref.watch(knowledgeStorageUsageProvider).asData?.value;

    // 按分组名聚合（功能缺口⑦）：具名分组按名排序在前，未分组殿后。
    final groupNames = <String>[
      for (final b in bases)
        if (b.groupName != null) b.groupName!,
    ];
    final groups = groupNames.toSet().toList()..sort();
    final ungrouped = [
      for (final b in bases)
        if (b.groupName == null) b,
    ];

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
            KnowledgeSectionHeader(title: '知识库 (${bases.length})'),
            if (bases.isEmpty)
              KnowledgeBasesEmptyHint(
                theme: theme,
                onCreate: () => _createBase(context, ref),
              )
            else ...[
              for (final group in groups) ...[
                KnowledgeGroupHeader(
                  name: group,
                  count: groupNames.where((g) => g == group).length,
                  onRename: () => _renameGroup(context, ref, group),
                  onDissolve: () => _dissolveGroup(context, ref, group),
                ),
                KnowledgeBaseListCard(
                  bases: [
                    for (final b in bases)
                      if (b.groupName == group) b,
                  ],
                  onOpen: (b) => context.push(
                    '/settings/knowledge/${b.id}',
                    extra: b.name,
                  ),
                  onPickGroup: (b) => _pickGroup(context, ref, b, groups),
                  onDelete: (b) => _deleteBase(context, ref, b),
                ),
                const SizedBox(height: 12),
              ],
              if (ungrouped.isNotEmpty) ...[
                if (groups.isNotEmpty)
                  KnowledgeGroupHeader(name: '未分组', count: ungrouped.length),
                KnowledgeBaseListCard(
                  bases: ungrouped,
                  onOpen: (b) => context.push(
                    '/settings/knowledge/${b.id}',
                    extra: b.name,
                  ),
                  onPickGroup: (b) => _pickGroup(context, ref, b, groups),
                  onDelete: (b) => _deleteBase(context, ref, b),
                ),
              ],
            ],
            if (usage != null && usage.stats.itemCount > 0) ...[
              const SizedBox(height: 16),
              KnowledgeStorageUsageCard(usage: usage, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}
