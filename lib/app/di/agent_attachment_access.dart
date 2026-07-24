import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// 文本类附件的单附件长度上限（字符）：控制随消息进入上下文的体量。
const int kAgentAttachmentTextCap = 16000;

/// 超限截断并标注，避免单个大文件占满上下文。
String clipAgentAttachmentText(String text) =>
    text.length <= kAgentAttachmentTextCap
    ? text
    : '${text.substring(0, kAgentAttachmentTextCap)}\n…(内容过长已截断)';

/// @ 引用浏览模式：单层目录列表（相对路径，'' 为根）。一次只发一个
/// listDir 请求，慢后端（SAF 等）也能即时展示，用户逐层自己选。
final agentWorkspaceDirProvider = FutureProvider.autoDispose
    .family<List<WorkspaceEntry>, (String?, String)>((ref, args) async {
      final (workspaceId, relDir) = args;
      final resolved = await resolveAgentWorkspace(ref, workspaceId);
      if (resolved == null) return const [];
      final (workspace, backend) = resolved;
      final root = workspace.root.endsWith('/')
          ? workspace.root.substring(0, workspace.root.length - 1)
          : workspace.root;
      final entries = await backend.listDir(
        relDir.isEmpty ? root : '$root/$relDir',
      );
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return entries;
    });

/// 任务绑定工作区的文件相对路径索引（@ 引用模糊搜索用）：边扫边出，
/// 按批 emit 增量结果，不必等整棵树走完才可搜。跳过依赖/构建目录
/// （[kListIgnoredDirs]），受 [kMaxRecursiveEntries] 上限保护；
/// 完成后缓存 2 分钟，重开搜索面板不重扫。
final agentWorkspaceFileIndexProvider = StreamProvider.autoDispose
    .family<({List<String> paths, bool done}), String?>((
      ref,
      workspaceId,
    ) async* {
      final link = ref.keepAlive();
      Timer? expiry;
      ref.onCancel(() {
        expiry = Timer(const Duration(minutes: 2), link.close);
      });
      ref.onResume(() => expiry?.cancel());
      ref.onDispose(() => expiry?.cancel());

      final resolved = await resolveAgentWorkspace(ref, workspaceId);
      if (resolved == null) {
        yield (paths: const <String>[], done: true);
        return;
      }
      final (workspace, backend) = resolved;
      final root = workspace.root.endsWith('/')
          ? workspace.root.substring(0, workspace.root.length - 1)
          : workspace.root;

      final out = <String>[];
      // 广度优先：浅层文件先出现在结果里，符合搜索直觉。
      final queue = <(String, int)>[(root, 1)];
      var sinceEmit = 0;
      while (queue.isNotEmpty && out.length < kMaxRecursiveEntries) {
        final (dir, depth) = queue.removeAt(0);
        List<WorkspaceEntry> entries;
        try {
          entries = await backend.listDir(dir);
        } catch (_) {
          continue;
        }
        entries.sort((a, b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? 1 : -1;
          return a.name.compareTo(b.name);
        });
        for (final e in entries) {
          if (out.length >= kMaxRecursiveEntries) break;
          if (e.isDirectory) {
            if (depth < 10 && !kListIgnoredDirs.contains(e.name)) {
              queue.add((e.path, depth + 1));
            }
          } else if (e.path.startsWith('$root/')) {
            out.add(e.path.substring(root.length + 1));
            sinceEmit++;
          }
        }
        if (sinceEmit >= 50) {
          sinceEmit = 0;
          yield (paths: List<String>.unmodifiable(out), done: false);
        }
      }
      yield (paths: List<String>.unmodifiable(out), done: true);
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
