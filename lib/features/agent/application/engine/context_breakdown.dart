import 'dart:convert';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// 上下文占用分解（对标 CC /context）：按与真实请求相同的组成
/// （系统提示 / 工具定义 / 消息重放）估算各部分 token 占用。
/// 估算基于字符数启发式，真实占用以 API usage（contextTokens）为准。
class AgentContextBreakdown {
  const AgentContextBreakdown({
    required this.sections,
    this.apiContextTokens = 0,
  });

  final List<ContextSection> sections;

  /// API usage 报告的真实上下文占用（0 = 未知）。
  final int apiContextTokens;

  int get estimatedTotal =>
      sections.fold(0, (sum, s) => sum + s.estimatedTokens);
}

/// 单个组成部分：标签 + 估算 token 数。
class ContextSection {
  const ContextSection({required this.label, required this.estimatedTokens});

  final String label;
  final int estimatedTokens;
}

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
  for (final m in messages) {
    var tokens = estimateContextTokens(m.content);
    for (final call in m.toolCalls ?? const <LlmToolCall>[]) {
      tokens += estimateContextTokens('${call.name}${call.arguments}');
    }
    if (m.toolCallId != null || (m.toolCalls?.isNotEmpty ?? false)) {
      toolTraffic += tokens;
    } else if (m.role == MessageRole.user) {
      if (m.content.startsWith('[上下文已压缩]') ||
          m.content.startsWith('[压缩前读过的文件快照]')) {
        compaction += tokens;
      } else {
        userMessages += tokens;
      }
    } else {
      assistantText += tokens;
    }
  }

  return AgentContextBreakdown(
    apiContextTokens: apiContextTokens,
    sections: [
      ContextSection(
        label: '系统提示',
        estimatedTokens: estimateContextTokens(systemPrompt),
      ),
      ContextSection(label: '工具定义', estimatedTokens: toolDefs),
      ContextSection(label: '用户消息', estimatedTokens: userMessages),
      ContextSection(label: '助手回复', estimatedTokens: assistantText),
      ContextSection(label: '工具调用与结果', estimatedTokens: toolTraffic),
      if (compaction > 0)
        ContextSection(label: '压缩摘要', estimatedTokens: compaction),
    ],
  );
}
