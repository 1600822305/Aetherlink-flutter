import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/subagent_profile.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// 自定义子代理档案加载 seam（agent 不得 import workspace 内部实现）。
///
/// 扫描绑定工作区（解析规则与项目指令层一致）的
/// `.aetherlink/agents/*.md`，并兼容读 `.cursor/agents/*.md`；
/// 同名档案以 `.aetherlink` 优先。目录不存在 / 后端不可用返回空列表。
const List<String> kSubagentProfileDirs = [
  '.aetherlink/agents',
  '.cursor/agents',
];

Future<List<AgentSubagentProfile>> loadCustomSubagentProfiles(
  Ref ref,
  String? workspaceId,
) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) return const [];
  final (workspace, backend) = resolved;
  final root = workspace.root.endsWith('/')
      ? workspace.root.substring(0, workspace.root.length - 1)
      : workspace.root;

  final seen = <String>{};
  final profiles = <AgentSubagentProfile>[];
  for (final dir in kSubagentProfileDirs) {
    List<WorkspaceEntry> entries;
    try {
      entries = await backend.listDir('$root/$dir');
    } catch (_) {
      continue; // 目录不存在或不可读：跳过。
    }
    for (final entry in entries) {
      if (entry.isDirectory || !entry.name.endsWith('.md')) continue;
      try {
        final content = await backend.readFile(entry.path);
        final profile = parseSubagentProfileMarkdown(entry.name, content);
        if (profile != null && seen.add(profile.name)) {
          profiles.add(profile);
        }
      } catch (_) {}
    }
  }
  return profiles;
}
