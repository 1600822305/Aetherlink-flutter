import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/load_mcp_tools_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';

/// 技能 → 延迟工具组绑定：read_skill 成功读取该技能后，下一轮请求
/// 才把对应工具组的定义注入 tools 列表（渐进披露，对标 CC 的
/// deferred tool loading）。key 为技能 id，value 为 builtin server 名
/// （仅声明语义，工具定义本体在 [DynamicToolCatalog.deferred]）。
const Map<String, String> kSkillToolBindings = {
  'builtin-browser': '@aether/browser',
  'builtin-subagent-dispatch': 'spawn_subagent',
};

/// 外部 MCP 延迟组的 key 前缀：与技能 id key 同住 [DynamicToolCatalog.deferred]，
/// 靠前缀区分激活来源（read_skill vs load_mcp_tools）。
const String kMcpDeferredKeyPrefix = 'mcp:';

String mcpDeferredKey(String serverId) => '$kMcpDeferredKeyPrefix$serverId';

/// 常驻 + 延迟两段式工具目录。routes 永远全量（不发给模型，只用于
/// 执行分发 / 重放 / 审批判定），只有发给模型的 definitions 按激活
/// 状态裁剪。
class DynamicToolCatalog {
  DynamicToolCatalog({
    required this.resident,
    required this.deferred,
    required this.routes,
    Map<String, String>? deferredMcpLabels,
  }) : deferredMcpLabels = deferredMcpLabels ?? {};

  /// 每轮请求恒定发送的工具定义。
  final List<McpToolDefinition> resident;

  /// skillId → 该技能绑定的延迟工具定义组。
  final Map<String, List<McpToolDefinition>> deferred;

  /// 全量执行分发表（含延迟组），审批门与重放共用。
  final Map<String, ToolRoute> routes;

  /// 外部 MCP 延迟组的展示名：`mcp:<serverId>` → 服务器名称（系统提示
  /// 「外部 MCP 服务器」清单用）。
  final Map<String, String> deferredMcpLabels;

  /// 本轮发送给模型的定义：常驻 + 已激活延迟组（技能 id 或 mcp: key）。
  List<McpToolDefinition> definitionsFor(Set<String> activatedSkillIds) => [
    ...resident,
    for (final id in activatedSkillIds) ...?deferred[id],
  ];

  /// 工具是否在目录内（常驻或任意延迟组），与激活状态无关。
  bool hasTool(String name) =>
      resident.any((d) => d.name == name) ||
      deferred.values.any((defs) => defs.any((d) => d.name == name));
}

/// 从**原始 append-only 事件流**扫描已激活的绑定技能。
///
/// 必须扫原始事件而非 fold/microcompact 后的视图——压缩摘要会吞掉
/// read_skill 工具事件，导致压缩后激活状态丢失（对标 CC 的
/// preCompactDiscoveredTools 快照所防的同一问题）。事件流本身就是
/// 激活记录：任务续跑 / 应用重启后按同一扫描恢复，无需新增存储。
/// 技能名匹配复用 [matchSkillByName]（与 executeReadSkill 同款
/// 精确 → 忽略大小写 → 子串三段式），避免读到了技能但没激活工具的错位。
Set<String> activatedSkillIdsFromEvents(
  List<AgentEvent> events,
  List<Skill> skills,
) {
  final activated = <String>{};
  for (final event in events) {
    if (event is! ToolCallEvent) continue;
    if (event.toolName != kReadSkillToolName) continue;
    if (event.state != AgentToolCallState.success) continue;
    final requested = _requestedSkillName(event);
    if (requested == null) continue;
    final skill = matchSkillByName(skills, requested);
    if (skill == null) continue;
    if (kSkillToolBindings.containsKey(skill.id)) activated.add(skill.id);
  }
  return activated;
}

/// 从原始事件流扫描已装载的外部 MCP 延迟组（load_mcp_tools 成功事件）。
/// 服务器定位复用 [matchMcpServerByName]（与执行侧同款宽松匹配），
/// 扫描约束与 [activatedSkillIdsFromEvents] 同：只认成功事件、
/// 只扫原始事件而非压缩视图、重复装载幂等（集合语义）。
Set<String> activatedMcpServerKeysFromEvents(
  List<AgentEvent> events,
  List<McpServer> servers,
) {
  final activated = <String>{};
  for (final event in events) {
    if (event is! ToolCallEvent) continue;
    if (event.toolName != kLoadMcpToolsToolName) continue;
    if (event.state != AgentToolCallState.success) continue;
    final requested = _requestedServerName(event);
    if (requested == null) continue;
    final server = matchMcpServerByName(servers, requested);
    if (server == null) continue;
    activated.add(mcpDeferredKey(server.id));
  }
  return activated;
}

String? _requestedServerName(ToolCallEvent event) {
  final args = event.argsDetail;
  if (args != null) {
    try {
      final decoded = jsonDecode(args);
      if (decoded is Map<String, dynamic>) {
        final name = decoded['server'];
        if (name is String && name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {}
  }
  // 兜底：执行侧成功结果固定以「已装载服务器「<名称>」…」开头。
  final detail = event.resultDetail;
  const prefix = '已装载服务器「';
  if (detail != null && detail.startsWith(prefix)) {
    final rest = detail.substring(prefix.length);
    final end = rest.indexOf('」');
    if (end > 0) return rest.substring(0, end);
  }
  return null;
}

String? _requestedSkillName(ToolCallEvent event) {
  final args = event.argsDetail;
  if (args != null) {
    try {
      final decoded = jsonDecode(args);
      if (decoded is Map<String, dynamic>) {
        final name = decoded['skill_name'];
        if (name is String && name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {}
  }
  // 兜底：executeReadSkill 成功结果首行固定为「# <技能名>」。
  final detail = event.resultDetail;
  if (detail != null && detail.startsWith('# ')) {
    return detail.split('\n').first.substring(2).trim();
  }
  return null;
}
