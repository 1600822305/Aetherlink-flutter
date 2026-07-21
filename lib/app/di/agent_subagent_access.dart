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

/// 子代理持久记忆文件目录（工作区相对路径）。
const String kSubagentMemoryDir = '.aetherlink/agent-memory';

/// 读取某档案的持久记忆（对标 Claude Code agent-memory）：
/// 返回记忆文件的工作区绝对路径与现有内容（文件不存在时 content 为
/// null）；工作区不可用返回 null。文件名对档案名做保守清洗，防路径穿越。
Future<({String path, String? content})?> readSubagentMemory(
  Ref ref,
  String? workspaceId,
  String profileName,
) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) return null;
  final (workspace, backend) = resolved;
  final root = workspace.root.endsWith('/')
      ? workspace.root.substring(0, workspace.root.length - 1)
      : workspace.root;
  final safeName =
      profileName.replaceAll(RegExp(r'[^A-Za-z0-9_\u4e00-\u9fff-]'), '-');
  final path = '$root/$kSubagentMemoryDir/$safeName.md';
  String? content;
  try {
    content = await backend.readFile(path);
  } catch (_) {
    content = null; // 记忆文件尚不存在：首次运行。
  }
  return (path: path, content: content);
}
