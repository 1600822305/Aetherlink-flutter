// 「打开文件夹」 entry, moved off the old start screen onto the file-tree header.
//
// Shows a bottom sheet with "打开本地文件夹" (real SAF picker) plus the "最近打开"
// list, and owns the open/switch logic: record the workspace in the recent
// store, reset the open tabs (a different workspace starts a fresh session) and
// set it as current. Only LocalSafBackend's neutral pickDirectory is touched —
// the plugin is never imported here (spec §1).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/presentation/mobile/terminal_setup_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/proot_folder_picker_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/ssh_connection_form_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/termux_setup_sheet.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens the workspace picker sheet (recent list + 「打开本地文件夹」).
Future<void> showOpenWorkspaceSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _OpenWorkspaceSheet(parentRef: ref),
  );
}

class _OpenWorkspaceSheet extends ConsumerWidget {
  const _OpenWorkspaceSheet({required this.parentRef});

  /// The page's ref — used for opening so provider writes outlive the sheet.
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(workspaceStoreProvider);
    final current = ref.watch(currentWorkspaceProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                '打开文件夹',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  LucideIcons.folderOpen,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('打开本地文件夹'),
                subtitle: const Text('授权手机上的一个目录 (SAF)'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await openLocalFolder(context, parentRef);
                },
              ),
            ),
            // SSH and Termux are both live now (设计文档 §10.5 / Termux-A).
            const SizedBox(height: 4),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  LucideIcons.server,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('SSH / 远程'),
                subtitle: const Text('连接远程机器，浏览其文件 (Remote-SSH)'),
                onTap: () async {
                  // Capture the navigator before popping this sheet — its own
                  // context is defunct afterwards but navigator.context stays
                  // valid for showing the form sheet.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  await showSshConnectionFormSheet(navigator.context, parentRef);
                },
              ),
            ),
            const SizedBox(height: 4),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  LucideIcons.terminal,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Termux'),
                subtitle: const Text('同机 Termux 一键接入，文件 + 终端'),
                onTap: () async {
                  // Capture the navigator before popping — this sheet's context
                  // is defunct afterwards but navigator.context stays valid.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  await showTermuxSetupSheet(navigator.context, parentRef);
                },
              ),
            ),
            const SizedBox(height: 4),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  LucideIcons.squareTerminal,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('内置终端'),
                subtitle: const Text('应用内置 Alpine Linux，免 Root 零依赖（PRoot）'),
                onTap: () async {
                  // Capture the navigator before popping — this sheet's context
                  // is defunct afterwards but navigator.context stays valid.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  await showProotScopeSheet(navigator.context, parentRef);
                },
              ),
            ),
            if (recent.asData?.value.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '最近打开',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final w in recent.asData!.value)
                ListTile(
                  leading: Icon(
                    LucideIcons.folder,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    w.displayPath ?? w.root,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: w.id == current?.id
                      ? Icon(
                          LucideIcons.check,
                          color: theme.colorScheme.primary,
                        )
                      : IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () => ref
                              .read(workspaceStoreProvider.notifier)
                              .remove(w.id),
                        ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await openRecent(parentRef, w);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Picks a folder via SAF, records it and opens it as the current workspace.
Future<void> openLocalFolder(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await ref.read(localSafBackendProvider).pickDirectory();
    if (picked == null) return; // 用户取消
    final workspace = await ref
        .read(workspaceStoreProvider.notifier)
        .open(
          name: picked.name,
          backendType: WorkspaceBackendType.localSaf,
          root: picked.root,
          displayPath: picked.displayPath,
        );
    _switchTo(ref, workspace);
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    AppToast.error(context, '打开失败 · ${e.code}: ${e.message ?? ''}');
  } catch (e) {
    if (!context.mounted) return;
    AppToast.error(context, '打开失败 · $e');
  }
}

/// Directory that hosts 项目模式 workspaces inside the PRoot rootfs
///（双作用域设计稿 §2.2）。
const String kProotProjectsDir = '/root/projects';

/// Shows the 内置终端 scope chooser: 项目文件夹 (project) vs 完整终端 (full)
///（双作用域设计稿 §5）。
Future<void> showProotScopeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '内置终端',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                LucideIcons.folderGit2,
                color: theme.colorScheme.primary,
              ),
              title: const Text('打开项目文件夹'),
              subtitle: const Text('工作区锚定到一个项目目录（IDE 式）'),
              onTap: () async {
                final navigator = Navigator.of(sheetContext);
                navigator.pop();
                await openProotProjectWorkspace(navigator.context, ref);
              },
            ),
            ListTile(
              leading: Icon(
                LucideIcons.squareTerminal,
                color: theme.colorScheme.primary,
              ),
              title: const Text('打开完整终端'),
              subtitle: const Text('整个 Alpine 环境，命令全量确认'),
              onTap: () async {
                final navigator = Navigator.of(sheetContext);
                navigator.pop();
                await openProotWorkspace(navigator.context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Ensures the PRoot rootfs is installed, guiding through the setup sheet on
/// first use. Returns false when the user bails out.
Future<bool> _ensureProotInstalled(BuildContext context, WidgetRef ref) async {
  if (await TerminalEngineManager.instance.isInstalled()) return true;
  if (!context.mounted) return false;
  return showTerminalSetupSheet(context, ref.read(fileSystemApiProvider));
}

/// Opens the 内置终端 (PRoot Alpine) workspace in 全机模式, installing the
/// rootfs via the setup sheet on first use.
Future<void> openProotWorkspace(BuildContext context, WidgetRef ref) async {
  try {
    if (!await _ensureProotInstalled(context, ref)) return;
    final workspace = await ref
        .read(workspaceStoreProvider.notifier)
        .open(
          name: '内置终端',
          backendType: WorkspaceBackendType.prootLocal,
          scope: WorkspaceScope.full,
          root: '/root',
          displayPath: 'Alpine Linux · 内置 (PRoot)',
        );
    _switchTo(ref, workspace);
  } catch (e) {
    if (!context.mounted) return;
    AppToast.error(context, '打开失败 · $e');
  }
}

/// Opens a 项目模式 workspace in the PRoot rootfs: shows an IDE-style folder
/// browser（默认锚在 [kProotProjectsDir]，可逐级浏览 / 新建）, then anchors the
/// workspace root to the picked directory（双作用域设计稿 §2.2）。
Future<void> openProotProjectWorkspace(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    if (!await _ensureProotInstalled(context, ref)) return;
    final backend = ref.read(prootLocalBackendProvider);
    // 保证默认项目目录存在，浏览器一进来就有地方落脚。
    final projectsDir = await backend.createDirectory(
      '/root',
      'projects',
      recursive: true,
    );
    if (!context.mounted) return;
    final pick = await showProotFolderPickerSheet(
      context,
      backend: backend,
      initialPath: projectsDir,
    );
    if (pick == null) return;
    final root = pick.path;
    final name = root == '/' ? '/' : root.substring(root.lastIndexOf('/') + 1);
    final workspace = await ref
        .read(workspaceStoreProvider.notifier)
        .open(
          name: name,
          backendType: WorkspaceBackendType.prootLocal,
          scope: WorkspaceScope.project,
          isolatedHome: pick.isolatedHome,
          root: root,
          displayPath: '内置终端 · $root',
        );
    _switchTo(ref, workspace);
  } catch (e) {
    if (!context.mounted) return;
    AppToast.error(context, '打开失败 · $e');
  }
}

/// Re-opens a "最近打开" entry as the current workspace.
Future<void> openRecent(WidgetRef ref, Workspace workspace) async {
  final stored = await ref
      .read(workspaceStoreProvider.notifier)
      .open(
        name: workspace.name,
        backendType: workspace.backendType,
        scope: workspace.scope,
        isolatedHome: workspace.isolatedHome,
        root: workspace.root,
        displayPath: workspace.displayPath,
        // SSH / Termux workspaces must keep their SshConnection reference, else
        // workspaceBackend can't resolve the pooled connection (设计文档 §5.1).
        connectionId: workspace.connectionId,
      );
  _switchTo(ref, stored);
}

// Switching workspaces starts a fresh editor session: clear tabs first (so the
// shell stays on the tree page) then set the new current workspace.
void _switchTo(WidgetRef ref, Workspace workspace) {
  ref.read(currentWorkspaceProvider.notifier).open(workspace);
  ref.read(openWorkspaceFilesProvider.notifier).reset();
}
