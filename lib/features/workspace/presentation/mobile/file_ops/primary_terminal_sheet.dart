// 「主终端」统一入口：选好默认主终端（内置 / Termux / SSH 连接）后，
// 新入口直接进 IDE 式文件夹浏览器逐级选目录「在此打开」，不再要求
// 先去各后端接入页配置。主终端只是默认值：各智能体档案 / 工作区仍
// 可各自绑定不同终端并行使用，切换默认不影响已开会话。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/workspace/application/primary_terminal_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_workspace_setup.dart';
import 'package:aetherlink_flutter/features/workspace/domain/primary_terminal.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/termux_setup.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/open_workspace_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/proot_folder_picker_sheet.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Termux 一键接入的连接固定指向同机 sshd，据此与普通 SSH 档案区分。
bool isTermuxConnection(SshConnection c) =>
    c.host == '127.0.0.1' && c.port == TermuxSetup.defaultPort;

/// 主终端的展示名（内置终端 / 连接 label）。连接已被删除时返回 null。
String? primaryTerminalLabel(WidgetRef ref, PrimaryTerminal terminal) {
  if (terminal.type == WorkspaceBackendType.prootLocal) return '内置终端';
  final connection = ref
      .read(sshConnectionStoreProvider.notifier)
      .byId(terminal.connectionId ?? '');
  if (connection == null) return null;
  return isTermuxConnection(connection) ? 'Termux' : connection.label;
}

/// 主入口：有默认主终端就直接进浏览器；没有先弹选择器（选完记为默认）。
Future<void> browseWithPrimaryTerminal(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(primaryTerminalStoreProvider.future);
  await ref.read(sshConnectionStoreProvider.future);
  var terminal = ref.read(primaryTerminalStoreProvider).value;
  if (terminal != null && primaryTerminalLabel(ref, terminal) == null) {
    terminal = null; // 连接已被删除，重新选。
  }
  if (terminal == null) {
    if (!context.mounted) return;
    terminal = await showPrimaryTerminalPickerSheet(context, ref);
    if (terminal == null) return;
    await ref.read(primaryTerminalStoreProvider.notifier).set(terminal);
  }
  if (!context.mounted) return;
  await openPrimaryTerminalFolder(context, ref, terminal);
}

/// 一站式：弹主终端选择器（未设默认时选中即记为默认），随后直接进
/// IDE 式目录浏览器并返回落成的工作区（智能体绑定用 switchTo: false，
/// 不切换当前工作区）。
Future<Workspace?> pickFolderWithTerminalPicker(
  BuildContext context,
  WidgetRef ref, {
  bool switchTo = true,
}) async {
  final terminal = await showPrimaryTerminalPickerSheet(context, ref);
  if (terminal == null) return null;
  await ref.read(primaryTerminalStoreProvider.future);
  if (ref.read(primaryTerminalStoreProvider).value == null) {
    await ref.read(primaryTerminalStoreProvider.notifier).set(terminal);
  }
  if (!context.mounted) return null;
  return openPrimaryTerminalFolder(context, ref, terminal, switchTo: switchTo);
}

/// 弹主终端选择器：内置终端 / 已有 Termux / 已有 SSH 连接；底部提供
/// 新建 SSH 连接、接入 Termux 的入口（走各自的接入页）。
Future<PrimaryTerminal?> showPrimaryTerminalPickerSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(sshConnectionStoreProvider.future);
  final connections = ref.read(sshConnectionStoreProvider.notifier).all();
  if (!context.mounted) return null;
  return showModalBottomSheet<PrimaryTerminal>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  '选择主终端',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '作为新入口的默认终端；各智能体仍可各自绑定不同终端并行使用',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.squareTerminal,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('内置终端'),
                subtitle: const Text('应用内置 Alpine Linux（PRoot），免 Root 零依赖'),
                onTap: () => Navigator.of(sheetContext).pop(
                  const PrimaryTerminal(type: WorkspaceBackendType.prootLocal),
                ),
              ),
              for (final c in connections)
                ListTile(
                  leading: Icon(
                    isTermuxConnection(c)
                        ? LucideIcons.terminal
                        : LucideIcons.server,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(isTermuxConnection(c) ? 'Termux' : c.label),
                  subtitle: Text('${c.username}@${c.host}:${c.port}'),
                  onTap: () => Navigator.of(sheetContext).pop(
                    PrimaryTerminal(
                      type: isTermuxConnection(c)
                          ? WorkspaceBackendType.termux
                          : WorkspaceBackendType.ssh,
                      connectionId: c.id,
                    ),
                  ),
                ),
              const Divider(height: 16),
              ListTile(
                leading: Icon(
                  LucideIcons.plus,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: const Text('新建 SSH 连接…'),
                onTap: () {
                  final router = GoRouter.of(sheetContext);
                  Navigator.of(sheetContext).pop();
                  router.push(AppRouter.sshConnectionPath);
                },
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.plus,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: const Text('接入 Termux…'),
                onTap: () {
                  final router = GoRouter.of(sheetContext);
                  Navigator.of(sheetContext).pop();
                  router.push(AppRouter.termuxSetupPath);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 在 [terminal] 上打开 IDE 式文件夹浏览器，「在此打开」落成项目工作区。
/// [switchTo] 为 false 时只落库返回，不切换当前工作区（智能体绑定用）。
/// 返回创建/复用的工作区，用户取消或失败时 null。
Future<Workspace?> openPrimaryTerminalFolder(
  BuildContext context,
  WidgetRef ref,
  PrimaryTerminal terminal, {
  bool switchTo = true,
}) async {
  try {
    switch (terminal.type) {
      case WorkspaceBackendType.prootLocal:
        return await openProotProjectWorkspace(
          context,
          ref,
          switchTo: switchTo,
        );
      case WorkspaceBackendType.termux:
      case WorkspaceBackendType.ssh:
        return await _openSshFolder(
          context,
          ref,
          connectionId: terminal.connectionId ?? '',
          switchTo: switchTo,
        );
      case WorkspaceBackendType.localSaf:
        return null; // SAF 无 shell，不能作主终端。
    }
  } catch (e) {
    if (context.mounted) AppToast.error(context, '打开失败 · $e');
    return null;
  }
}

Future<Workspace?> _openSshFolder(
  BuildContext context,
  WidgetRef ref, {
  required String connectionId,
  required bool switchTo,
}) async {
  await ref.read(sshConnectionStoreProvider.future);
  final connection = ref
      .read(sshConnectionStoreProvider.notifier)
      .byId(connectionId);
  if (connection == null) {
    if (context.mounted) AppToast.error(context, '连接档案已被删除，请重新选择主终端');
    return null;
  }
  final backend = ref.read(sshBackendPoolProvider).backendFor(connection.id);
  final home = (await backend.exec(
    r'printf %s "$HOME"',
    timeout: const Duration(seconds: 15),
  )).stdout.trim();
  final initialPath = home.startsWith('/') ? home : '/';
  if (!context.mounted) return null;
  final pick = await showProotFolderPickerSheet(
    context,
    backend: backend,
    initialPath: initialPath,
  );
  if (pick == null) return null;
  final root = pick.path;
  final name = root == '/' ? '/' : root.substring(root.lastIndexOf('/') + 1);
  return openAndSwitchSshWorkspace(
    ref,
    connection,
    root: root,
    backendType: isTermuxConnection(connection)
        ? WorkspaceBackendType.termux
        : WorkspaceBackendType.ssh,
    scope: WorkspaceScope.project,
    isolatedHome: pick.isolatedHome,
    name: name,
    switchTo: switchTo,
  );
}
