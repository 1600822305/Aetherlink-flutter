// The `@aether/knowledge` built-in MCP server — 知识库的「聊天轨道」(轨道 B)。
//
// 完全套用 `@aether/file-editor` 的落地方式（设计文档 §7）：一个 [Ref] 依赖的
// 内置服务器，在进程内直接拿 Riverpod provider 执行；写操作（kb_manage）走
// 现成的 HITL 确认门控（与 `fileEditorRiskLevel` 同款分级）。
//
// 4 个工具：
//   kb_list   —— 列出所有知识库 / 某库的条目（只读）
//   kb_search —— 语义/关键词检索（只读，可跨库）
//   kb_read   —— 按条目取回完整正文（只读）
//   kb_manage —— 建库 / 加笔记 / 删库（写，需用户确认）
//
// 作用域：所有库对聊天一律可见/可操作（本来就是工具调用，不再设
// chatEnabled 门控）；智能体轨道（agentIds）预留。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_support.dart';

const String kKnowledgeServerName = '@aether/knowledge';
const String kKnowledgeListTool = 'kb_list';
const String kKnowledgeSearchTool = 'kb_search';
const String kKnowledgeReadTool = 'kb_read';
const String kKnowledgeManageTool = 'kb_manage';

/// Upper bound on the正文 returned by `kb_read`，避免一次把超大文档塞进上下文。
const int _kMaxReadChars = 8000;

/// 写操作的风险级别（与 `FileEditorRisk` 同构）。只有 `kb_manage` 是写工具，
/// 其余三个只读工具返回 null（不确认）。
enum KnowledgeToolRisk { medium, high }

/// `kb_manage` 各 action 的风险分级：删库高危，建库/加笔记/重建中危；
/// 只读工具与未知工具返回 null。分级供 HITL 门控与确认摘要复用。
KnowledgeToolRisk? knowledgeToolRiskLevel(
  String toolName,
  Map<String, Object?> args,
) {
  if (toolName != kKnowledgeManageTool) return null;
  final action = optionalKnowledgeString(args, 'action')?.toLowerCase();
  switch (action) {
    case 'delete':
      return KnowledgeToolRisk.high;
    case 'create':
    case 'add_note':
    case 'add_url':
    case 'add_workspace':
    case 'refresh':
    case 'retry_embeddings':
      return KnowledgeToolRisk.medium;
  }
  // 未知/缺失 action 也当作写操作，防御性地要求确认。
  return KnowledgeToolRisk.medium;
}

/// 是否需要用户确认——任何 `kb_manage` 调用（写操作）都需要。
bool knowledgeToolNeedsConfirmation(
  String toolName,
  Map<String, Object?> args,
) =>
    knowledgeToolRiskLevel(toolName, args) != null;

/// 当前是否存在知识库——供 chat_controller 决定是否即便 MCP 总开关关着
/// 也注入 `kb_search`。
Future<bool> hasChatEnabledKnowledgeBase(Ref ref) async {
  final bases = await ref.read(knowledgeServiceProvider).listBases();
  return bases.isNotEmpty;
}

/// Dispatches one `@aether/knowledge` tool call. Errors become a clean error
/// [McpToolResult]（与 `runFileEditorTool` 同款兜底）。
Future<McpToolResult> runKnowledgeTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args,
) async {
  final service = ref.read(knowledgeServiceProvider);
  try {
    switch (toolName) {
      case kKnowledgeListTool:
        return await _runList(service, args);
      case kKnowledgeSearchTool:
        return await _runSearch(service, args);
      case kKnowledgeReadTool:
        return await _runRead(service, args);
      case kKnowledgeManageTool:
        return await _runManage(service, args);
    }
    return knowledgeError('未知的知识库工具: $toolName');
  } on KnowledgeToolError catch (e) {
    return knowledgeError(e.message);
  } catch (e) {
    return knowledgeError('知识库工具执行失败: $e');
  }
}

// ── handlers ──

/// kb_list：不带 `base_id` 时列出所有库；带 `base_id` 时列出该库
/// 的条目。只读。
Future<McpToolResult> _runList(
  KnowledgeService service,
  Map<String, Object?> args,
) async {
  final baseId = optionalKnowledgeString(args, 'base_id');
  if (baseId == null) {
    final bases = await _allBases(service);
    final data = <Map<String, Object?>>[];
    for (final base in bases) {
      data.add({
        'id': base.id,
        'name': base.name,
        'searchMode': base.searchMode.name,
        'status': base.status.name,
        'itemCount': await service.itemCount(base.id),
      });
    }
    return knowledgeOk({'knowledgeBases': data});
  }

  final base = await _requireBase(service, baseId);
  final items = await service.listItems(base.id);
  return knowledgeOk({
    'knowledgeBaseId': base.id,
    'knowledgeBaseName': base.name,
    'items': [for (final item in items) _itemJson(item)],
  });
}

/// kb_search：检索。带 `base_id` 时只搜该库；否则跨所有库并按相似度
/// 融合。只读。
Future<McpToolResult> _runSearch(
  KnowledgeService service,
  Map<String, Object?> args,
) async {
  final query = requireKnowledgeString(args, 'query');
  final topK = optionalKnowledgeInt(args, 'top_k');
  final baseIdArg = optionalKnowledgeString(args, 'base_id');

  final List<KnowledgeBase> targets;
  if (baseIdArg != null) {
    targets = [await _requireBase(service, baseIdArg)];
  } else {
    targets = await _allBases(service);
  }
  if (targets.isEmpty) {
    return knowledgeError('当前没有知识库，可用 kb_manage 建库或请用户在知识库页面创建。');
  }

  final merged = <KnowledgeReferenceItem>[];
  for (final base in targets) {
    merged.addAll(
      await service.search(baseId: base.id, query: query, topK: topK),
    );
  }
  merged.sort((a, b) => b.similarity.compareTo(a.similarity));
  final limit = topK ?? KnowledgeBase.kDefaultTopK;
  final top = merged.take(limit).toList();

  return knowledgeOk({
    'query': query,
    'results': [
      for (var i = 0; i < top.length; i++)
        {
          'index': i + 1,
          'content': top[i].content,
          'similarity': top[i].similarity,
          'documentId': top[i].documentId,
          'knowledgeBaseId': top[i].knowledgeBaseId,
          'knowledgeBaseName': top[i].knowledgeBaseName,
        },
    ],
  });
}

/// kb_read：按 `base_id` + `document_id`（检索结果里的 documentId）取回条目完整正文。
/// 只读。超长正文截断到 [_kMaxReadChars]。
Future<McpToolResult> _runRead(
  KnowledgeService service,
  Map<String, Object?> args,
) async {
  final base = await _requireBase(
    service,
    requireKnowledgeString(args, 'base_id'),
  );
  final itemId = requireKnowledgeString(args, 'document_id');
  final item = await service.getItem(itemId);
  if (item == null || item.baseId != base.id) {
    throw KnowledgeToolError('条目不存在于知识库「${base.name}」: $itemId');
  }
  final content = await service.readItemContent(itemId) ?? '';
  final truncated = content.length > _kMaxReadChars;
  return knowledgeOk({
    'knowledgeBaseId': base.id,
    'knowledgeBaseName': base.name,
    'document': _itemJson(item),
    'content': truncated ? content.substring(0, _kMaxReadChars) : content,
    'truncated': truncated,
    if (truncated) 'totalChars': content.length,
  });
}

/// kb_manage：写操作，按 `action` 分流。调用点已过 HITL 确认，此处只执行。
Future<McpToolResult> _runManage(
  KnowledgeService service,
  Map<String, Object?> args,
) async {
  final action = requireKnowledgeString(args, 'action').toLowerCase();
  switch (action) {
    case 'create':
      final name = requireKnowledgeString(args, 'name');
      final embeddingModelKey =
          optionalKnowledgeString(args, 'embedding_model_key');
      final searchMode = _parseSearchMode(
        optionalKnowledgeString(args, 'search_mode'),
      );
      final base = await service.createBase(
        name: name,
        embeddingModelKey: embeddingModelKey,
        searchMode: searchMode,
      );
      return knowledgeOk({
        'action': 'create',
        'knowledgeBaseId': base.id,
        'knowledgeBaseName': base.name,
        'searchMode': base.searchMode.name,
      });
    case 'add_note':
      final base = await _requireBase(
        service,
        requireKnowledgeString(args, 'base_id'),
      );
      final text = requireKnowledgeString(args, 'text');
      final title = optionalKnowledgeString(args, 'title') ?? '';
      final item = await service.addNote(
        baseId: base.id,
        title: title,
        text: text,
      );
      return knowledgeOk({
        'action': 'add_note',
        'knowledgeBaseId': base.id,
        'documentId': item.id,
        'title': item.title,
      });
    case 'add_url':
      final base = await _requireBase(
        service,
        requireKnowledgeString(args, 'base_id'),
      );
      final url = requireKnowledgeString(args, 'url');
      final title = optionalKnowledgeString(args, 'title');
      // 抓取网页 → HTML 转 Markdown 快照 → 走与 note/file 一致的摄取管线
      // （设计文档 §5「URL 抓取」）。
      final item = await service.addUrl(
        baseId: base.id,
        url: url,
        title: title,
      );
      return knowledgeOk({
        'action': 'add_url',
        'knowledgeBaseId': base.id,
        'documentId': item.id,
        'title': item.title,
        'source': item.source,
      });
    case 'add_workspace':
      final base = await _requireBase(
        service,
        requireKnowledgeString(args, 'base_id'),
      );
      final workspaceId = requireKnowledgeString(args, 'workspace_id');
      // 遍历工作区目录下的文本文件逐个摄取（type=workspace），并记录来源指纹
      // 供 staleness 检测（设计文档 §8/§8.1）。
      final items = await service.addWorkspace(
        baseId: base.id,
        workspaceId: workspaceId,
      );
      return knowledgeOk({
        'action': 'add_workspace',
        'knowledgeBaseId': base.id,
        'workspaceId': workspaceId,
        'ingestedFiles': items.length,
        'documents': [
          for (final item in items)
            {'documentId': item.id, 'title': item.title},
        ],
      });
    case 'delete':
      final base = await _requireBase(
        service,
        requireKnowledgeString(args, 'base_id'),
      );
      await service.deleteBase(base.id);
      return knowledgeOk({
        'action': 'delete',
        'knowledgeBaseId': base.id,
        'knowledgeBaseName': base.name,
      });
    case 'refresh':
      final base = await _requireBase(
        service,
        requireKnowledgeString(args, 'base_id'),
      );
      // 从权威正文原子重建整库派生索引（切块 + 向量），未变内容命中已存向量、
      // 不重复调用嵌入 API（设计文档 §5.1）。
      final count = await service.reindexBase(base.id);
      return knowledgeOk({
        'action': 'refresh',
        'knowledgeBaseId': base.id,
        'knowledgeBaseName': base.name,
        'reindexedItems': count,
      });
    case 'retry_embeddings':
      final base = await _requireBase(
        service,
        requireKnowledgeString(args, 'base_id'),
      );
      // 失败恢复（设计文档 §11）：只补嵌嵌入失败/中断留下的待补切块，
      // 已嵌入的不重算、不重复扣费，比 refresh 整库重建轻。
      final embedded = await service.retryPendingEmbeddings(base.id);
      final remaining = await service.pendingEmbeddingCount(base.id);
      return knowledgeOk({
        'action': 'retry_embeddings',
        'knowledgeBaseId': base.id,
        'knowledgeBaseName': base.name,
        'embeddedChunks': embedded,
        'pendingChunks': remaining,
      });
  }
  throw KnowledgeToolError(
    '未知的 kb_manage 操作: $action（可用: create / add_note / add_url / '
    'add_workspace / delete / refresh / retry_embeddings）',
  );
}

// ── helpers ──

Future<List<KnowledgeBase>> _allBases(KnowledgeService service) =>
    service.listBases();

Future<KnowledgeBase> _requireBase(
  KnowledgeService service,
  String baseId,
) async {
  final base = await service.getBase(baseId);
  if (base == null) {
    throw KnowledgeToolError('知识库不存在: $baseId');
  }
  return base;
}

KnowledgeSearchMode _parseSearchMode(String? name) =>
    KnowledgeSearchMode.fromName(name?.toLowerCase());

Map<String, Object?> _itemJson(KnowledgeItem item) => {
      'documentId': item.id,
      'title': item.title ?? item.source,
      'type': item.type.name,
      'conceptId': item.conceptId,
      'status': item.status.name,
    };
