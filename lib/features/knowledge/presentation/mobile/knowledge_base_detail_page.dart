// 单个知识库详情页 (route /settings/knowledge/:baseId).
//
// 轨道 A / UI 的最小闭环（设计文档 §10）：加笔记（含粘贴 txt/md 文本）+ 纯关键词
// 检索 + 条目列表。语义检索留待 P1。UI 对齐工作区管理页的卡片式风格。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class KnowledgeBaseDetailPage extends ConsumerStatefulWidget {
  const KnowledgeBaseDetailPage({
    required this.baseId,
    required this.baseName,
    super.key,
  });

  final String baseId;
  final String baseName;

  @override
  ConsumerState<KnowledgeBaseDetailPage> createState() =>
      _KnowledgeBaseDetailPageState();
}

class _KnowledgeBaseDetailPageState
    extends ConsumerState<KnowledgeBaseDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  List<KnowledgeReferenceItem>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);
    final results = await ref
        .read(knowledgeServiceProvider)
        .search(baseId: widget.baseId, query: query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _results = null);
  }

  Future<void> _addNote() async {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加笔记'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '标题（可选）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '内容',
                  hintText: '粘贴或输入文本（支持 txt / md）',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final title = titleController.text.trim();
    final text = textController.text;
    titleController.dispose();
    textController.dispose();
    if (saved != true || text.trim().isEmpty) return;
    await ref
        .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
        .addNote(title: title, text: text);
    if (mounted) AppToast.success(context, '已添加笔记');
  }

  /// 选择一个 txt / md 文件并摄取为条目。读取按 UTF-8；富文档（PDF/DOCX）暂不支持。
  Future<void> _addFile() async {
    final picked = await ref
        .read(fileSystemApiProvider)
        .pickFile(allowedExtensions: const ['txt', 'md', 'markdown', 'text']);
    if (picked == null) return;
    String text;
    try {
      text = await ref.read(fileSystemApiProvider).readAsString(picked.path);
    } catch (e) {
      if (mounted) AppToast.error(context, '读取文件失败：$e');
      return;
    }
    if (text.trim().isEmpty) {
      if (mounted) AppToast.error(context, '文件内容为空，未摄取');
      return;
    }
    try {
      await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .addFile(fileName: picked.name, text: text, sourcePath: picked.path);
      if (mounted) AppToast.success(context, '已上传「${picked.name}」');
    } catch (e) {
      if (mounted) AppToast.error(context, '上传失败：$e');
    }
  }

  /// 从已存正文重建整库索引（切块 + 向量）。适用于调整切块/嵌入配置后刷新。
  Future<void> _refresh() async {
    try {
      final count = await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .refresh();
      if (mounted) AppToast.success(context, '已重建索引（$count 个条目）');
    } catch (e) {
      if (mounted) AppToast.error(context, '重建索引失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(
      knowledgeItemsControllerProvider(widget.baseId),
    );

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
            onPressed: () => context.pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Text(widget.baseName.isEmpty ? '知识库' : widget.baseName),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '重建索引',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(LucideIcons.upload, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '上传文件（txt / md）',
            onPressed: _addFile,
          ),
          IconButton(
            icon: const Icon(LucideIcons.filePlus, size: 22),
            color: theme.colorScheme.primary,
            tooltip: '添加笔记',
            onPressed: _addNote,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '关键词搜索',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results != null
                ? _SearchResults(results: _results!, theme: theme)
                : itemsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('加载失败 · $err')),
                    data: (items) =>
                        _ItemList(items: items, theme: theme, onAdd: _addNote),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.theme,
    required this.onAdd,
  });

  final List<KnowledgeItem> items;
  final ThemeData theme;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyHint(theme: theme, onAdd: onAdd);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _SectionHeader(title: '条目 (${items.length})'),
        _OutlinedCard(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.dividerColor),
                _ItemRow(item: items[i], theme: theme),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.theme});

  final KnowledgeItem item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        LucideIcons.fileText,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        item.title ?? item.source,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_typeLabel(item.type)} · ${_statusLabel(item.status)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
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

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.theme});

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
        _SectionHeader(title: '搜索结果 (${results.length})'),
        _OutlinedCard(
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.theme, required this.onAdd});

  final ThemeData theme;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
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
              '添加笔记后即可关键词搜索',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.filePlus, size: 18),
              label: const Text('添加笔记'),
            ),
          ],
        ),
      ),
    );
  }
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
