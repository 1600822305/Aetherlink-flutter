import 'package:aetherlink_flutter/shared/config/builtin_skills/browser_skill.dart';
import 'package:aetherlink_flutter/shared/config/builtin_skills/subagent_dispatch_skill.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// 内置 skill 目录：每个 skill 单独一个文件放在
/// `lib/shared/config/builtin_skills/`，这里只做聚合（对齐 web 端
/// `src/shared/config/builtinSkills/*` 的组织方式）。
///
/// 只收录带真实 SKILL 正文（能给模型实际指令）的技能——没有正文的
/// 占位技能不进目录。下架的内置技能 id 记入
/// [kRetiredBuiltinSkillIds]，持久层据此清理旧种子。
const List<Skill> kBuiltinSkills = [
  kSubagentDispatchSkill,
  kBrowserSkill,
];

/// 曾随旧版本种子写入持久层、现已下架的内置 skill id。
/// [Skills.build] 启动时据此删除存量条目（用户自建技能不受影响）。
const Set<String> kRetiredBuiltinSkillIds = {
  'builtin-code-review',
  'builtin-unit-testing',
  'builtin-debugging',
  'builtin-refactoring',
  'builtin-git-assistant',
  'builtin-api-design',
  'builtin-sql-optimization',
  'builtin-doc-writing',
  'builtin-creative-writing',
  'builtin-meeting-notes',
  'builtin-data-analysis',
  'builtin-web-summary',
  'builtin-news-analysis',
  'builtin-translation',
  'builtin-mcp-bridge',
};
