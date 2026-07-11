// 进工作区自动恢复上次会话（工作区 + 打开的文件 tab + 活动 tab），最像 IDE。
// 工作区页和独立终端路由共用：后者跳过了工作区页的进入流程，也需要先把
// currentWorkspace 恢复出来，否则终端页只会显示「请先打开一个工作区」。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

enum WorkspaceRestoreStatus {
  /// 已恢复上次工作区（及文件 tab）。
  restored,

  /// 无可恢复的会话（关了自动恢复 / 没有记录 / 工作区已被删）。
  none,

  /// SAF 的 content:// 授权已被系统回收，需用户重新打开文件夹。
  authExpired,
}

/// 恢复上次工作区会话。已有打开的工作区时不做任何事（返回 [WorkspaceRestoreStatus.restored]）。
/// SAF 授权可能被系统回收，恢复前先探一下根目录可读。
Future<WorkspaceRestoreStatus> restoreLastWorkspaceSession(WidgetRef ref) async {
  if (ref.read(currentWorkspaceProvider) != null) {
    return WorkspaceRestoreStatus.restored;
  }

  final settings = ref.read(appSettingsStoreProvider);
  // 用户可在「工作区管理」里关掉自动恢复。
  if (await settings.getSetting(kWorkspaceAutoRestoreKey) == 'false') {
    return WorkspaceRestoreStatus.none;
  }

  final raw = await settings.getSetting(kWorkspaceSessionKey);
  final session = WorkspaceSession.decode(raw);
  if (session == null) return WorkspaceRestoreStatus.none;

  final recent = await ref.read(workspaceStoreProvider.future);
  Workspace? workspace;
  for (final w in recent) {
    if (w.id == session.workspaceId) {
      workspace = w;
      break;
    }
  }
  if (workspace == null) return WorkspaceRestoreStatus.none;

  try {
    final backend = ref.read(workspaceBackendProvider(workspace));
    await backend.listDir(workspace.root);
  } catch (_) {
    return WorkspaceRestoreStatus.authExpired;
  }

  ref.read(currentWorkspaceProvider.notifier).open(workspace);
  if (session.tabs.isNotEmpty) {
    ref
        .read(openWorkspaceFilesProvider.notifier)
        .restore(session.tabs, session.activePath);
  }
  return WorkspaceRestoreStatus.restored;
}
