// 「工作区管理」 page (设置 → 数据与知识 → 工作区管理, route /settings/workspace).
//
// Lives in the workspace feature (not settings) because it reaches workspace
// `application` / `data` directly — the cross-feature import-boundary guard
// (test/architecture/import_boundaries_test.dart) only allows settings to
// reference its route string via AppRouter, never the page class.
//
// The "at rest" management hub for workspaces, complementing the in-workspace
// quick-switch sheet (file_ops/open_workspace_sheet.dart). Both read the same
// [workspaceStoreProvider], so the two surfaces stay consistent.
//
// Capabilities: open a folder; open / rename / re-authorize (rebind by stable
// id) / remove a workspace; toggle "进入工作区自动恢复上次会话"; clear all records.
// On entry it proactively probes each SAF grant (verifyAccess) to badge revoked
// entries instead of failing only when opened.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/open_workspace_sheet.dart';

class WorkspaceManagementPage extends ConsumerStatefulWidget {
  const WorkspaceManagementPage({super.key});

  @override
  ConsumerState<WorkspaceManagementPage> createState() =>
      _WorkspaceManagementPageState();
}

class _WorkspaceManagementPageState
    extends ConsumerState<WorkspaceManagementPage> {
  // null = still loading; defaults to true (auto-restore on) when unset.
  bool? _autoRestore;

  // Ids of workspaces whose SAF grant has been revoked/expired (proactive
  // health check via the backend's verifyAccess). Drives the 「授权已失效」 badge.
  Set<String> _invalidIds = const {};

  @override
  void initState() {
    super.initState();
    _loadAutoRestore();
    _refreshHealth();
  }

  // Proactively probes every localSaf workspace's persisted grant in parallel
  // (one cheap permission lookup each, no directory I/O) so revoked entries get
  // a 「授权已失效」 badge instead of failing only when opened.
  Future<void> _refreshHealth() async {
    final workspaces = await ref.read(workspaceStoreProvider.future);
    final backend = ref.read(localSafBackendProvider);
    final invalid = <String>{};
    await Future.wait([
      for (final w in workspaces)
        if (w.backendType == WorkspaceBackendType.localSaf)
          backend.verifyAccess(w.root).then(
            (ok) {
              if (!ok) invalid.add(w.id);
            },
            onError: (_) => invalid.add(w.id),
          ),
    ]);
    if (mounted) setState(() => _invalidIds = invalid);
  }

  Future<void> _loadAutoRestore() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kWorkspaceAutoRestoreKey);
    if (mounted) setState(() => _autoRestore = raw != 'false');
  }

  Future<void> _setAutoRestore(bool value) async {
    setState(() => _autoRestore = value);
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kWorkspaceAutoRestoreKey, value ? 'true' : 'false');
  }

  // + 按钮:打开本地文件夹,成功后跳进 /workspace。openLocalFolder 会记录并设为当前,
  // 用 currentWorkspace 是否变化来判断用户是否真的选了(而非取消)。
  Future<void> _openFolder() async {
    final before = ref.read(currentWorkspaceProvider)?.id;
    await openLocalFolder(context, ref);
    final after = ref.read(currentWorkspaceProvider);
    if (mounted && after != null && after.id != before) {
      context.go(AppRouter.workspacePath);
    }
  }

  Future<void> _open(Workspace w) async {
    await openRecent(ref, w);
    if (mounted) context.go(AppRouter.workspacePath);
  }

  Future<void> _rename(Workspace w) async {
    final name = await _promptRename(w.name);
    if (name == null) return;
    await ref.read(workspaceStoreProvider.notifier).rename(w.id, name);
  }

  Future<String?> _promptRename(String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名工作区'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '仅用于显示,不影响真实目录',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 重新授权(企业级:rebind by stable id)。重选目录后:
  //   · 同一目录(root 相同,SAF 的 content:// 根是确定性的) → 静默刷新授权;
  //   · 不同目录 → 二次确认后,把新 root 绑回原条目的 id(保留 id/名称/历史),
  //     绝不产生重复条目,也不依赖脆弱的"按名字匹配"。
  Future<void> _reauthorize(Workspace w) async {
    if (w.backendType != WorkspaceBackendType.localSaf) {
      _snack('该工作区类型暂不支持重新授权');
      return;
    }
    final PickedDirectory? picked;
    try {
      picked = await ref.read(localSafBackendProvider).pickDirectory();
    } catch (e) {
      _snack('重新授权失败 · $e');
      return;
    }
    if (picked == null) return; // 用户取消
    if (picked.root != w.root) {
      final ok = await _confirm(
        title: '目录不一致',
        message:
            '你选择的是「${picked.displayPath ?? picked.name}」,与原工作区不同。'
            '用它替换「${w.name}」吗?',
        confirmLabel: '替换',
      );
      if (!ok) return;
    }
    final updated = await ref
        .read(workspaceStoreProvider.notifier)
        .rebind(w.id, root: picked.root, displayPath: picked.displayPath);
    if (updated == null) return;
    await _refreshHealth();
    if (mounted) _snack('已重新授权');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _remove(Workspace w) async {
    final ok = await _confirm(
      title: '移除工作区',
      message: '将从「最近打开」中移除「${w.name}」。不会删除磁盘上的任何文件。',
      confirmLabel: '移除',
    );
    if (ok) await ref.read(workspaceStoreProvider.notifier).remove(w.id);
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
      title: '清空所有工作区记录',
      message: '将清空整个「最近打开」列表。不会删除磁盘上的任何文件。',
      confirmLabel: '清空',
    );
    if (ok) await ref.read(workspaceStoreProvider.notifier).clear();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = ref.watch(workspaceStoreProvider);
    final current = ref.watch(currentWorkspaceProvider);
    final workspaces = recent.asData?.value ?? const <Workspace>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.settingsPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('工作区管理'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.folderPlus, size: 22),
            color: theme.colorScheme.primary,
            tooltip: '打开文件夹',
            onPressed: _openFolder,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: '工作区 (${workspaces.length})'),
          if (workspaces.isEmpty)
            _EmptyHint(theme: theme, onOpen: _openFolder)
          else
            _OutlinedCard(
              child: Column(
                children: [
                  for (var i = 0; i < workspaces.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.dividerColor),
                    _WorkspaceRow(
                      workspace: workspaces[i],
                      isCurrent: workspaces[i].id == current?.id,
                      isInvalid: _invalidIds.contains(workspaces[i].id),
                      onOpen: () => _open(workspaces[i]),
                      onRename: () => _rename(workspaces[i]),
                      onReauthorize: () => _reauthorize(workspaces[i]),
                      onRemove: () => _remove(workspaces[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '偏好'),
          _OutlinedCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: _autoRestore ?? true,
                  onChanged: _autoRestore == null ? null : _setAutoRestore,
                  title: const Text('进入工作区自动恢复上次会话'),
                  subtitle: const Text('像 IDE 一样恢复上次打开的工作区与文件标签'),
                  secondary: Icon(
                    LucideIcons.history,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                ListTile(
                  leading: Icon(
                    LucideIcons.list,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('最多记住的工作区数量'),
                  trailing: Text(
                    '$kMaxRecentWorkspaces',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (workspaces.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionHeader(title: '危险区'),
            _OutlinedCard(
              child: ListTile(
                leading: Icon(LucideIcons.trash2, color: theme.colorScheme.error),
                title: Text(
                  '清空所有工作区记录',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('仅清空记录,不删除磁盘文件'),
                onTap: _clearAll,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.workspace,
    required this.isCurrent,
    required this.isInvalid,
    required this.onOpen,
    required this.onRename,
    required this.onReauthorize,
    required this.onRemove,
  });

  final Workspace workspace;
  final bool isCurrent;
  final bool isInvalid;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onReauthorize;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 失效条目:点击直接走重新授权(直接打开必失败)。
    return ListTile(
      onTap: isInvalid ? onReauthorize : onOpen,
      leading: Icon(
        isInvalid ? LucideIcons.folderX : LucideIcons.folder,
        color: isInvalid
            ? theme.colorScheme.error
            : isCurrent
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              workspace.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isInvalid) ...[
            const SizedBox(width: 8),
            _Badge(
              theme: theme,
              label: '授权已失效',
              color: theme.colorScheme.error,
            ),
          ] else if (isCurrent) ...[
            const SizedBox(width: 8),
            _Badge(
              theme: theme,
              label: '当前',
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workspace.displayPath ?? workspace.root,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${_backendLabel(workspace.backendType)} · '
            '${_relativeTime(workspace.lastOpenedAt)}打开',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
        onSelected: (value) {
          switch (value) {
            case 'open':
              onOpen();
            case 'rename':
              onRename();
            case 'reauthorize':
              onReauthorize();
            case 'remove':
              onRemove();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'open', child: Text('打开')),
          PopupMenuItem(value: 'rename', child: Text('重命名')),
          PopupMenuItem(value: 'reauthorize', child: Text('重新授权')),
          PopupMenuItem(value: 'remove', child: Text('移除')),
        ],
      ),
    );
  }

  static String _backendLabel(WorkspaceBackendType type) => switch (type) {
        WorkspaceBackendType.localSaf => '本地',
        WorkspaceBackendType.termux => 'Termux',
        WorkspaceBackendType.ssh => 'SSH',
      };

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.theme,
    required this.label,
    required this.color,
  });

  final ThemeData theme;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.theme, required this.onOpen});

  final ThemeData theme;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(
              LucideIcons.folderOpen,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '还没有任何工作区',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '打开一个手机本地目录开始使用',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.folderPlus, size: 18),
              label: const Text('打开文件夹'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
