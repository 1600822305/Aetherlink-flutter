import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_recall_history_controller.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 召回测试面板（对齐 Cherry Studio 的 RecallTestPanel）：输入查询语句跑一次
/// 真实检索，逐条展示命中分数、来源条目与匹配切块全文，供调整 RAG 参数后
/// 立即验证召回效果。
class KnowledgeRecallTestSheet extends ConsumerStatefulWidget {
  const KnowledgeRecallTestSheet({super.key, required this.baseId});

  final String baseId;

  @override
  ConsumerState<KnowledgeRecallTestSheet> createState() =>
      _KnowledgeRecallTestSheetState();
}

class _KnowledgeRecallTestSheetState
    extends ConsumerState<KnowledgeRecallTestSheet> {
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
    final history = ref.watch(
      knowledgeRecallHistoryControllerProvider,
    )[widget.baseId];
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
          // 标题 / 参数 / 查询输入区固定，仅结果列表滚动。
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
                child: Text(
                  '检索测试',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (base != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                  child: Text(
                    '模式 ${_modeLabel(base.searchMode)} · topK ${base.topK}'
                    '${base.threshold == null ? '' : ' · 阈值 ${base.threshold}'}'
                    ' —— 在「库设置」调整参数后可在此验证效果',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
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
              ),
              if (history != null && history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Wrap(
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
                ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
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
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${(hit.similarity * 100).round()}%',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
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
            ],
          ),
        ),
      ),
    );
  }
}
