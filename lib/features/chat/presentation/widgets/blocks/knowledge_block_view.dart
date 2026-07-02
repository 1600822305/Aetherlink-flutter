import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';

/// Compact rendering for the `@aether/knowledge` tools (kb_list / kb_search /
/// kb_read / kb_manage)：与 `@aether/file-editor` 只读工具同款的一行头部卡片
/// （图标 + 摘要 + 展开箭头），展开后按工具展示检索命中列表 / 库列表 / 正文
/// 预览 / 管理结果，替代默认的原始 JSON 工具卡。
class KnowledgeBlockView extends StatefulWidget {
  const KnowledgeBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<KnowledgeBlockView> createState() => _KnowledgeBlockViewState();
}

class _KnowledgeBlockViewState extends State<KnowledgeBlockView> {
  bool _expanded = false;

  ToolBlock get block => widget.block;
  String get _tool => block.toolName ?? '';
  Map<String, Object?> get _args => block.arguments ?? const {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = block.status;
    final isProcessing = status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error || _error() != null;
    final data = _data();

    final (icon, summary) = _header(data);
    final body = (!isProcessing && !hasError) ? _body(theme, data) : null;
    final canExpand = body != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: canExpand
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (isProcessing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      hasError ? LucideIcons.circleAlert : icon,
                      size: 15,
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isProcessing ? _processingLabel() : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasError ? theme.colorScheme.error : null,
                      ),
                    ),
                  ),
                  if (canExpand)
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasError && !isProcessing)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                _error() ?? '知识库工具执行失败',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (canExpand)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: body,
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );
  }

  // ----- header -----

  (IconData, String) _header(Map<String, Object?>? data) {
    switch (_tool) {
      case 'kb_search':
        final query =
            data?['query']?.toString() ?? _args['query']?.toString() ?? '';
        final results = data?['results'];
        final count = results is List ? results.length : 0;
        return (LucideIcons.search, '检索知识库「$query」· $count 条命中');
      case 'kb_list':
        final bases = data?['knowledgeBases'];
        if (bases is List) {
          return (LucideIcons.library, '知识库列表 · ${bases.length} 个库');
        }
        final name = data?['knowledgeBaseName']?.toString() ?? '';
        final items = data?['items'];
        final count = items is List ? items.length : 0;
        return (LucideIcons.library, '「$name」条目 · $count 条');
      case 'kb_read':
        final doc = data?['document'];
        final title = doc is Map ? doc['title']?.toString() ?? '' : '';
        final baseName = data?['knowledgeBaseName']?.toString() ?? '';
        return (LucideIcons.bookOpen, '读取「$title」（$baseName）');
      case 'kb_manage':
        final action = data?['action']?.toString() ??
            _args['action']?.toString() ??
            '';
        final baseName = data?['knowledgeBaseName']?.toString() ?? '';
        return (LucideIcons.bookMarked, '${_manageLabel(action)}$baseName');
    }
    return (LucideIcons.bookOpen, _tool);
  }

  String _manageLabel(String action) => switch (action) {
        'create' => '创建知识库 ',
        'add_note' => '添加笔记到知识库 ',
        'add_url' => '抓取网页到知识库 ',
        'add_workspace' => '摄取工作区到知识库 ',
        'delete' => '删除知识库 ',
        'refresh' => '重建索引 ',
        'retry_embeddings' => '补嵌向量 ',
        _ => '管理知识库 ',
      };

  String _processingLabel() => switch (_tool) {
        'kb_search' => '检索知识库中...',
        'kb_read' => '读取条目中...',
        'kb_manage' => '操作知识库中...',
        _ => '查询知识库中...',
      };

  // ----- body -----

  Widget? _body(ThemeData theme, Map<String, Object?>? data) {
    if (data == null) return null;
    switch (_tool) {
      case 'kb_search':
        return _searchBody(theme, data['results']);
      case 'kb_list':
        final bases = data['knowledgeBases'];
        if (bases is List) return _basesBody(theme, bases);
        return _itemsBody(theme, data['items']);
      case 'kb_read':
        return _readBody(theme, data);
      case 'kb_manage':
        return _manageBody(theme, data);
    }
    return null;
  }

  Widget _searchBody(ThemeData theme, Object? results) {
    if (results is! List || results.isEmpty) {
      return _emptyBody(theme, '没有命中的资料');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in results)
          if (r is Map) _searchHitRow(theme, r.cast<String, Object?>()),
      ],
    );
  }

  Widget _searchHitRow(ThemeData theme, Map<String, Object?> hit) {
    final index = hit['index'];
    final baseName = hit['knowledgeBaseName']?.toString() ?? '';
    final similarity = hit['similarity'];
    final content = hit['content']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$index',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  baseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (similarity is num)
                Text(
                  similarity.toStringAsFixed(2),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _basesBody(ThemeData theme, List<Object?> bases) {
    if (bases.isEmpty) return _emptyBody(theme, '暂无知识库');
    return Column(
      children: [
        for (final b in bases)
          if (b is Map)
            _simpleRow(
              theme,
              icon: LucideIcons.bookOpen,
              title: b['name']?.toString() ?? '',
              trailing: '${b['itemCount'] ?? 0} 条 · ${b['searchMode'] ?? ''}',
            ),
      ],
    );
  }

  Widget _itemsBody(ThemeData theme, Object? items) {
    if (items is! List || items.isEmpty) {
      return _emptyBody(theme, '库里还没有条目');
    }
    return Column(
      children: [
        for (final item in items)
          if (item is Map)
            _simpleRow(
              theme,
              icon: switch (item['type']?.toString()) {
                'url' => LucideIcons.link,
                'file' => LucideIcons.fileText,
                'workspace' => LucideIcons.folder,
                _ => LucideIcons.notebookPen,
              },
              title: item['title']?.toString() ?? '',
              trailing: item['status']?.toString(),
            ),
      ],
    );
  }

  Widget _readBody(ThemeData theme, Map<String, Object?> data) {
    final content = data['content']?.toString() ?? '';
    final truncated = data['truncated'] == true;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, style: theme.textTheme.bodySmall),
          if (truncated) ...[
            const SizedBox(height: 6),
            Text(
              '（正文过长已截断，共 ${data['totalChars']} 字）',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _manageBody(ThemeData theme, Map<String, Object?> data) {
    final entries = <(String, String)>[
      for (final MapEntry(:key, :value) in data.entries)
        if (value is! List && key != 'action')
          (_manageFieldLabel(key), value.toString()),
    ];
    final docs = data['documents'];
    if (entries.isEmpty && docs is! List) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(value, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (docs is List)
          for (final d in docs)
            if (d is Map)
              _simpleRow(
                theme,
                icon: LucideIcons.fileText,
                title: d['title']?.toString() ?? '',
              ),
        const SizedBox(height: 4),
      ],
    );
  }

  String _manageFieldLabel(String key) => switch (key) {
        'knowledgeBaseId' => '库 ID',
        'knowledgeBaseName' => '知识库',
        'documentId' => '条目 ID',
        'title' => '标题',
        'source' => '来源',
        'searchMode' => '检索模式',
        'workspaceId' => '工作区',
        'ingestedFiles' => '摄取文件',
        'reindexedItems' => '重建条目',
        'embeddedChunks' => '已补嵌',
        'pendingChunks' => '待补嵌',
        _ => key,
      };

  Widget _simpleRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (trailing != null && trailing.isNotEmpty)
            Text(
              trailing,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyBody(ThemeData theme, String message) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  // ----- result parsing -----

  Map<String, Object?>? _data() {
    final content = block.content;
    if (content is! String || content.isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) return data.cast<String, Object?>();
      }
    } catch (_) {}
    return null;
  }

  String? _error() {
    final content = block.content;
    if (content is String && content.isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map &&
            decoded['success'] == false &&
            decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
    }
    final blockErr = block.error;
    if (blockErr != null && blockErr['message'] is String) {
      return blockErr['message'] as String;
    }
    return null;
  }
}
