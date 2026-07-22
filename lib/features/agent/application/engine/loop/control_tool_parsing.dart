/// 引擎控制工具的参数解析（update_plan / ask_user / finish_task /
/// exit_plan_mode）：纯函数，容错解析，失败时给安全的兜底值。
library;

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// update_plan 的解析结果：要么是合法的全量条目，要么携带给模型的
/// 错误说明（拒绝提交，已有计划保持不变，绝不静默清空）。
sealed class PlanUpdateParse {
  const PlanUpdateParse();
}

class PlanUpdateOk extends PlanUpdateParse {
  const PlanUpdateOk(this.items);
  final List<AgentPlanItem> items;
}

class PlanUpdateInvalid extends PlanUpdateParse {
  const PlanUpdateInvalid(this.reason);
  final String reason;
}

/// update_plan 的全量计划条目：严格校验，任何非法输入都返回
/// [PlanUpdateInvalid]（错误回填给模型自我纠正），不做静默兜底。
PlanUpdateParse parsePlanUpdate(AgentToolCallRequest call) {
  final Object? decoded;
  try {
    decoded = jsonDecode(call.argsJson);
  } catch (_) {
    return const PlanUpdateInvalid('参数不是合法 JSON。');
  }
  if (decoded is! Map<String, dynamic>) {
    return const PlanUpdateInvalid('参数必须是包含 items 数组的对象。');
  }
  final rawItems = decoded['items'];
  if (rawItems is! List<dynamic>) {
    return const PlanUpdateInvalid('缺少 items 数组。');
  }
  if (rawItems.isEmpty) {
    return const PlanUpdateInvalid(
        'items 为空。update_plan 是全量覆盖式提交：若所有条目已完成，'
        '请把每项 status 置为 completed 后提交（计划会自动清空），不要提交空列表。');
  }
  final items = <AgentPlanItem>[];
  for (var i = 0; i < rawItems.length; i++) {
    final raw = rawItems[i];
    if (raw is! Map<String, dynamic>) {
      return PlanUpdateInvalid('items[$i] 不是对象。');
    }
    final content = raw['content'];
    if (content is! String || content.trim().isEmpty) {
      return PlanUpdateInvalid('items[$i].content 必须是非空字符串。');
    }
    final status = switch (raw['status']) {
      'pending' => AgentPlanItemStatus.pending,
      'in_progress' || 'inProgress' => AgentPlanItemStatus.inProgress,
      'completed' => AgentPlanItemStatus.completed,
      _ => null,
    };
    if (status == null) {
      return PlanUpdateInvalid('items[$i].status 非法（收到 ${raw['status']}）：'
          '必须是 pending / in_progress / completed。');
    }
    items.add(AgentPlanItem(content: content.trim(), status: status));
  }
  return PlanUpdateOk(items);
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
