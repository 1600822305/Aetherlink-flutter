import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// The synthetic tool name the model calls to read a skill's full instructions
/// — the port of the web `READ_SKILL_TOOL_NAME` (`SkillReadTool.ts`).
const String kReadSkillToolName = 'read_skill';

/// Virtual server marker for the [read_skill] tool: it belongs to no real MCP
/// server, so dispatch routes it in-process. Matches the web `'__skill__'`.
const String kSkillVirtualServer = '__skill__';

/// The `read_skill` tool definition injected when skills are enabled and the
/// assistant has bound (enabled) skills — the port of
/// `READ_SKILL_TOOL_DEFINITION`. The system prompt lists each skill's summary;
/// the model calls this to pull the full SKILL.md body on demand.
const McpToolDefinition kReadSkillToolDefinition = McpToolDefinition(
  name: kReadSkillToolName,
  description: '读取指定技能的完整指令内容。当用户的请求匹配某个已绑定技能时，先调用本工具获取该技能的详细指令，再按指令执行。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'skill_name': {
        'type': 'string',
        'description': '技能名称，对应系统提示词 Available skills 列表中的名称',
      },
    },
    'required': ['skill_name'],
  },
);

/// Looks up a skill by name in [skills] and returns its full content — the port
/// of the web `executeReadSkill`. Matching is exact → case-insensitive →
/// substring, mirroring the source. [skills] is the whole library; the
/// "available" fallback only lists enabled ones.
McpToolResult executeReadSkill(List<Skill> skills, Map<String, Object?> args) {
  final skillName = (args['skill_name'] as String?)?.trim();
  if (skillName == null || skillName.isEmpty) {
    return const McpToolResult('read_skill 需要提供 skill_name 参数', isError: true);
  }

  final lower = skillName.toLowerCase();
  Skill? skill = skills.where((s) => s.name == skillName).firstOrNull;
  skill ??= skills.where((s) => s.name.toLowerCase() == lower).firstOrNull;
  skill ??= skills
      .where((s) => s.name.toLowerCase().contains(lower))
      .firstOrNull;

  if (skill == null) {
    final available = skills
        .where((s) => s.enabled)
        .map((s) => s.name)
        .join(', ');
    return McpToolResult(
      '未找到技能: "$skillName"。可用的技能: ${available.isEmpty ? '无' : available}',
      isError: true,
    );
  }

  if (skill.content.isEmpty) {
    return McpToolResult(
      '技能 "${skill.name}" 没有详细指令内容。\n描述: ${skill.description}',
    );
  }

  return McpToolResult('# ${skill.name}\n\n${skill.content}');
}
