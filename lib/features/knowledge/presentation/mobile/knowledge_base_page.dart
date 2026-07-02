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

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_dao.dart'
    show KnowledgeStorageStats;
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart'
    show KnowledgeService;
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class KnowledgeBasePage extends ConsumerWidget {
  const KnowledgeBasePage({super.key});

  Future<void> _createBase(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CreateBaseResult>(
      context: context,
      builder: (ctx) => const _CreateBaseDialog(),
    );
    if (result == null || result.name.isEmpty) return;
    await ref.read(knowledgeBasesControllerProvider.notifier).createBase(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final basesAsync = ref.watch(knowledgeBasesControllerProvider);
    final bases = basesAsync.asData?.value ?? const <KnowledgeBase>[];
    final usage = ref.watch(knowledgeStorageUsageProvider).asData?.value;

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
            if (usage != null && usage.stats.itemCount > 0) ...[
              const SizedBox(height: 16),
              _StorageUsageCard(usage: usage, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

/// 存储占用提示（设计文档 §11.1 软配额）：展示正文/索引占用，超过软上限时变色
/// 提醒但不拦截。
class _StorageUsageCard extends StatelessWidget {
  const _StorageUsageCard({required this.usage, required this.theme});

  final ({KnowledgeStorageStats stats, bool overSoftLimit}) usage;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final stats = usage.stats;
    final over = usage.overSoftLimit;
    final color = over
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return _OutlinedCard(
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

/// The choices returned by [_CreateBaseDialog]. [embeddingModelKey] is null for
/// a pure keyword base; when set, [searchMode] is vector or hybrid.
class _CreateBaseResult {
  const _CreateBaseResult({
    required this.name,
    required this.embeddingModelKey,
    required this.searchMode,
  });

  final String name;
  final String? embeddingModelKey;
  final KnowledgeSearchMode searchMode;
}

/// 新建知识库对话框：名称 + 可选嵌入模型 + 检索模式。未选嵌入模型时锁定关键词检索
/// （与服务端 `createBase` 的约束一致，避免建出「向量库却无从嵌入」的坏状态）。
class _CreateBaseDialog extends ConsumerStatefulWidget {
  const _CreateBaseDialog();

  @override
  ConsumerState<_CreateBaseDialog> createState() => _CreateBaseDialogState();
}

class _CreateBaseDialogState extends ConsumerState<_CreateBaseDialog> {
  final _controller = TextEditingController();
  String? _modelKey;
  KnowledgeSearchMode _mode = KnowledgeSearchMode.keyword;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _modelDisplayName(List<ModelProvider> providers) {
    final pair = decodeEmbeddingModelKey(_modelKey);
    if (pair == null) return '未选择（纯关键词检索）';
    for (final p in providers) {
      if (p.id != pair.$1) continue;
      for (final m in p.models) {
        if (m.id == pair.$2) return '${p.name} / ${m.name}';
      }
    }
    return '未选择（纯关键词检索）';
  }

  Future<void> _pickModel() async {
    final pair = decodeEmbeddingModelKey(_modelKey);
    await showModelSelectorDialog(
      context,
      selectedProviderId: pair?.$1,
      selectedModelId: pair?.$2,
      filter: isEmbeddingModel,
      onSelect: (provider, model) {
        setState(() {
          _modelKey = encodeEmbeddingModelKey(provider.id, model.id);
          // 一旦选了嵌入模型，默认切到混合检索（语义 + 关键词兜底）。
          if (_mode == KnowledgeSearchMode.keyword) {
            _mode = KnowledgeSearchMode.hybrid;
          }
        });
      },
    );
  }

  void _clearModel() {
    setState(() {
      _modelKey = null;
      _mode = KnowledgeSearchMode.keyword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ??
        const <ModelProvider>[];
    final hasModel = _modelKey != null;

    return AlertDialog(
      title: const Text('新建知识库'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            '嵌入模型',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _pickModel,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.boxes,
                    size: 18,
                    color: hasModel
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _modelDisplayName(providers),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasModel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (hasModel)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      visualDensity: VisualDensity.compact,
                      tooltip: '清除',
                      onPressed: _clearModel,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '检索模式',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _ModeSelector(
            mode: _mode,
            enableSemantic: hasModel,
            onChanged: (m) => setState(() => _mode = m),
          ),
          if (!hasModel) ...[
            const SizedBox(height: 6),
            Text(
              '未选嵌入模型时仅支持关键词检索',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _CreateBaseResult(
                    name: _controller.text.trim(),
                    embeddingModelKey: _modelKey,
                    searchMode: _mode,
                  ),
                ),
          child: const Text('创建'),
        ),
      ],
    );
  }
}

/// Segmented selector for the three retrieval modes. 向量 / 混合 are disabled
/// (greyed out) until an embedding model is chosen.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.enableSemantic,
    required this.onChanged,
  });

  final KnowledgeSearchMode mode;
  final bool enableSemantic;
  final ValueChanged<KnowledgeSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(KnowledgeSearchMode value, String label) {
      final enabled = value == KnowledgeSearchMode.keyword || enableSemantic;
      final selected = mode == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: enabled ? (_) => onChanged(value) : null,
          selectedColor: theme.colorScheme.primary,
          disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          labelStyle: TextStyle(
            color: !enabled
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return Wrap(
      children: [
        chip(KnowledgeSearchMode.keyword, '关键词'),
        chip(KnowledgeSearchMode.vector, '向量'),
        chip(KnowledgeSearchMode.hybrid, '混合'),
      ],
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
