import 'dart:async';

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

/// 按工作区缓存的项目技能：系统提示每轮都要列清单、read_skill
/// 每次调用都要查找，慢后端（SAF 等）上重复扫目录 + 读全部
/// SKILL.md 很昂贵；扫一次后保活，无人监听 2 分钟后过期重扫。
final projectSkillsProvider = FutureProvider.autoDispose
    .family<List<Skill>, String?>((ref, workspaceId) {
      final link = ref.keepAlive();
      Timer? expiry;
      ref.onCancel(() {
        expiry = Timer(const Duration(minutes: 2), link.close);
      });
      ref.onResume(() => expiry?.cancel());
      ref.onDispose(() => expiry?.cancel());
      return loadProjectSkills(ref, workspaceId);
    });

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
        String? packageDir;
        if (entry.isDirectory) {
          final children = await backend.listDir(entry.path);
          final md = children
              .where((e) => !e.isDirectory && e.name == 'SKILL.md')
              .firstOrNull;
          if (md == null) continue;
          raw = await backend.readFile(md.path);
          fallbackName = entry.name;
          // 只有 SKILL.md 之外还有内容（scripts/references/assets…）
          // 才算带资源包，read_skill 才附清单。
          if (children.length > 1) packageDir = '$dir/${entry.name}';
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
          packageDir: packageDir,
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
  String? packageDir,
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
    packageDir: packageDir,
    enabled: true,
  );
}

/// 单个技能包清单的上限（条目数 / 递归深度）：防慢后端上的大目录
/// 扫描拖死 read_skill，也防清单膨胀挤爆上下文。
const int kSkillPackageMaxEntries = 80;
const int kSkillPackageMaxDepth = 3;

/// 列出项目技能包里 SKILL.md 之外的资源文件（scripts/references/
/// assets 等，限深度与条数），返回工作区相对路径清单；非目录型技能、
/// 目录不可读或没有额外文件时返回空。渐进披露：扫描/列清单时
/// 不读正文，模型按需用 read_file 读、用终端跑 scripts。
Future<List<String>> listSkillPackageFiles(
  Ref ref,
  String? workspaceId,
  Skill skill,
) async {
  final packageDir = skill.packageDir;
  if (packageDir == null) return const [];
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) return const [];
  final (workspace, backend) = resolved;
  final root = workspace.root.endsWith('/')
      ? workspace.root.substring(0, workspace.root.length - 1)
      : workspace.root;
  return walkSkillPackageFiles(backend, root, packageDir);
}

/// [listSkillPackageFiles] 的后端无关实现，便于用内存后端测试。
Future<List<String>> walkSkillPackageFiles(
  WorkspaceBackend backend,
  String root,
  String packageDir,
) async {
  final files = <String>[];
  Future<void> walk(String absDir, String relDir, int depth) async {
    if (depth > kSkillPackageMaxDepth ||
        files.length >= kSkillPackageMaxEntries) {
      return;
    }
    List<WorkspaceEntry> entries;
    try {
      entries = await backend.listDir(absDir);
    } catch (_) {
      return;
    }
    for (final entry in entries) {
      if (files.length >= kSkillPackageMaxEntries) return;
      final rel = '$relDir/${entry.name}';
      if (entry.isDirectory) {
        // 子目录用 listDir 返回的 entry.path 递归（SAF 等后端的
        // path 可能是不透明 URI，不能字符串拼接）。
        await walk(entry.path, rel, depth + 1);
      } else if (!(depth == 0 && entry.name == 'SKILL.md')) {
        files.add(rel);
      }
    }
  }

  await walk('$root/$packageDir', packageDir, 0);
  return files..sort();
}

String _stripQuotes(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}
