import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// 上下文占用分解（对标 CC /context）：按与真实请求相同的组成
/// （系统提示 / 工具定义 / 消息重放）估算各部分 token 占用。
/// 估算基于字符数启发式，真实占用以 API usage（contextTokens）为准。
class AgentContextBreakdown {
  const AgentContextBreakdown({
    required this.sections,
    this.apiContextTokens = 0,
    this.bulkClearable = const [],
    this.manuallyClearedIds = const {},
  });

  final List<ContextSection> sections;

  /// 「清理大输出」一键候选：可重取工具的大输出，最近几条不动。
  final List<ContextItem> bulkClearable;

  /// 当前被用户手动清理的工具调用 id（用于「恢复」）。
  final Set<String> manuallyClearedIds;

  int get bulkClearableTokens =>
      bulkClearable.fold(0, (sum, i) => sum + i.estimatedTokens);

  /// API usage 报告的真实上下文占用（0 = 未知）。
  final int apiContextTokens;

  int get estimatedTotal =>
      sections.fold(0, (sum, s) => sum + s.estimatedTokens);
}

/// 单个组成部分：标签 + 估算 token 数。
class ContextSection {
  const ContextSection({
    required this.label,
    required this.estimatedTokens,
    this.topItems = const [],
  });

  final String label;
  final int estimatedTokens;

  /// 本类里占用最多的若干条（按 token 降序，最多 [kContextTopItems] 条）。
  final List<ContextItem> topItems;
}

/// 分类明细里的一条：如某次 read_file 的结果、一条长用户消息。
class ContextItem {
  const ContextItem({
    required this.label,
    required this.estimatedTokens,
    this.eventId,
    this.clearable = false,
  });

  final String label;
  final int estimatedTokens;

  /// 对应的工具调用事件 id（仅工具结果有）。
  final String? eventId;

  /// 是否可手动清理（可重取工具的输出，且尚未被清理/占位）。
  final bool clearable;
}

/// 单条可手动清理的最小体量（太小清了没意义）。
const int kManualClearMinTokens = 300;

/// 一键清理只清这么大以上的输出。
const int kBulkClearMinTokens = 1500;

/// 每个分类展示的明细条数。
const int kContextTopItems = 5;

List<ContextItem> _topOf(List<ContextItem> items) {
  final sorted = [...items]
    ..sort((a, b) => b.estimatedTokens.compareTo(a.estimatedTokens));
  return sorted.take(kContextTopItems).toList(growable: false);
}

/// 单行预览：压空白、截断。
String _preview(String text, [int max = 40]) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max)}…';
}

/// 工具调用的简短参数：优先取常见的路径/命令字段。
String _argHint(String argsJson) {
  try {
    final decoded = jsonDecode(argsJson);
    if (decoded is Map) {
      for (final k in const [
        'path', 'file_path', 'command', 'pattern', 'query', 'url', 'name',
      ]) {
        final v = decoded[k];
        if (v is String && v.isNotEmpty) return _preview(v, 36);
      }
    }
  } catch (_) {}
  return '';
}

/// 单张图片的粗略 token 估算（浏览器设计稿 §20.3：字符代理看不到
/// 图片成本，按 provider 公式量级取 ~800 token/张）。
const int kEstimatedTokensPerImage = 800;

/// 字符数启发式估 token：CJK ≈ 1.5 字符/token，其余 ≈ 4 字符/token。
int estimateContextTokens(String text) {
  var cjk = 0;
  for (final code in text.runes) {
    if ((code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3000 && code <= 0x30FF) ||
        (code >= 0xFF00 && code <= 0xFFEF)) {
      cjk++;
    }
  }
  final other = text.length - cjk;
  return (cjk / 1.5 + other / 4).ceil();
}

/// 组装分解：系统提示 / 工具定义 / 用户消息 / 助手回复 /
/// 工具调用与结果 / 压缩摘要。
AgentContextBreakdown computeContextBreakdown({
  required String systemPrompt,
  required List<McpToolDefinition> toolDefinitions,
  required List<LlmMessage> messages,
  int apiContextTokens = 0,
  Set<String> manuallyClearedIds = const {},
}) {
  var toolDefs = 0;
  for (final d in toolDefinitions) {
    toolDefs += estimateContextTokens(
      '${d.name}\n${d.description}\n${jsonEncode(d.inputSchema)}',
    );
  }

  var userMessages = 0;
  var assistantText = 0;
  var toolTraffic = 0;
  var compaction = 0;
  var images = 0;
  final userItems = <ContextItem>[];
  final assistantItems = <ContextItem>[];
  final toolItems = <ContextItem>[];
  final compactionItems = <ContextItem>[];
  // tool_call id → 「工具名 参数」，给工具结果消息起名。
  final callLabels = <String, String>{};
  // 工具结果按出现顺序（算一键清理候选时保护最近几条）。
  final toolResults = <ContextItem>[];
  for (final m in messages) {
    var tokens = estimateContextTokens(m.content);
    images += (m.images?.length ?? 0) * kEstimatedTokensPerImage;
    final calls = m.toolCalls ?? const <LlmToolCall>[];
    for (final call in calls) {
      final hint = _argHint(call.arguments);
      callLabels[call.id] = hint.isEmpty ? call.name : '${call.name} $hint';
      tokens += estimateContextTokens('${call.name}${call.arguments}');
    }
    if (m.toolCallId != null || calls.isNotEmpty) {
      toolTraffic += tokens;
      final resultId = m.toolCallId;
      final label = resultId != null
          ? (callLabels[resultId] ?? '工具结果')
          : '调用 ${calls.map((c) => c.name).join('、')}';
      final clearable =
          resultId != null &&
          !manuallyClearedIds.contains(resultId) &&
          kMicroCompactableTools.contains(m.toolName) &&
          tokens >= kManualClearMinTokens;
      final item = ContextItem(
        label: label,
        estimatedTokens: tokens,
        eventId: resultId,
        clearable: clearable,
      );
      toolItems.add(item);
      if (resultId != null) toolResults.add(item);
    } else if (m.role == MessageRole.user) {
      if (m.content.startsWith('[上下文已压缩]') ||
          m.content.startsWith('[压缩前读过的文件快照]')) {
        compaction += tokens;
        compactionItems.add(
          ContextItem(label: _preview(m.content), estimatedTokens: tokens),
        );
      } else {
        userMessages += tokens;
        userItems.add(
          ContextItem(label: _preview(m.content), estimatedTokens: tokens),
        );
      }
    } else {
      assistantText += tokens;
      assistantItems.add(
        ContextItem(label: _preview(m.content), estimatedTokens: tokens),
      );
    }
  }

  final protectedFrom = toolResults.length - kMicroCompactKeepRecentToolCalls;
  final bulk = <ContextItem>[
    for (var i = 0; i < protectedFrom; i++)
      if (toolResults[i].clearable &&
          toolResults[i].estimatedTokens >= kBulkClearMinTokens)
        toolResults[i],
  ];

  return AgentContextBreakdown(
    apiContextTokens: apiContextTokens,
    bulkClearable: bulk,
    manuallyClearedIds: manuallyClearedIds,
    sections: [
      ContextSection(
        label: '系统提示',
        estimatedTokens: estimateContextTokens(systemPrompt),
      ),
      ContextSection(label: '工具定义', estimatedTokens: toolDefs),
      ContextSection(
        label: '用户消息',
        estimatedTokens: userMessages,
        topItems: _topOf(userItems),
      ),
      ContextSection(
        label: '助手回复',
        estimatedTokens: assistantText,
        topItems: _topOf(assistantItems),
      ),
      ContextSection(
        label: '工具调用与结果',
        estimatedTokens: toolTraffic,
        topItems: _topOf(toolItems),
      ),
      if (compaction > 0)
        ContextSection(
          label: '压缩摘要',
          estimatedTokens: compaction,
          topItems: _topOf(compactionItems),
        ),
      if (images > 0) ContextSection(label: '图片', estimatedTokens: images),
    ],
  );
}
