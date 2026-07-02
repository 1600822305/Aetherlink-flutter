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
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_add_sheets.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_base_settings_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_cloud_parsing_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_item_detail_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_recall_test_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_restore_embedding_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/sheets/knowledge_trash_sheet.dart';
import 'package:aetherlink_flutter/features/knowledge/presentation/mobile/widgets/knowledge_item_list.dart';
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

  /// 多选模式选中的条目 id（长按进入，清空即退出）。
  final Set<String> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  void _toggleSelected(KnowledgeItem item) {
    setState(() {
      if (!_selectedIds.add(item.id)) _selectedIds.remove(item.id);
    });
  }

  void _exitSelection() => setState(_selectedIds.clear);

  /// 批量重建选中条目的索引，逐条执行并汇总结果。
  Future<void> _reindexSelected() async {
    final ids = _selectedIds.toList();
    _exitSelection();
    var ok = 0;
    Object? firstError;
    for (final id in ids) {
      try {
        await ref
            .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
            .reindexItem(id);
        ok++;
      } catch (e) {
        firstError ??= e;
      }
    }
    if (!mounted) return;
    if (firstError == null) {
      AppToast.success(context, '已重建 $ok 个条目的索引');
    } else {
      AppToast.error(context, '重建完成 $ok/${ids.length}，首个错误：$firstError');
    }
  }

  /// 批量删除选中条目（移入回收站），删除前二次确认。
  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('将把选中的 ${ids.length} 个条目移入回收站，可从回收站恢复。'),
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
    if (ok != true || !mounted) return;
    _exitSelection();
    var deleted = 0;
    Object? firstError;
    for (final id in ids) {
      try {
        await ref
            .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
            .deleteItem(id);
        deleted++;
      } catch (e) {
        firstError ??= e;
      }
    }
    if (!mounted) return;
    if (firstError == null) {
      AppToast.success(context, '已删除 $deleted 个条目');
    } else {
      AppToast.error(context, '删除完成 $deleted/${ids.length}，首个错误：$firstError');
    }
  }

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
      builder: (ctx) => KnowledgeAddSourceSheet(
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
      builder: (ctx) => const KnowledgeAddNoteSheet(),
    );
    if (result == null || result.text.trim().isEmpty) return;
    await ref
        .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
        .addNote(title: result.title, text: result.text);
    if (mounted) AppToast.success(context, '已添加笔记');
  }

  /// 选择一个或多个文件并逐个摄取为条目。纯文本（含 csv / json）按 UTF-8
  /// 读取；HTML 用与 URL 抓取同一套转换器转 Markdown；DOCX / PPTX / XLSX /
  /// EPUB 在 isolate 里、PDF 在 PDFium 原生 worker 里转 Markdown（§5.2 本地
  /// 解析轨）后走同一条摄取管线；库配置了云端解析器时富文档改走云端预处理
  /// 轨，并额外放开 doc / ppt / xls 等仅云端轨支持的旧版格式（功能缺口④）。
  Future<void> _addFile() async {
    final base = await ref.read(
      knowledgeBaseControllerProvider(widget.baseId).future,
    );
    final processor = KnowledgeFileProcessor.fromId(base?.fileProcessorId);
    final pickedFiles = await ref
        .read(fileSystemApiProvider)
        .pickFiles(
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
    if (pickedFiles.isEmpty) return;
    if (pickedFiles.length == 1) {
      final error = await _ingestPickedFile(pickedFiles.first, processor);
      if (!mounted) return;
      if (error == null) {
        AppToast.success(context, '已上传「${pickedFiles.first.name}」');
      } else {
        AppToast.error(context, error);
      }
      return;
    }
    var ok = 0;
    String? firstError;
    for (final picked in pickedFiles) {
      final error = await _ingestPickedFile(picked, processor);
      if (error == null) {
        ok++;
      } else {
        firstError ??= '「${picked.name}」$error';
      }
    }
    if (!mounted) return;
    if (firstError == null) {
      AppToast.success(context, '已上传 $ok 个文件');
    } else {
      AppToast.error(context, '上传完成 $ok/${pickedFiles.length}，$firstError');
    }
  }

  /// 摄取单个已选文件；成功返回 null，失败返回面向用户的错误文案。
  Future<String?> _ingestPickedFile(
    PickedFile picked,
    KnowledgeFileProcessor? processor,
  ) async {
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
      return _ingestFileViaCloud(picked, processor);
    }
    if (isCloudOnly) {
      // 兜底：系统选择器可能忽略扩展名过滤（如部分 Android 实现）。
      return '该格式需要云端解析，请先在「云端解析」里配置解析器';
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
      return '读取文件失败：$e';
    }
    if (text.trim().isEmpty) {
      return isPdf ? 'PDF 无文本层（可能为扫描件），未摄取' : '文件内容为空，未摄取';
    }
    try {
      await ref
          .read(knowledgeItemsControllerProvider(widget.baseId).notifier)
          .addFile(fileName: picked.name, text: text, sourcePath: picked.path);
      return null;
    } catch (e) {
      return '上传失败：$e';
    }
  }

  /// 云端预处理轨（§5.2）：把原始字节交给库配置的云端解析器转 Markdown
  /// 权威快照后摄取。上传 + 轮询可能要几十秒到几分钟，先给提示。
  /// 成功返回 null，失败返回错误文案。
  Future<String?> _ingestFileViaCloud(
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
      return null;
    } catch (e) {
      return '云端解析失败：$e';
    }
  }

  /// 输入一个网址，抓取网页转成 Markdown 快照后摄取为条目（type=url）。
  Future<void> _addUrl() async {
    final result = await showModalBottomSheet<({String url, String title})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const KnowledgeAddUrlSheet(),
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
          builder: (ctx) => KnowledgeCloudParsingSheet(
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
    final result = await showModalBottomSheet<KnowledgeBaseSettingsResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => KnowledgeBaseSettingsSheet(base: base),
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
            // 换模型时检索模式交给 changeEmbeddingModel 一并落库（新模型
            // 尚未写入前按语义模式校验会被拒）。
            searchMode: modelChanged ? null : result.searchMode,
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
      await _applyEmbeddingModel(newModelKey, searchMode: result.searchMode);
    } else if (chunkingChanged) {
      await _refresh();
    }
  }

  /// 执行换嵌入模型 + 整库重建向量索引，并提示结果。
  Future<void> _applyEmbeddingModel(
    String modelKey, {
    KnowledgeSearchMode? searchMode,
  }) async {
    try {
      final count = await ref
          .read(knowledgeBaseControllerProvider(widget.baseId).notifier)
          .changeEmbeddingModel(modelKey, searchMode: searchMode);
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
      builder: (ctx) => KnowledgeRestoreEmbeddingSheet(base: base),
    );
    if (modelKey == null) return;
    await _applyEmbeddingModel(modelKey);
  }

  /// 条目详情面板：切块列表 + 重新索引 / 删除入口。
  Future<void> _showItemDetail(KnowledgeItem item) async {
    final action = await showModalBottomSheet<KnowledgeItemDetailAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => KnowledgeItemDetailSheet(item: item),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case KnowledgeItemDetailAction.delete:
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
      case KnowledgeItemDetailAction.reindex:
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
      builder: (ctx) => KnowledgeTrashSheet(baseId: widget.baseId),
    );
  }

  /// 召回测试面板：用于调参时验证检索效果，展示每条命中的分数与
  /// 来源条目 / 匹配切块全文。
  Future<void> _openRecallTest() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => KnowledgeRecallTestSheet(baseId: widget.baseId),
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
          child: _selectionMode
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(LucideIcons.x, size: 24),
                  color: theme.colorScheme.primary,
                  tooltip: '退出多选',
                  onPressed: _exitSelection,
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
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
        title: Text(
          _selectionMode
              ? '已选 ${_selectedIds.length} 项'
              : (baseName.isEmpty ? '知识库' : baseName),
        ),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 20),
                  color: theme.colorScheme.primary,
                  tooltip: '重建选中条目的索引',
                  onPressed: _reindexSelected,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 20),
                  color: theme.colorScheme.error,
                  tooltip: '删除选中条目',
                  onPressed: _deleteSelected,
                ),
                const SizedBox(width: 4),
              ]
            : [
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
                    _menuItem(
                      LucideIcons.cloudCog,
                      '云端解析设置',
                      _configureCloudParsing,
                    ),
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
                ? KnowledgeSearchResultsView(
                    results: _results!,
                    theme: theme,
                    items: itemsAsync.asData?.value ?? const [],
                    onTapItem: _showItemDetail,
                  )
                : itemsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('加载失败 · $err')),
                    data: (items) => KnowledgeItemListView(
                      items: items,
                      theme: theme,
                      onNote: _addNote,
                      onFile: _addFile,
                      onUrl: _addUrl,
                      onWorkspace: _addWorkspace,
                      onTapItem: _showItemDetail,
                      selectedIds: _selectedIds,
                      selectionMode: _selectionMode,
                      onToggleSelected: _toggleSelected,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
