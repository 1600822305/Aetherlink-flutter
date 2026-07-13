import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// 文本类附件的单附件长度上限（字符）：控制随消息进入上下文的体量。
const int kAgentAttachmentTextCap = 16000;

/// 超限截断并标注，避免单个大文件占满上下文。
String clipAgentAttachmentText(String text) => text.length <= kAgentAttachmentTextCap
    ? text
    : '${text.substring(0, kAgentAttachmentTextCap)}\n…(内容过长已截断)';

/// 任务绑定工作区的文件相对路径索引（@ 引用模糊搜索用）。
/// 跳过 .git 目录内容；索引受 [kMaxRecursiveEntries] 上限保护。
final agentWorkspaceFileIndexProvider = FutureProvider.autoDispose
    .family<List<String>, String?>((ref, workspaceId) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) return const [];
  final (workspace, backend) = resolved;
  final root = workspace.root.endsWith('/')
      ? workspace.root.substring(0, workspace.root.length - 1)
      : workspace.root;
  final listing = await listRecursive(backend, root, 10);
  return [
    for (final e in listing.entries)
      if (e['type'] == 'file')
        if ((e['path'] as String? ?? '').startsWith('$root/'))
          if (!(e['path'] as String).contains('/.git/'))
            (e['path'] as String).substring(root.length + 1),
  ];
});

/// 读取工作区文件为文本附件（@ 引用选中后调用）。
final agentWorkspaceFileAttachmentProvider = FutureProvider.autoDispose
    .family<AgentUserAttachment?, (String?, String)>((ref, args) async {
  final (workspaceId, relPath) = args;
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) return null;
  final (workspace, backend) = resolved;
  final root = workspace.root.endsWith('/')
      ? workspace.root.substring(0, workspace.root.length - 1)
      : workspace.root;
  final content = await backend.readFile('$root/$relPath');
  return AgentUserAttachment(
    kind: AgentAttachmentKind.file,
    name: relPath,
    text: clipAgentAttachmentText(content),
  );
});

/// 当前未提交改动清单 → 引用附件（无改动/不可用时返回 null）。
AgentUserAttachment? agentDiffAttachmentFrom(AgentChangesResult result) {
  final snapshot = result.snapshot;
  if (snapshot == null || snapshot.changes.isEmpty) return null;
  final lines = [
    for (final c in snapshot.changes)
      '${c.status.name} ${c.relPath}'
          '${c.additions != null || c.deletions != null ? ' +${c.additions ?? 0}/-${c.deletions ?? 0}' : ''}',
  ];
  return AgentUserAttachment(
    kind: AgentAttachmentKind.snippet,
    name: '当前改动清单（${snapshot.changes.length} 个文件）',
    text: clipAgentAttachmentText(lines.join('\n')),
  );
}

/// 终端输出尾部 → 引用附件（取最近一段，报错直接喂给模型）。
const int kAgentTerminalTailChars = 4000;

AgentUserAttachment agentTerminalAttachmentFrom(
  String sessionLabel,
  String snapshot,
) {
  final tail = snapshot.length <= kAgentTerminalTailChars
      ? snapshot
      : snapshot.substring(snapshot.length - kAgentTerminalTailChars);
  return AgentUserAttachment(
    kind: AgentAttachmentKind.snippet,
    name: '终端输出（$sessionLabel）',
    text: tail.trim(),
  );
}
