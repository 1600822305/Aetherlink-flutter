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

  /// 选择一个 txt / md / docx / pdf 文件并摄取为条目。纯文本按 UTF-8 读取；
  /// DOCX 在 isolate 里、PDF 在 PDFium 原生 worker 里转 Markdown（§5.2 本地解析轨）
  /// 后走同一条摄取管线；库配置了云端解析器时 PDF / DOCX 改走云端预处理轨。
  Future<void> _addFile() async {
    final picked = await ref.read(fileSystemApiProvider).pickFile(
      allowedExtensions: const ['txt', 'md', 'markdown', 'text', 'docx', 'pdf'],
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
        final bytes =
            await ref.read(fileSystemApiProvider).readAsBytes(picked.path);
        text = await convertDocxBytesToMarkdown(bytes);
      } else if (isPdf) {
        final bytes =
            await ref.read(fileSystemApiProvider).readAsBytes(picked.path);
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
        AppToast.error(
          context,
          isPdf ? 'PDF 无文本层（可能为扫描件），未摄取' : '文件内容为空，未摄取',
        );
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
      final bytes =
          await ref.read(fileSystemApiProvider).readAsBytes(picked.path);
      if (mounted) {
        AppToast.success(
          context,
          '已交给 ${processor.label} 云端解析，完成后自动入库…',
        );
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
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加网址'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '网址',
                  hintText: 'https://example.com/article',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题（可选，留空用网页标题）',
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
            child: const Text('抓取'),
          ),
        ],
      ),
    );
    final url = urlController.text.trim();
    final title = titleController.text.trim();
    urlController.dispose();
    titleController.dispose();
    if (saved != true || url.isEmpty) return;
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
    final picked = await showDialog<Workspace>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择工作区目录'),
        children: [
          for (final w in workspaces)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(w),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
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
            ),
        ],
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
    var selected = KnowledgeFileProcessor.fromId(base?.fileProcessorId);
    final keyControllers = {
      for (final p in KnowledgeFileProcessor.values)
        p: TextEditingController(),
    };
    for (final p in KnowledgeFileProcessor.values) {
      final saved = await readKnowledgeFileProcessorApiKey(ref, p);
      keyControllers[p]!.text = saved ?? '';
    }
    if (!mounted) {
      for (final c in keyControllers.values) {
        c.dispose();
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('云端解析设置'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<KnowledgeFileProcessor?>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'PDF / DOCX 解析方式',
                  ),
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
                  onChanged: (value) =>
                      setDialogState(() => selected = value),
                ),
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyControllers[selected]!,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '${selected!.label} API Key',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '启用后本库的 PDF / DOCX 会上传到 ${selected!.label} '
                    '解析为 Markdown（注意隐私与费用）；解析结果作为权威快照'
                    '落库，重建索引不会重复调用云端。',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
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
      ),
    );
    try {
      if (confirmed != true) return;
      final processor = selected;
      if (processor != null) {
        final key = keyControllers[processor]!.text.trim();
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
          processor == null
              ? '已切回本地解析'
              : '已启用 ${processor.label} 云端解析',
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败：$e');
    } finally {
      for (final c in keyControllers.values) {
        c.dispose();
      }
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
    final pendingEmbeddings = ref
            .watch(knowledgePendingEmbeddingCountProvider(widget.baseId))
            .asData
            ?.value ??
        0;

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
            icon: const Icon(LucideIcons.cloudCog, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '云端解析设置',
            onPressed: _configureCloudParsing,
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
