/// 引擎控制工具的参数解析（update_plan / ask_user / finish_task /
/// exit_plan_mode）：纯函数，容错解析，失败时给安全的兜底值。
library;

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// update_plan 的全量计划条目。
List<AgentPlanItem> parsePlanItems(AgentToolCallRequest call) {
  try {
    final json = jsonDecode(call.argsJson) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in items.cast<Map<String, dynamic>>())
        AgentPlanItem(
          content: item['content'] as String? ?? '',
          status: switch (item['status'] as String?) {
            'in_progress' || 'inProgress' => AgentPlanItemStatus.inProgress,
            'completed' => AgentPlanItemStatus.completed,
            _ => AgentPlanItemStatus.pending,
          },
        ),
    ];
  } catch (_) {
    return const [];
  }
}

/// 取字符串参数；解析失败或类型不符返回 null。
String? stringArgOf(AgentToolCallRequest call, String key) {
  try {
    final json = jsonDecode(call.argsJson) as Map<String, dynamic>;
    return json[key] as String?;
  } catch (_) {
    return null;
  }
}

/// 从 exit_plan_mode 的参数 JSON 取方案全文（恢复时用）。
String planOfArgs(String? argsJson) {
  if (argsJson == null || argsJson.isEmpty) return '';
  try {
    final decoded = jsonDecode(argsJson);
    if (decoded is Map<String, dynamic>) {
      final plan = decoded['plan'];
      if (plan is String) return plan.trim();
    }
  } catch (_) {}
  return '';
}

/// 解析 ask_user 参数（RooCode ask_followup_question 风格）：
/// question + follow_up 建议答案列表。
(String, List<String>) parseUserQuestion(AgentToolCallRequest call) {
  try {
    final json = jsonDecode(call.argsJson) as Map<String, dynamic>;
    final question = (json['question'] as String? ?? '').trim();
    if (question.isNotEmpty) {
      return (question, _trimmedStrings(json['follow_up']));
    }
  } catch (_) {
    // 解析失败时仍落一个可回答的问题，避免任务挂起但 UI 无内容。
  }
  return ('需要你的输入', const []);
}

List<String> _trimmedStrings(Object? raw) {
  if (raw is! List<dynamic>) return const [];
  final result = <String>[];
  for (final item in raw.take(4)) {
    if (item is! String) continue;
    final normalized = item.trim();
    if (normalized.isEmpty || result.contains(normalized)) continue;
    result.add(normalized);
  }
  return result;
}
