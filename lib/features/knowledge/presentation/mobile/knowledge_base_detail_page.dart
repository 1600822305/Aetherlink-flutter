// 单个知识库详情页 (route /settings/knowledge/:baseId).
//
// 轨道 A / UI 的最小闭环（设计文档 §10）：加笔记（含粘贴 txt/md 文本）+ 纯关键词
// 检索 + 条目列表。语义检索留待 P1。UI 对齐工作区管理页的卡片式风格。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/core/platform/file_system_api.dart'
    show PickedFile;
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_document_converter.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
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
    final result = await showModalBottomSheet<({String title, String text})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _AddNoteSheet(),
    );
    if (result == null || result.text.trim().isEmpty) return;
    await ref
        .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
        .addNote(title: result.title, text: result.text);
    if (mounted) AppToast.success(context, '已添加笔记');
  }

  /// 选择一个 txt / md / docx / pdf 文件并摄取为条目。纯文本按 UTF-8 读取；
  /// DOCX 在 isolate 里、PDF 在 PDFium 原生 worker 里转 Markdown（§5.2 本地解析轨）
  /// 后走同一条摄取管线；库配置了云端解析器时 PDF / DOCX 改走云端预处理轨。
  Future<void> _addFile() async {
    final picked = await ref
        .read(fileSystemApiProvider)
        .pickFile(
          allowedExtensions: const [
            'txt',
            'md',
            'markdown',
            'text',
            'docx',
            'pdf',
          ],
        );
    if (picked == null) return;
    final isPdf = isPdfFileName(picked.name);
    final isRichDoc = isPdf || isDocxFileName(picked.name);
    if (isRichDoc) {
      final base = await ref.read(
        knowledgeBaseControllerProvider(widget.baseId).future,
      );
      final processor = KnowledgeFileProcessor.fromId(base?.fileProcessorId);
      if (processor != null) {
        await _addFileViaCloud(picked, processor);
        return;
      }
    }
    String text;
    try {
      if (isDocxFileName(picked.name)) {
        final bytes = await ref
            .read(fileSystemApiProvider)
            .readAsBytes(picked.path);
        text = await convertDocxBytesToMarkdown(bytes);
      } else if (isPdf) {
        final bytes = await ref
            .read(fileSystemApiProvider)
            .readAsBytes(picked.path);
        text = await convertPdfBytesToMarkdown(bytes);
      } else {
        text = await ref.read(fileSystemApiProvider).readAsString(picked.path);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '读取文件失败：$e');
      return;
    }
    if (text.trim().isEmpty) {
      if (mounted) {
        AppToast.error(context, isPdf ? 'PDF 无文本层（可能为扫描件），未摄取' : '文件内容为空，未摄取');
      }
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

  /// 云端预处理轨（§5.2）：把原始字节交给库配置的云端解析器转 Markdown
  /// 权威快照后摄取。上传 + 轮询可能要几十秒到几分钟，先给提示。
  Future<void> _addFileViaCloud(
    PickedFile picked,
    KnowledgeFileProcessor processor,
  ) async {
    try {
      final bytes = await ref
          .read(fileSystemApiProvider)
          .readAsBytes(picked.path);
      if (mounted) {
        AppToast.success(context, '已交给 ${processor.label} 云端解析，完成后自动入库…');
      }
      await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .addProcessedFile(
            fileName: picked.name,
            bytes: bytes,
            sourcePath: picked.path,
          );
      if (mounted) {
        AppToast.success(
          context,
          '已通过 ${processor.label} 解析并上传「${picked.name}」',
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '云端解析失败：$e');
    }
  }

  /// 输入一个网址，抓取网页转成 Markdown 快照后摄取为条目（type=url）。
  Future<void> _addUrl() async {
    final result = await showModalBottomSheet<({String url, String title})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _AddUrlSheet(),
    );
    if (result == null || result.url.isEmpty) return;
    final url = result.url;
    final title = result.title;
    try {
      await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .addUrl(url: url, title: title.isEmpty ? null : title);
      if (mounted) AppToast.success(context, '已抓取「$url」');
    } catch (e) {
      if (mounted) AppToast.error(context, '抓取失败：$e');
    }
  }

  /// 选择一个「最近打开」的工作区，遍历其目录下文本文件摄取为条目（type=workspace）。
  /// 摄取时记录来源指纹，供检索时的 staleness 检测异步比对（设计文档 §8.1）。
  Future<void> _addWorkspace() async {
    final workspaces = await ref.read(workspaceStoreProvider.future);
    if (!mounted) return;
    if (workspaces.isEmpty) {
      AppToast.error(context, '还没有打开过工作区，先在「工作区」里打开一个目录');
      return;
    }
    final picked = await showModalBottomSheet<Workspace>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '选择工作区目录',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final w in workspaces)
              ListTile(
                onTap: () => Navigator.of(ctx).pop(w),
                leading: const Icon(LucideIcons.folder, size: 20),
                title: Text(w.name.isEmpty ? '未命名工作区' : w.name),
                subtitle: w.displayPath == null
                    ? null
                    : Text(
                        w.displayPath!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      final count = await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .addWorkspace(workspaceId: picked.id);
      if (mounted) AppToast.success(context, '已摄取「${picked.name}」（$count 个文件）');
    } catch (e) {
      if (mounted) AppToast.error(context, '摄取工作区失败：$e');
    }
  }

  /// 只补嵌失败/中断留下的待补切块（失败恢复，设计文档 §11），已嵌入的不重算。
  Future<void> _retryEmbeddings() async {
    try {
      final count = await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .retryEmbeddings();
      if (!mounted) return;
      if (count > 0) {
        AppToast.success(context, '已补嵌 $count 个切块');
      } else {
        AppToast.error(context, '本次未能补嵌，请检查嵌入模型后重试');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '补嵌失败：$e');
    }
  }

  /// 库级云端解析设置（§5.2 云端预处理轨）：选择 PDF / DOCX 的解析方式
  /// （本地 / MinerU / Doc2X / Mistral OCR）并填写对应服务的 API Key。
  Future<void> _configureCloudParsing() async {
    final base = await ref.read(
      knowledgeBaseControllerProvider(widget.baseId).future,
    );
    if (!mounted) return;
    final initialKeys = <KnowledgeFileProcessor, String>{};
    for (final p in KnowledgeFileProcessor.values) {
      final saved = await readKnowledgeFileProcessorApiKey(ref, p);
      initialKeys[p] = saved ?? '';
    }
    if (!mounted) return;
    final result =
        await showModalBottomSheet<
          ({KnowledgeFileProcessor? processor, String key})
        >(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => _CloudParsingSheet(
            initialProcessor: KnowledgeFileProcessor.fromId(
              base?.fileProcessorId,
            ),
            initialKeys: initialKeys,
          ),
        );
    if (result == null) return;
    try {
      final processor = result.processor;
      if (processor != null) {
        final key = result.key.trim();
        if (key.isEmpty) {
          if (mounted) {
            AppToast.error(context, '请填写 ${processor.label} 的 API Key');
          }
          return;
        }
        await saveKnowledgeFileProcessorApiKey(ref, processor, key);
      }
      await ref
          .read(knowledgeBaseControllerProvider(widget.baseId).notifier)
          .setFileProcessor(processor?.id);
      if (mounted) {
        AppToast.success(
          context,
          processor == null ? '已切回本地解析' : '已启用 ${processor.label} 云端解析',
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败：$e');
    }
  }

  /// 库设置（重命名 + RAG 参数）。切块参数变化时自动重建索引，让新参数
  /// 对已有条目生效。
  Future<void> _openBaseSettings() async {
    final base = await ref.read(
      knowledgeBaseControllerProvider(widget.baseId).future,
    );
    if (base == null || !mounted) return;
    final result = await showModalBottomSheet<_BaseSettingsResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _BaseSettingsSheet(base: base),
    );
    if (result == null) return;
    final chunkingChanged =
        result.chunkSize != base.chunkSize ||
        result.chunkOverlap != base.chunkOverlap;
    try {
      await ref
          .read(knowledgeBaseControllerProvider(widget.baseId).notifier)
          .updateConfig(
            name: result.name,
            chunkSize: result.chunkSize,
            chunkOverlap: result.chunkOverlap,
            topK: result.topK,
            threshold: result.threshold,
          );
      if (mounted) AppToast.success(context, '已保存库设置');
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败：$e');
      return;
    }
    if (chunkingChanged) await _refresh();
  }

  /// 条目详情面板：切块列表 + 删除入口。
  Future<void> _showItemDetail(KnowledgeItem item) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _ItemDetailSheet(item: item),
    );
    if (deleted != true || !mounted) return;
    try {
      await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .deleteItem(item.id);
      if (mounted) {
        AppToast.success(context, '已删除「${item.title ?? item.source}」');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '删除失败：$e');
    }
  }

  /// 召回测试面板：用于调参时验证检索效果，展示每条命中的分数与
  /// 来源条目 / 匹配切块全文。
  Future<void> _openRecallTest() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _RecallTestSheet(baseId: widget.baseId),
    );
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
    final pendingEmbeddings =
        ref
            .watch(knowledgePendingEmbeddingCountProvider(widget.baseId))
            .asData
            ?.value ??
        0;
    final baseName =
        ref
            .watch(knowledgeBaseControllerProvider(widget.baseId))
            .asData
            ?.value
            ?.name ??
        widget.baseName;

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
        title: Text(baseName.isEmpty ? '知识库' : baseName),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings2, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '库设置（重命名 / RAG 参数）',
            onPressed: _openBaseSettings,
          ),
          IconButton(
            icon: const Icon(LucideIcons.cloudCog, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '云端解析设置',
            onPressed: _configureCloudParsing,
          ),
          IconButton(
            icon: const Icon(LucideIcons.testTube2, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '检索测试',
            onPressed: _openRecallTest,
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '重建索引',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(LucideIcons.upload, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '上传文件（txt / md / docx / pdf）',
            onPressed: _addFile,
          ),
          IconButton(
            icon: const Icon(LucideIcons.link, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '添加网址',
            onPressed: _addUrl,
          ),
          IconButton(
            icon: const Icon(LucideIcons.folder, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '摄取工作区目录',
            onPressed: _addWorkspace,
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
          if (pendingEmbeddings > 0)
            MaterialBanner(
              backgroundColor: theme.colorScheme.errorContainer,
              content: Text(
                '有 $pendingEmbeddings 个切块嵌入未完成，向量检索可能不完整',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _retryEmbeddings,
                  child: const Text('重试嵌入'),
                ),
              ],
            ),
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
                    data: (items) => _ItemList(
                      items: items,
                      theme: theme,
                      onAdd: _addNote,
                      onTapItem: _showItemDetail,
                    ),
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
    required this.onTapItem,
  });

  final List<KnowledgeItem> items;
  final ThemeData theme;
  final VoidCallback onAdd;
  final ValueChanged<KnowledgeItem> onTapItem;

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
                _ItemRow(
                  item: items[i],
                  theme: theme,
                  onTap: () => onTapItem(items[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final KnowledgeItem item;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
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

/// Bottom-sheet 通用外壳：键盘避让 + 限高 + 标题 + 底部「取消 / 确认」操作行。
/// 表单控制器由各 State 持有，随退出动画结束后统一 dispose。
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...children,
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onConfirm, child: Text(confirmLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 添加笔记面板。
class _AddNoteSheet extends StatefulWidget {
  const _AddNoteSheet();

  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '添加笔记',
      confirmLabel: '保存',
      onConfirm: () => Navigator.of(
        context,
      ).pop((title: _titleController.text.trim(), text: _textController.text)),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: '标题（可选）'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
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
    );
  }
}

/// 添加网址面板。
class _AddUrlSheet extends StatefulWidget {
  const _AddUrlSheet();

  @override
  State<_AddUrlSheet> createState() => _AddUrlSheetState();
}

class _AddUrlSheetState extends State<_AddUrlSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '添加网址',
      confirmLabel: '抓取',
      onConfirm: () => Navigator.of(context).pop((
        url: _urlController.text.trim(),
        title: _titleController.text.trim(),
      )),
      children: [
        TextField(
          controller: _urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '网址',
            hintText: 'https://example.com/article',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: '标题（可选，留空用网页标题）'),
        ),
      ],
    );
  }
}

/// 云端解析设置面板（§5.2）：解析方式下拉 + 对应服务的 API Key。
class _CloudParsingSheet extends StatefulWidget {
  const _CloudParsingSheet({
    required this.initialProcessor,
    required this.initialKeys,
  });

  final KnowledgeFileProcessor? initialProcessor;
  final Map<KnowledgeFileProcessor, String> initialKeys;

  @override
  State<_CloudParsingSheet> createState() => _CloudParsingSheetState();
}

class _CloudParsingSheetState extends State<_CloudParsingSheet> {
  late KnowledgeFileProcessor? _selected = widget.initialProcessor;
  late final Map<KnowledgeFileProcessor, TextEditingController>
  _keyControllers = {
    for (final p in KnowledgeFileProcessor.values)
      p: TextEditingController(text: widget.initialKeys[p] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return _SheetScaffold(
      title: '云端解析设置',
      confirmLabel: '保存',
      onConfirm: () => Navigator.of(context).pop((
        processor: _selected,
        key: _selected == null ? '' : _keyControllers[_selected]!.text,
      )),
      children: [
        DropdownButtonFormField<KnowledgeFileProcessor?>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'PDF / DOCX 解析方式'),
          items: [
            const DropdownMenuItem<KnowledgeFileProcessor?>(
              value: null,
              child: Text('本地解析（默认，不上传）'),
            ),
            for (final p in KnowledgeFileProcessor.values)
              DropdownMenuItem<KnowledgeFileProcessor?>(
                value: p,
                child: Text(p.label),
              ),
          ],
          onChanged: (value) => setState(() => _selected = value),
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _keyControllers[selected]!,
            obscureText: true,
            decoration: InputDecoration(labelText: '${selected.label} API Key'),
          ),
          const SizedBox(height: 12),
          Text(
            '启用后本库的 PDF / DOCX 会上传到 ${selected.label} '
            '解析为 Markdown（注意隐私与费用）；解析结果作为权威快照'
            '落库，重建索引不会重复调用云端。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// [_BaseSettingsSheet] 的返回值：名称 + RAG 参数。
class _BaseSettingsResult {
  const _BaseSettingsResult({
    required this.name,
    required this.chunkSize,
    required this.chunkOverlap,
    required this.topK,
    required this.threshold,
  });

  final String name;
  final int chunkSize;
  final int chunkOverlap;
  final int topK;
  final double? threshold;
}

/// 库设置面板：重命名 + RAG 参数（切块大小 / 重叠 / topK / 相似度阈值）。
class _BaseSettingsSheet extends StatefulWidget {
  const _BaseSettingsSheet({required this.base});

  final KnowledgeBase base;

  @override
  State<_BaseSettingsSheet> createState() => _BaseSettingsSheetState();
}

class _BaseSettingsSheetState extends State<_BaseSettingsSheet> {
  late final _nameController = TextEditingController(text: widget.base.name);
  late final _chunkSizeController = TextEditingController(
    text: '${widget.base.chunkSize}',
  );
  late final _chunkOverlapController = TextEditingController(
    text: '${widget.base.chunkOverlap}',
  );
  late final _topKController = TextEditingController(
    text: '${widget.base.topK}',
  );
  late final _thresholdController = TextEditingController(
    text: widget.base.threshold?.toString() ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _chunkSizeController.dispose();
    _chunkOverlapController.dispose();
    _topKController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, '名称不能为空');
      return;
    }
    final chunkSize = int.tryParse(_chunkSizeController.text.trim());
    final chunkOverlap = int.tryParse(_chunkOverlapController.text.trim());
    final topK = int.tryParse(_topKController.text.trim());
    if (chunkSize == null || chunkOverlap == null || topK == null) {
      AppToast.error(context, '切块大小 / 重叠 / topK 需为整数');
      return;
    }
    final thresholdText = _thresholdController.text.trim();
    double? threshold;
    if (thresholdText.isNotEmpty) {
      threshold = double.tryParse(thresholdText);
      if (threshold == null || threshold < 0 || threshold > 1) {
        AppToast.error(context, '相似度阈值需为 0–1 的小数');
        return;
      }
    }
    Navigator.of(context).pop(
      _BaseSettingsResult(
        name: name,
        chunkSize: chunkSize,
        chunkOverlap: chunkOverlap,
        topK: topK,
        threshold: threshold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SheetScaffold(
      title: '库设置',
      confirmLabel: '保存',
      onConfirm: _submit,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chunkSizeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '切块大小',
                  helperText: '100–10000',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _chunkOverlapController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '切块重叠',
                  helperText: '需小于切块大小',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _topKController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '返回条数 topK',
                  helperText: '1–50',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '相似度阈值',
                  helperText: '0–1，留空不限',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '修改切块大小 / 重叠后会自动重建整库索引（向量库会按需补嵌，'
          '未变的内容不重复调用嵌入 API）。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 条目详情面板：元信息 + 切块列表 + 删除入口。删除前二次确认，确认后
/// pop(true) 交由页面执行删除。
class _ItemDetailSheet extends ConsumerWidget {
  const _ItemDetailSheet({required this.item});

  final KnowledgeItem item;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('将删除「${item.title ?? item.source}」及其全部切块与索引。此操作不可撤销。'),
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
    if (ok == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chunksAsync = ref.watch(knowledgeItemChunksProvider(item.id));
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
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                item.title ?? item.source,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                item.source,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            chunksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text('切块加载失败 · $err'),
              ),
              data: (chunks) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '切块 (${chunks.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final chunk in chunks)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${chunk.unitIndex + 1}'
                            '${chunk.embedded ? ' · 已嵌入' : ''}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            chunk.content,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () => _confirmDelete(context),
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: const Text('删除条目'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 召回测试面板（对齐 Cherry Studio 的 RecallTestPanel）：输入查询语句跑一次
/// 真实检索，逐条展示命中分数、来源条目与匹配切块全文，供调整 RAG 参数后
/// 立即验证召回效果。
class _RecallTestSheet extends ConsumerStatefulWidget {
  const _RecallTestSheet({required this.baseId});

  final String baseId;

  @override
  ConsumerState<_RecallTestSheet> createState() => _RecallTestSheetState();
}

class _RecallTestSheetState extends ConsumerState<_RecallTestSheet> {
  final _queryController = TextEditingController();
  List<KnowledgeReferenceItem>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(knowledgeServiceProvider)
          .search(baseId: widget.baseId, query: query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      AppToast.error(context, '检索失败：$e');
    }
  }

  static String _modeLabel(KnowledgeSearchMode mode) => switch (mode) {
    KnowledgeSearchMode.vector => '向量',
    KnowledgeSearchMode.keyword => '关键词',
    KnowledgeSearchMode.hybrid => '混合',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = ref
        .watch(knowledgeBaseControllerProvider(widget.baseId))
        .asData
        ?.value;
    final items =
        ref
            .watch(knowledgeItemsControllerProvider(widget.baseId))
            .asData
            ?.value ??
        const <KnowledgeItem>[];
    final titleById = {
      for (final item in items) item.id: item.title ?? item.source,
    };
    final results = _results;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  '检索测试',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (base != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    '模式 ${_modeLabel(base.searchMode)} · topK ${base.topK}'
                    '${base.threshold == null ? '' : ' · 阈值 ${base.threshold}'}'
                    ' —— 在「库设置」调整参数后可在此验证效果',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _run(),
                      decoration: InputDecoration(
                        hintText: '输入要测试的查询语句',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _searching ? null : _run,
                    child: const Text('检索'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (results != null && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '未召回任何切块，可尝试降低阈值或换检索模式',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else if (results != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    '召回 ${results.length} 条',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final hit in results)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${hit.index} · '
                                '${titleById[hit.documentId] ?? '未知来源'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(hit.similarity * 100).round()}%',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          hit.content,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
