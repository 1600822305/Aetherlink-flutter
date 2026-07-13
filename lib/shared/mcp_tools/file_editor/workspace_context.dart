// 工作区上下文注入 — 启用 @aether/file-editor 工具时，把当前工作区的基本
// 信息（名称/后端/根路径/顶层内容）直接拼进系统提示，AI 开局即知工作范围，
// 不必每轮先调 list_files 探路。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// Cap on top-level entries listed in the injected section, so a huge
/// workspace root can't bloat every turn's system prompt.
const int kWorkspaceContextMaxEntries = 30;

/// Builds the `[工作区上下文]` system-prompt section: the current workspace
/// (name / backend / root / top-level entries) plus the other opened
/// workspaces by name. Returns null when no workspace is opened, and never
/// throws — a failing backend just omits the listing.
///
/// [workspace] 锁定锚点工作区（智能体任务绑定的工作区），缺省取当前
/// 工作区；[listOthers] 为 false 时不向模型暴露其他已打开的工作区
/// （绑定工作区的任务硬隔离）。
Future<String?> buildWorkspaceContextSection(
  Ref ref, {
  Workspace? workspace,
  bool listOthers = true,
}) async {
  final List<Workspace> workspaces;
  try {
    workspaces = await loadWorkspaces(ref);
  } catch (_) {
    return null;
  }
  if (workspaces.isEmpty) return null;

  final current =
      workspace ?? ref.read(currentWorkspaceProvider) ?? workspaces.first;
  final buf = StringBuffer()
    ..writeln('[工作区上下文]')
    ..writeln(
      '当前工作区：「${current.name}」（后端 ${current.backendType.name}，'
      '根路径 ${current.root}）。文件工具未指定 workspace 参数时即作用于它。',
    );

  try {
    final backend = ref.read(workspaceBackendProvider(current));
    final entries = await backend.listDir(current.root);
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    final shown = entries.take(kWorkspaceContextMaxEntries).toList();
    final names = [
      for (final e in shown) e.isDirectory ? '${e.name}/' : e.name,
    ];
    if (names.isNotEmpty) {
      final more = entries.length - shown.length;
      buf.writeln(
        '顶层内容（${entries.length} 项）：${names.join('、')}'
        '${more > 0 ? '（另有 $more 项，可用 list_files 查看）' : ''}',
      );
    }
  } catch (_) {
    // Backend unavailable (e.g. SSH not connected): skip the listing.
  }

  final others = [
    if (listOthers)
      for (final w in workspaces)
        if (w.id != current.id) w.name,
  ];
  if (others.isNotEmpty) {
    buf.writeln('其他已打开的工作区：${others.join('、')}（可通过 workspace 参数指定）。');
  }
  return buf.toString().trimRight();
}
