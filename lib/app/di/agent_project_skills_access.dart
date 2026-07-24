import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// 项目级技能加载 seam（与 `agent_subagent_access` 同款解析规则）：
/// 扫描绑定工作区的技能目录，随任务动态加载，只在该工作区的任务里
/// 可读，不写入全局技能库。每个技能是「子目录 + SKILL.md」（YAML
/// frontmatter 提供 name/description），也兼容目录下直接放 `*.md`
/// 单文件技能；同名以先扫到的目录优先。目录不存在 / 后端不可用返回空。
const List<String> kProjectSkillDirs = [
  '.aetherlink/skills',
  '.agents/skills',
  '.claude/skills',
  '.cursor/skills',
];

/// 项目技能的 id 前缀，与全局技能库的 id 空间隔开。
const String kProjectSkillIdPrefix = 'project-skill:';

Future<List<Skill>> loadProjectSkills(Ref ref, String? workspaceId) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) return const [];
  final (workspace, backend) = resolved;
  final root = workspace.root.endsWith('/')
      ? workspace.root.substring(0, workspace.root.length - 1)
      : workspace.root;

  final seen = <String>{};
  final skills = <Skill>[];
  for (final dir in kProjectSkillDirs) {
    List<WorkspaceEntry> entries;
    try {
      entries = await backend.listDir('$root/$dir');
    } catch (_) {
      continue; // 目录不存在或不可读：跳过。
    }
    for (final entry in entries) {
      try {
        String raw;
        String fallbackName;
        if (entry.isDirectory) {
          final md = (await backend.listDir(
            entry.path,
          )).where((e) => !e.isDirectory && e.name == 'SKILL.md').firstOrNull;
          if (md == null) continue;
          raw = await backend.readFile(md.path);
          fallbackName = entry.name;
        } else if (entry.name.endsWith('.md')) {
          raw = await backend.readFile(entry.path);
          fallbackName = entry.name.substring(0, entry.name.length - 3);
        } else {
          continue;
        }
        final skill = parseProjectSkillMarkdown(
          fallbackName,
          raw,
          sourceDir: dir,
        );
        if (seen.add(skill.name)) skills.add(skill);
      } catch (_) {}
    }
  }
  return skills;
}

/// 解析一个项目技能文件：YAML frontmatter 的 `name` / `description`
/// （缺省用目录/文件名），正文为 frontmatter 之后的 Markdown。
Skill parseProjectSkillMarkdown(
  String fallbackName,
  String raw, {
  required String sourceDir,
}) {
  var name = fallbackName;
  var description = '';
  var body = raw.trim();
  final lines = raw.split('\n');
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    final end = lines.indexWhere((l) => l.trim() == '---', 1);
    if (end > 0) {
      for (final line in lines.sublist(1, end)) {
        final idx = line.indexOf(':');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        final value = _stripQuotes(line.substring(idx + 1).trim());
        if (key == 'name' && value.isNotEmpty) name = value;
        if (key == 'description') description = value;
      }
      body = lines.sublist(end + 1).join('\n').trim();
    }
  }
  return Skill(
    id: '$kProjectSkillIdPrefix$sourceDir/$fallbackName',
    name: name,
    description: description,
    source: SkillSource.user,
    content: body,
    enabled: true,
  );
}

String _stripQuotes(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}
