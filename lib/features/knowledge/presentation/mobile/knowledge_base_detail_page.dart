// 单个知识库详情页 (route /settings/knowledge/:baseId).
//
// 轨道 A / UI 的最小闭环（设计文档 §10）：加笔记（含粘贴 txt/md 文本）+ 纯关键词
// 检索 + 条目列表。语义检索留待 P1。UI 对齐工作区管理页的卡片式风格。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/platform/file_system_api.dart'
    show PickedFile;
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_recall_history_controller.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_document_converter.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
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

  /// 「添加数据源」统一入口：上拉面板列出四种来源（笔记 / 文件 / 网址 / 工作区
  /// 目录），选中后走各自原有流程。
  Future<void> _openAddMenu() async {
    final action = await showModalBottomSheet<Future<void> Function()>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _AddSourceSheet(
        onNote: _addNote,
        onFile: _addFile,
        onUrl: _addUrl,
        onWorkspace: _addWorkspace,
      ),
    );
    if (action == null) return;
    await action();
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

  /// 选择一个文件并摄取为条目。纯文本（含 csv / json）按 UTF-8 读取；HTML 用
  /// 与 URL 抓取同一套转换器转 Markdown；DOCX / PPTX / XLSX / EPUB 在 isolate
  /// 里、PDF 在 PDFium 原生 worker 里转 Markdown（§5.2 本地解析轨）后走同一条
  /// 摄取管线；库配置了云端解析器时富文档改走云端预处理轨，并额外放开
  /// doc / ppt / xls 等仅云端轨支持的旧版格式（功能缺口④）。
  Future<void> _addFile() async {
    final base = await ref.read(
      knowledgeBaseControllerProvider(widget.baseId).future,
    );
    final processor = KnowledgeFileProcessor.fromId(base?.fileProcessorId);
    final picked = await ref
        .read(fileSystemApiProvider)
        .pickFile(
          allowedExtensions: [
            ...kPlainTextKnowledgeExtensions,
            'html',
            'htm',
            'docx',
            'pdf',
            ...kLocalOfficeKnowledgeExtensions,
            if (processor != null) ...kCloudOnlyKnowledgeExtensions,
          ],
        );
    if (picked == null) return;
    final isPdf = isPdfFileName(picked.name);
    final isCloudOnly = isCloudOnlyKnowledgeFileName(picked.name);
    final isRichDoc =
        isPdf ||
        isDocxFileName(picked.name) ||
        isPptxFileName(picked.name) ||
        isXlsxFileName(picked.name) ||
        isEpubFileName(picked.name) ||
        isCloudOnly;
    if (isRichDoc && processor != null) {
      await _addFileViaCloud(picked, processor);
      return;
    }
    if (isCloudOnly) {
      // 兜底：系统选择器可能忽略扩展名过滤（如部分 Android 实现）。
      if (mounted) {
        AppToast.error(context, '该格式需要云端解析，请先在「云端解析」里配置解析器');
      }
      return;
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
      } else if (isPptxFileName(picked.name)) {
        final bytes = await ref
            .read(fileSystemApiProvider)
            .readAsBytes(picked.path);
        text = await convertPptxBytesToMarkdown(bytes);
      } else if (isXlsxFileName(picked.name)) {
        final bytes = await ref
            .read(fileSystemApiProvider)
            .readAsBytes(picked.path);
        text = await convertXlsxBytesToMarkdown(bytes);
      } else if (isEpubFileName(picked.name)) {
        final bytes = await ref
            .read(fileSystemApiProvider)
            .readAsBytes(picked.path);
        text = await convertEpubBytesToMarkdown(bytes);
      } else if (isHtmlFileName(picked.name)) {
        final html = await ref
            .read(fileSystemApiProvider)
            .readAsString(picked.path);
        text = await convertHtmlTextToMarkdown(html);
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

  /// 库设置（重命名 + RAG 参数 + 嵌入模型）。切块参数变化时自动重建索引，
  /// 让新参数对已有条目生效；嵌入模型变化时整库重建向量索引（旧模型向量随之
  /// 清理，避免与新维度混存）。
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
    final newModelKey = result.embeddingModelKey;
    final modelChanged =
        newModelKey != null && newModelKey != base.embeddingModelKey;
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
      if (result.rerankModelKey != base.rerankModelKey) {
        await ref
            .read(knowledgeBaseControllerProvider(widget.baseId).notifier)
            .setRerankModel(result.rerankModelKey);
      }
      if (mounted) AppToast.success(context, '已保存库设置');
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败：$e');
      return;
    }
    if (modelChanged) {
      // 换模型的重建已覆盖切块参数变化，不再另跑一次 _refresh。
      await _applyEmbeddingModel(newModelKey);
    } else if (chunkingChanged) {
      await _refresh();
    }
  }

  /// 执行换嵌入模型 + 整库重建向量索引，并提示结果。
  Future<void> _applyEmbeddingModel(String modelKey) async {
    try {
      final count = await ref
          .read(knowledgeBaseControllerProvider(widget.baseId).notifier)
          .changeEmbeddingModel(modelKey);
      if (mounted) AppToast.success(context, '已更换嵌入模型并重建索引（$count 个条目）');
    } catch (e) {
      if (mounted) AppToast.error(context, '更换嵌入模型失败：$e');
    }
  }

  /// 换模型重建恢复入口（参考 CS RestoreKnowledgeBaseDialog）：嵌入失败 /
  /// 模型不可用的库选一个可用的嵌入模型后整库重建向量索引恢复。
  Future<void> _openRestoreEmbedding() async {
    final base = await ref.read(
      knowledgeBaseControllerProvider(widget.baseId).future,
    );
    if (base == null || !mounted) return;
    final modelKey = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _RestoreEmbeddingSheet(base: base),
    );
    if (modelKey == null) return;
    await _applyEmbeddingModel(modelKey);
  }

  /// 条目详情面板：切块列表 + 重新索引 / 删除入口。
  Future<void> _showItemDetail(KnowledgeItem item) async {
    final action = await showModalBottomSheet<_ItemDetailAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _ItemDetailSheet(item: item),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ItemDetailAction.delete:
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
      case _ItemDetailAction.reindex:
        try {
          final count = await ref
              .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
              .reindexItem(item.id);
          if (mounted) AppToast.success(context, '已重建索引（$count 个切块）');
        } catch (e) {
          if (mounted) AppToast.error(context, '重建索引失败：$e');
        }
    }
  }

  /// 回收站面板（功能缺口⑩）：列出软删除条目，支持恢复 / 彻底删除 / 清空。
  Future<void> _openTrash() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _TrashSheet(baseId: widget.baseId),
    );
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

  /// 「更多」菜单的一项：图标 + 文字标签，选中后执行 [action]。
  PopupMenuItem<VoidCallback> _menuItem(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
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
            icon: const Icon(LucideIcons.plus, size: 22),
            color: theme.colorScheme.primary,
            tooltip: '添加数据源',
            onPressed: _openAddMenu,
          ),
          PopupMenuButton<VoidCallback>(
            icon: Icon(
              LucideIcons.ellipsisVertical,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            tooltip: '更多',
            onSelected: (action) => action(),
            itemBuilder: (ctx) => [
              _menuItem(LucideIcons.settings2, '库设置', _openBaseSettings),
              _menuItem(LucideIcons.cloudCog, '云端解析设置', _configureCloudParsing),
              _menuItem(LucideIcons.testTube2, '检索测试', _openRecallTest),
              _menuItem(LucideIcons.refreshCw, '重建索引', _refresh),
              _menuItem(LucideIcons.trash2, '回收站', _openTrash),
            ],
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
                TextButton(
                  onPressed: _openRestoreEmbedding,
                  child: const Text('换模型重建'),
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
                      onNote: _addNote,
                      onFile: _addFile,
                      onUrl: _addUrl,
                      onWorkspace: _addWorkspace,
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
    required this.onNote,
    required this.onFile,
    required this.onUrl,
    required this.onWorkspace,
    required this.onTapItem,
  });

  final List<KnowledgeItem> items;
  final ThemeData theme;
  final VoidCallback onNote;
  final VoidCallback onFile;
  final VoidCallback onUrl;
  final VoidCallback onWorkspace;
  final ValueChanged<KnowledgeItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyHint(
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
    final statusColor = _statusColor(item.status, theme);
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
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${_typeLabel(item.type)} · '),
            TextSpan(
              text: _statusLabel(item.status),
              style: statusColor == null
                  ? null
                  : TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
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
  const _EmptyHint({
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

/// 「添加数据源」面板：四种来源各一行，点选后 pop 出对应动作由调用方执行
/// （先关面板再开来源自己的面板 / 选择器，避免嵌套导航）。
class _AddSourceSheet extends StatelessWidget {
  const _AddSourceSheet({
    required this.onNote,
    required this.onFile,
    required this.onUrl,
    required this.onWorkspace,
  });

  final Future<void> Function() onNote;
  final Future<void> Function() onFile;
  final Future<void> Function() onUrl;
  final Future<void> Function() onWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget entry({
      required IconData icon,
      required String title,
      required String subtitle,
      required Future<void> Function() action,
    }) {
      return ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => Navigator.of(context).pop(action),
      );
    }

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
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '添加数据源',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            entry(
              icon: LucideIcons.filePlus,
              title: '笔记',
              subtitle: '手写一段文本并摄取',
              action: onNote,
            ),
            entry(
              icon: LucideIcons.upload,
              title: '文件',
              subtitle: 'txt / md / html / docx / pdf / pptx / xlsx / epub，'
                  '配置云端解析后支持 doc / ppt / xls 等更多格式',
              action: onFile,
            ),
            entry(
              icon: LucideIcons.link,
              title: '网址',
              subtitle: '抓取网页正文并摄取',
              action: onUrl,
            ),
            entry(
              icon: LucideIcons.folder,
              title: '工作区目录',
              subtitle: '摄取工作区里的文本文件',
              action: onWorkspace,
            ),
          ],
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

/// [_BaseSettingsSheet] 的返回值：名称 + RAG 参数 + 重排模型 + 嵌入模型。
class _BaseSettingsResult {
  const _BaseSettingsResult({
    required this.name,
    required this.chunkSize,
    required this.chunkOverlap,
    required this.topK,
    required this.threshold,
    required this.rerankModelKey,
    required this.embeddingModelKey,
  });

  final String name;
  final int chunkSize;
  final int chunkOverlap;
  final int topK;
  final double? threshold;
  final String? rerankModelKey;
  final String? embeddingModelKey;
}

/// 库设置面板：重命名 + RAG 参数（切块大小 / 重叠 / topK / 相似度阈值）+
/// 重排序模型（功能缺口⑥，可选）。
class _BaseSettingsSheet extends ConsumerStatefulWidget {
  const _BaseSettingsSheet({required this.base});

  final KnowledgeBase base;

  @override
  ConsumerState<_BaseSettingsSheet> createState() => _BaseSettingsSheetState();
}

class _BaseSettingsSheetState extends ConsumerState<_BaseSettingsSheet> {
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
  late String? _rerankModelKey = widget.base.rerankModelKey;
  late String? _embeddingModelKey = widget.base.embeddingModelKey;

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
        rerankModelKey: _rerankModelKey,
        embeddingModelKey: _embeddingModelKey,
      ),
    );
  }

  Future<void> _pickEmbeddingModel() async {
    final pair = decodeEmbeddingModelKey(_embeddingModelKey);
    await showModelSelectorDialog(
      context,
      selectedProviderId: pair?.$1,
      selectedModelId: pair?.$2,
      filter: isEmbeddingModel,
      onSelect: (provider, model) {
        setState(() {
          _embeddingModelKey = encodeEmbeddingModelKey(provider.id, model.id);
        });
      },
    );
  }

  String _rerankModelDisplayName(List<ModelProvider> providers) {
    final pair = decodeEmbeddingModelKey(_rerankModelKey);
    if (pair == null) return '未选择（不重排）';
    for (final p in providers) {
      if (p.id != pair.$1) continue;
      for (final m in p.models) {
        if (m.id == pair.$2) return '${p.name} / ${m.name}';
      }
    }
    return '未选择（不重排）';
  }

  Future<void> _pickRerankModel() async {
    final pair = decodeEmbeddingModelKey(_rerankModelKey);
    await showModelSelectorDialog(
      context,
      selectedProviderId: pair?.$1,
      selectedModelId: pair?.$2,
      filter: isRerankModel,
      onSelect: (provider, model) {
        setState(() {
          _rerankModelKey = encodeEmbeddingModelKey(provider.id, model.id);
        });
      },
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
        const SizedBox(height: 12),
        Text(
          '嵌入模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        _EmbeddingModelField(
          modelKey: _embeddingModelKey,
          onTap: _pickEmbeddingModel,
        ),
        const SizedBox(height: 4),
        Text(
          '更换嵌入模型后会自动整库重建向量索引（旧模型的向量随之清理，'
          '全部内容需重新调用嵌入 API，注意耗时与费用）；'
          '纯关键词库选上模型后自动升级为混合检索。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '重排序模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickRerankModel,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  LucideIcons.arrowDownUp,
                  size: 18,
                  color: _rerankModelKey != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rerankModelDisplayName(
                      ref.watch(appModelProvidersProvider).asData?.value ??
                          const <ModelProvider>[],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _rerankModelKey != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_rerankModelKey != null)
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: '关闭重排',
                    onPressed: () => setState(() => _rerankModelKey = null),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '选了重排模型后，检索命中会再经 rerank API 按相关性重排；'
          '调用失败时自动保持原排序。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 嵌入模型选择行：展示当前模型（点击弹出模型选择器）+ 维度探测提示
/// （复用建库时的 knowledgeEmbeddingDimensionsProvider）。
class _EmbeddingModelField extends ConsumerWidget {
  const _EmbeddingModelField({required this.modelKey, required this.onTap});

  final String? modelKey;
  final VoidCallback onTap;

  String _displayName(List<ModelProvider> providers) {
    final pair = decodeEmbeddingModelKey(modelKey);
    if (pair == null) return '未选择（纯关键词检索）';
    for (final p in providers) {
      if (p.id != pair.$1) continue;
      for (final m in p.models) {
        if (m.id == pair.$2) return '${p.name} / ${m.name}';
      }
    }
    return '${pair.$1} / ${pair.$2}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasModel = modelKey != null;
    final providers =
        ref.watch(appModelProvidersProvider).asData?.value ??
        const <ModelProvider>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
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
                    _displayName(providers),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasModel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasModel) _DimensionHint(modelKey: modelKey!),
      ],
    );
  }
}

/// 嵌入模型的维度探测提示（同建库面板）：选中模型后真实调一次嵌入 API 展示
/// 「向量维度：N」；探测中显示进度、失败提示不阻断保存。
class _DimensionHint extends ConsumerWidget {
  const _DimensionHint({required this.modelKey});

  final String modelKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(knowledgeEmbeddingDimensionsProvider(modelKey));
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget child;
    if (async.isLoading) {
      child = Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text('正在探测向量维度…', style: style),
        ],
      );
    } else {
      final dimensions = async.asData?.value;
      child = Text(
        dimensions == null ? '维度探测失败（模型可能不可用）' : '向量维度：$dimensions',
        style: dimensions == null
            ? style
            : style?.copyWith(color: theme.colorScheme.primary),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 26),
      child: child,
    );
  }
}

/// 换模型重建面板（参考 CS RestoreKnowledgeBaseDialog）：说明当前库的嵌入
/// 状况，选一个可用的嵌入模型后 pop 出模型键，由页面执行整库重建恢复。
class _RestoreEmbeddingSheet extends ConsumerStatefulWidget {
  const _RestoreEmbeddingSheet({required this.base});

  final KnowledgeBase base;

  @override
  ConsumerState<_RestoreEmbeddingSheet> createState() =>
      _RestoreEmbeddingSheetState();
}

class _RestoreEmbeddingSheetState
    extends ConsumerState<_RestoreEmbeddingSheet> {
  late String? _modelKey = widget.base.embeddingModelKey;

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
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelKey = _modelKey;
    return _SheetScaffold(
      title: '换模型重建',
      confirmLabel: '重建恢复',
      onConfirm: modelKey == null
          ? null
          : () => Navigator.of(context).pop(modelKey),
      children: [
        Text(
          '本库存在嵌入未完成的切块（嵌入失败或模型不可用）。选择一个可用的'
          '嵌入模型后将整库重建向量索引：旧模型的向量会被清理，全部内容需'
          '重新调用嵌入 API（注意耗时与费用）。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '嵌入模型',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        _EmbeddingModelField(modelKey: _modelKey, onTap: _pickModel),
      ],
    );
  }
}

/// 条目详情面板：元信息 + 切块列表 + 删除入口。删除前二次确认，确认后
/// pop(true) 交由页面执行删除。
/// [_ItemDetailSheet] 关闭时要求调用方执行的动作。
enum _ItemDetailAction { reindex, delete }

class _ItemDetailSheet extends ConsumerWidget {
  const _ItemDetailSheet({required this.item});

  final KnowledgeItem item;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('将把「${item.title ?? item.source}」移入回收站，可从回收站恢复。'),
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
    if (ok == true && context.mounted) {
      Navigator.of(context).pop(_ItemDetailAction.delete);
    }
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
            if (item.status == KnowledgeItemStatus.failed &&
                (item.error?.isNotEmpty ?? false))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '摄取失败',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
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
              onPressed: () =>
                  Navigator.of(context).pop(_ItemDetailAction.reindex),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('重新索引此条目'),
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

/// 回收站面板（功能缺口⑩）：展示本库软删除条目，每条可恢复（从保留正文重建
/// 索引）或彻底删除，并支持一键清空。
class _TrashSheet extends ConsumerWidget {
  const _TrashSheet({required this.baseId});

  final String baseId;

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    KnowledgeItem item,
  ) async {
    try {
      await ref
          .read(knowledgeItemsControllerProvider(baseId).notifier)
          .restoreItem(item.id);
      if (context.mounted) {
        AppToast.success(context, '已恢复「${item.title ?? item.source}」');
      }
    } catch (e) {
      if (context.mounted) AppToast.error(context, '恢复失败：$e');
    }
  }

  Future<void> _purge(
    BuildContext context,
    WidgetRef ref,
    KnowledgeItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('将彻底删除「${item.title ?? item.source}」及其正文。此操作不可撤销。'),
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
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(knowledgeItemsControllerProvider(baseId).notifier)
          .purgeItem(item.id);
      if (context.mounted) {
        AppToast.success(context, '已彻底删除「${item.title ?? item.source}」');
      }
    } catch (e) {
      if (context.mounted) AppToast.error(context, '删除失败：$e');
    }
  }

  Future<void> _emptyTrash(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('将彻底删除回收站里的全部条目。此操作不可撤销。'),
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
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final count = await ref
          .read(knowledgeItemsControllerProvider(baseId).notifier)
          .emptyTrash();
      if (context.mounted) AppToast.success(context, '已清空回收站（$count 个条目）');
    } catch (e) {
      if (context.mounted) AppToast.error(context, '清空失败：$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trashAsync = ref.watch(knowledgeTrashProvider(baseId));
    final items = trashAsync.asData?.value ?? const <KnowledgeItem>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '回收站 (${items.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (items.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _emptyTrash(context, ref),
                    child: const Text('清空'),
                  ),
              ],
            ),
            if (trashAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '回收站是空的',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    LucideIcons.trash2,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    item.title ?? item.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: item.deletedAt == null
                      ? null
                      : Text(
                          '删除于 ${_formatTime(item.deletedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.undo2, size: 18),
                        color: theme.colorScheme.primary,
                        tooltip: '恢复',
                        onPressed: () => _restore(context, ref, item),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        color: theme.colorScheme.error,
                        tooltip: '彻底删除',
                        onPressed: () => _purge(context, ref, item),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} '
        '${pad(time.hour)}:${pad(time.minute)}';
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
      ref
          .read(knowledgeRecallHistoryControllerProvider.notifier)
          .record(widget.baseId, query);
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

  void _runHistory(String query) {
    _queryController.text = query;
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref
        .watch(knowledgeRecallHistoryControllerProvider)[widget.baseId];
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
              if (history != null && history.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final query in history)
                      InputChip(
                        label: Text(
                          query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: _searching
                            ? null
                            : () => _runHistory(query),
                        onDeleted: () => ref
                            .read(
                              knowledgeRecallHistoryControllerProvider
                                  .notifier,
                            )
                            .remove(widget.baseId, query),
                        deleteIcon: const Icon(LucideIcons.x, size: 14),
                      ),
                  ],
                ),
              ],
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
