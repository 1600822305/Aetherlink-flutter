/// 内置技能与工具分组的联动：技能依赖的工具分组在档案里关闭时，
/// 该技能既不注入系统提示，也不在智能体技能页展示（与工具动态
/// 注入同一开关，避免"技能在、工具不在"的悬空引用）。
library;

import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';

/// 内置技能 id → 依赖的工具分组；不在表内的技能不依赖特定分组，恒可用。
const Map<String, AgentToolGroup> kBuiltinSkillToolGroups = {
  'builtin-ppt-designer': AgentToolGroup.pptx,
  'builtin-browser': AgentToolGroup.webSearch,
};

/// [tools]（档案勾选的分组）下技能 [skillId] 是否可用。
bool builtinSkillAvailableFor(String skillId, Set<AgentToolGroup> tools) {
  final group = kBuiltinSkillToolGroups[skillId];
  return group == null || tools.contains(group);
}
