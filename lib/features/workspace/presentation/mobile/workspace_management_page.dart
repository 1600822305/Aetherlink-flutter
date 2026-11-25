// 「工作区管理」page (设置 → 数据与知识 → 工作区管理, route /settings/workspace).
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
// id) / pin / hide / remove a workspace; pick the 主终端 (default backend for
// 新建); toggle「进入时恢复上次会话」; clear all records.
// On entry it proactively probes each backend (verifyAccess) to badge revoked
// entries instead of failing only when opened, and shows a spinner while the
// probe runs plus a summary banner when anything is broken.
//
// 移除 / 清空前会读 [workspaceUsageProvider]（app/di 只读 seam）提示绑定了该
// 工作区的智能体——store 的 remove/clear 只过滤列表，不检查引用。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_usage_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/agent_hooks_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/settings/agent_permission_rules_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/workspace/application/primary_terminal_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/open_workspace_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/primary_terminal_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/tool_auth_settings_page.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 后端配色：本地蓝 / 内置终端橙 / SSH 紫 / Termux 青。仅用于列表图标底色。
const Color _kLocalColor = Color(0xFF4F6EF7);
const Color _kProotColor = Color(0xFFF59E0B);
const Color _kSshColor = Color(0xFF8B5CF6);
const Color _kTermuxColor = Color(0xFF0EA5A4);
const Color _kFullScopeColor = Color(0xFFD97706);
const Color _kIsolatedColor = Color(0xFF7C3AED);

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

  // Ids of workspaces whose backend access has been revoked / is unreachable
  // (proactive health check via verifyAccess). Drives the「授权失效」badge.
  Set<String> _invalidIds = const {};

  // 健康检查进行中（分组标题旁显示 spinner，避免「先正常→突然变红」的跳变）。
  bool _checking = false;

  // 「已隐藏」分组默认折叠。
  bool _hiddenExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAutoRestore();
    _refreshHealth();
  }

  // Proactively probes every workspace's backend access in parallel so revoked
  // (SAF) / unreachable (SSH) entries get a badge instead of failing only when
  // opened. SAF = a cheap permission lookup; SSH/Termux = an SFTP stat(root)
  // over the pooled transport.
  Future<void> _refreshHealth() async {
    if (mounted) setState(() => _checking = true);
    try {
      final workspaces = await ref.read(workspaceStoreProvider.future);
      final saf = ref.read(localSafBackendProvider);
      // Profiles must be hydrated before the pool can resolve connectionIds.
      await ref.read(sshConnectionStoreProvider.future);
      final pool = ref.read(sshBackendPoolProvider);
      final invalid = <String>{};
      await Future.wait([
        for (final w in workspaces) _checkHealth(w, saf, pool, invalid),
      ]);
      if (mounted) setState(() => _invalidIds = invalid);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _checkHealth(
    Workspace w,
    LocalSafBackend saf,
    SshBackendPool pool,
    Set<String> invalid,
  ) async {
    try {
      final WorkspaceBackend backend;
      switch (w.backendType) {
        case WorkspaceBackendType.localSaf:
          backend = saf;
        case WorkspaceBackendType.prootLocal:
          backend = ref.read(prootLocalBackendProvider);
        case WorkspaceBackendType.ssh:
        case WorkspaceBackendType.termux:
          final cid = w.connectionId;
          if (cid == null || cid.isEmpty) {
            invalid.add(w.id);
            return;
          }
          backend = pool.backendFor(cid);
      }
      if (!await backend.verifyAccess(w.root)) invalid.add(w.id);
    } catch (_) {
      invalid.add(w.id);
    }
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

  // + 按钮 / 空状态:打开统一的「新建工作区」面板(主终端 / 本地 / SSH / Termux /
  // 内置终端)。新工作区被设为当前后跳进 /workspace —— 用一次性 listener 捕获切换,
  // 兼容各自的异步流程(选择类型时外层面板已先 pop,无法在 await 之后同步判断)。
  Future<void> _addWorkspace() async {
    final before = ref.read(currentWorkspaceProvider)?.id;
    var navigated = false;
    ref.listenManual<Workspace?>(currentWorkspaceProvider, (prev, next) {
      if (navigated || !mounted || next == null || next.id == before) return;
      navigated = true;
      context.push(AppRouter.workspacePath);
    });
    await showAddWorkspaceSheet(context, ref);
  }

  Future<void> _open(Workspace w) async {
    await openRecent(ref, w);
    if (mounted) context.push(AppRouter.workspacePath);
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

  // 重新授权(rebind by stable id)。重选目录后:
  //   · 同一目录(root 相同,SAF 的 content:// 根是确定性的) → 静默刷新授权;
  //   · 不同目录 → 二次确认后,把新 root 绑回原条目的 id(保留 id/名称/历史),
  //     绝不产生重复条目,也不依赖脆弱的"按名字匹配"。
  Future<void> _reauthorize(Workspace w) async {
    switch (w.backendType) {
      case WorkspaceBackendType.localSaf:
        await _reauthorizeSaf(w);
      case WorkspaceBackendType.prootLocal:
        _snack('内置终端无需授权；环境损坏时在新建面板里重新安装即可');
      case WorkspaceBackendType.ssh:
      case WorkspaceBackendType.termux:
        await _editConnection(w);
    }
  }

  Future<void> _reauthorizeSaf(Workspace w) async {
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

  // 「重新授权」for SSH / Termux = edit the referenced SshConnection (host /
  // credential / key). The form saves through and invalidates the pooled
  // transport; we then re-probe to refresh the badge.
  Future<void> _editConnection(Workspace w) async {
    final cid = w.connectionId;
    if (cid == null || cid.isEmpty) {
      _snack('该工作区未关联连接配置');
      return;
    }
    await ref.read(sshConnectionStoreProvider.future);
    final conn = ref.read(sshConnectionStoreProvider.notifier).byId(cid);
    if (conn == null) {
      _snack('连接配置不存在或已删除');
      return;
    }
    if (!mounted) return;
    final changed = await context.push<bool>(
      AppRouter.sshConnectionPath,
      extra: conn,
    );
    if (changed == true) {
      await _refreshHealth();
      if (mounted) _snack('已更新连接');
    }
  }

  // 主终端 = 新建工作区时默认浏览目录的后端。这里只改默认值，不影响已有工作区。
  Future<void> _pickPrimaryTerminal() async {
    final picked = await showPrimaryTerminalPickerSheet(context, ref);
    if (picked == null) return;
    await ref.read(primaryTerminalStoreProvider.notifier).set(picked);
    if (mounted) _snack('已设为主终端');
  }

  void _snack(String message) {
    if (!mounted) return;
    AppToast.info(context, message);
  }

  Future<void> _togglePin(Workspace w) =>
      ref.read(workspaceStoreProvider.notifier).togglePin(w.id);

  Future<void> _setHidden(Workspace w, bool hidden) =>
      ref.read(workspaceStoreProvider.notifier).setHidden(w.id, hidden);

  Future<void> _remove(Workspace w) async {
    final usage = ref.read(workspaceUsageProvider)[w.id];
    final ok = await _confirm(
      title: '移除「${w.name}」?',
      message: '只会从列表中移除，不删除磁盘上的任何文件。',
      impact: usage == null || usage.isEmpty ? null : _impactText(usage),
      confirmLabel: '移除',
    );
    if (ok) await ref.read(workspaceRemovalProvider).remove(w.id);
  }

  Future<void> _clearAll() async {
    final usage = ref.read(workspaceUsageProvider);
    final profiles = {for (final u in usage.values) ...u.profileNames};
    final servers = {for (final u in usage.values) ...u.mcpServerNames};
    final ok = await _confirm(
      title: '清空所有工作区记录',
      message: '将清空整个工作区列表。不会删除磁盘上的任何文件。',
      impact: profiles.isEmpty && servers.isEmpty
          ? null
          : [
              if (profiles.isNotEmpty)
                '${profiles.length} 个智能体会解除工作区绑定。',
              if (servers.isNotEmpty)
                '${servers.length} 个 MCP 服务器会失去运行环境并被停用。',
              '已有话题保留记录，但无法继续操作原工作区。',
            ].join('\n'),
      confirmLabel: '清空',
    );
    if (ok) await ref.read(workspaceRemovalProvider).clearAll();
  }

  static String _impactText(WorkspaceUsage u) {
    final lines = <String>[];
    if (u.profileNames.isNotEmpty) {
      lines.add('${u.profileNames.length} 个智能体会解除绑定：');
      for (final n in u.profileNames.take(5)) {
        lines.add('· $n');
      }
      if (u.profileNames.length > 5) {
        lines.add('· 等 ${u.profileNames.length} 个');
      }
    }
    if (u.mcpServerNames.isNotEmpty) {
      lines.add(
        'MCP 服务器 ${u.mcpServerNames.join('、')} 会失去运行环境并被停用。',
      );
    }
    if (u.activeTaskCount > 0) {
      lines.add('${u.activeTaskCount} 个话题仍在进行中，之后的文件/终端操作会失败。');
    } else if (u.taskCount > 0) {
      lines.add('${u.taskCount} 个话题保留记录，但无法继续操作这个工作区。');
    }
    return lines.join('\n');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    String? impact,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (impact != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kFullScopeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.triangleAlert,
                        size: 16,
                        color: _kFullScopeColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          impact,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // 行操作面板（替代原 ⋮ 菜单）：每项带一句语义说明，「移除」单独红色置底。
  Future<void> _showActions(Workspace w, {required bool isInvalid}) async {
    final usage = ref.read(workspaceUsageProvider)[w.id];
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final subtle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        Widget item(
          String value,
          IconData icon,
          String title, {
          String? subtitle,
          Color? color,
        }) =>
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              horizontalTitleGap: 12,
              minLeadingWidth: 20,
              leading: Icon(icon, size: 18, color: color),
              title: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: color,
                ),
              ),
              subtitle: subtitle == null ? null : Text(subtitle, style: subtle),
              onTap: () => Navigator.of(ctx).pop(value),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (usage != null && usage.profileNames.isNotEmpty)
                      Text(
                        '被 ${usage.profileNames.length} 个智能体使用',
                        style: subtle,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (!isInvalid) item('open', LucideIcons.folderOpen, '打开'),
              if (w.backendType != WorkspaceBackendType.prootLocal)
                item(
                  'reauthorize',
                  LucideIcons.keyRound,
                  w.backendType == WorkspaceBackendType.localSaf
                      ? '重新授权'
                      : '编辑连接',
                  subtitle: w.backendType == WorkspaceBackendType.localSaf
                      ? '重新选择文件夹，保留名称与历史'
                      : '修改主机 / 凭据，使用同一连接的工作区一起生效',
                ),
              item(
                'pin',
                w.pinned ? LucideIcons.pinOff : LucideIcons.pin,
                w.pinned ? '取消置顶' : '置顶',
              ),
              item(
                'rename',
                LucideIcons.pencil,
                '重命名',
                subtitle: '只改显示名，不影响真实目录',
              ),
              item(
                'hide',
                w.hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                w.hidden ? '取消隐藏' : '隐藏',
                subtitle: w.hidden ? null : '不在「切换工作区」面板显示；重新打开会自动取消隐藏',
              ),
              const Divider(height: 1),
              item(
                'remove',
                LucideIcons.trash2,
                '从列表移除…',
                subtitle: '不删除文件',
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    switch (action) {
      case 'open':
        await _open(w);
      case 'reauthorize':
        await _reauthorize(w);
      case 'pin':
        await _togglePin(w);
      case 'rename':
        await _rename(w);
      case 'hide':
        await _setHidden(w, !w.hidden);
      case 'remove':
        await _remove(w);
    }
  }

  String? _connectionLabel(Workspace w) {
    final cid = w.connectionId;
    if (cid == null || cid.isEmpty) return null;
    return ref.read(sshConnectionStoreProvider.notifier).byId(cid)?.label;
  }

  Widget _buildRow(
    Workspace w, {
    required Workspace? current,
    required Map<String, WorkspaceUsage> usage,
  }) {
    final isInvalid = _invalidIds.contains(w.id);
    return _WorkspaceRow(
      workspace: w,
      isCurrent: w.id == current?.id,
      isInvalid: isInvalid,
      connectionLabel: _connectionLabel(w),
      agentCount: usage[w.id]?.profileNames.length ?? 0,
      // 失效条目:点击直接走重新授权(直接打开必失败)。
      onTap: isInvalid ? () => _reauthorize(w) : () => _open(w),
      onMore: () => _showActions(w, isInvalid: isInvalid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = ref.watch(workspaceStoreProvider);
    final current = ref.watch(currentWorkspaceProvider);
    final usage = ref.watch(workspaceUsageProvider);
    // 连接名 / 主终端展示名都依赖连接档案，watch 以便档案加载或改名后刷新。
    ref.watch(sshConnectionStoreProvider);
    final primary = ref.watch(primaryTerminalStoreProvider).value;
    final primaryLabel =
        primary == null ? null : primaryTerminalLabel(ref, primary);

    // 置顶靠前、组内按活跃时间；隐藏条目沉底到独立分组可恢复。
    final all = recent.asData?.value ?? const <Workspace>[];
    final workspaces = sortWorkspacesForDisplay([
      for (final w in all)
        if (!w.hidden) w,
    ]);
    final hiddenWorkspaces = sortWorkspacesForDisplay([
      for (final w in all)
        if (w.hidden) w,
    ]);
    final invalidVisible = [
      for (final w in workspaces)
        if (_invalidIds.contains(w.id)) w,
    ];

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
            tooltip: '新建工作区',
            onPressed: _addWorkspace,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHealth,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (invalidVisible.isNotEmpty) ...[
              _InvalidBanner(
                count: invalidVisible.length,
                firstName: invalidVisible.first.name,
                onFix: () => _reauthorize(invalidVisible.first),
              ),
              const SizedBox(height: 16),
            ],
            _SectionHeader(
              title: '工作区 (${workspaces.length})',
              trailing: _checking
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '检查中',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            if (workspaces.isEmpty)
              _EmptyHint(theme: theme, onOpen: _addWorkspace)
            else
              _OutlinedCard(
                child: Column(
                  children: [
                    for (var i = 0; i < workspaces.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: theme.dividerColor),
                      _buildRow(
                        workspaces[i],
                        current: current,
                        usage: usage,
                      ),
                    ],
                  ],
                ),
              ),
            if (hiddenWorkspaces.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    setState(() => _hiddenExpanded = !_hiddenExpanded),
                child: _SectionHeader(
                  title: '已隐藏 (${hiddenWorkspaces.length})',
                  trailing: Icon(
                    _hiddenExpanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_hiddenExpanded)
                _OutlinedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Text(
                          '不在「切换工作区」面板中显示。重新打开会自动取消隐藏。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final w in hiddenWorkspaces) ...[
                        Divider(height: 1, color: theme.dividerColor),
                        _buildRow(w, current: current, usage: usage),
                      ],
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const _SectionHeader(title: '偏好'),
            _OutlinedCard(
              child: Column(
                children: [
                  _SettingRow(
                    icon: LucideIcons.squareTerminal,
                    title: '主终端',
                    description: '新建工作区时默认在这里浏览目录',
                    value: primaryLabel ?? '未设置',
                    onTap: _pickPrimaryTerminal,
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  _SettingRow(
                    icon: LucideIcons.history,
                    title: '进入时恢复上次会话',
                    description: '恢复上次的工作区和打开的文件标签',
                    trailing: CustomSwitch(
                      value: _autoRestore ?? true,
                      onChanged: _autoRestore == null ? null : _setAutoRestore,
                    ),
                    onTap: _autoRestore == null
                        ? null
                        : () => _setAutoRestore(!_autoRestore!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionHeader(title: '智能体'),
            _OutlinedCard(
              child: Column(
                children: [
                  _SettingRow(
                    icon: LucideIcons.shieldCheck,
                    title: '工具授权',
                    description: 'AI 调用文件/终端工具时哪些免确认（白名单）',
                    onTap: () => showToolAuthSettingsPage(context),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  _SettingRow(
                    icon: LucideIcons.listChecks,
                    title: '权限规则',
                    description: '审批时「总是允许 / 总是禁止」的持久规则',
                    onTap: () => showAgentPermissionRulesPage(context),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  _SettingRow(
                    icon: LucideIcons.webhook,
                    title: 'Hooks',
                    description: '工作区 hooks.json 的审阅与信任',
                    onTap: () => showAgentHooksPage(context),
                  ),
                ],
              ),
            ),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: theme.textTheme.bodySmall,
                  ),
                  onPressed: _clearAll,
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  label: const Text('清空所有工作区记录'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.workspace,
    required this.isCurrent,
    required this.isInvalid,
    required this.connectionLabel,
    required this.agentCount,
    required this.onTap,
    required this.onMore,
  });

  final Workspace workspace;
  final bool isCurrent;
  final bool isInvalid;

  /// SSH / Termux 引用的连接档案名；其他后端为 null。
  final String? connectionLabel;

  /// 绑定了该工作区的智能体档案数。
  final int agentCount;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = workspace;
    final isFull = w.scope == WorkspaceScope.full;
    final color = isInvalid ? theme.colorScheme.error : _backendColor(w);

    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      child: Container(
        color: isInvalid ? theme.colorScheme.error.withValues(alpha: 0.04) : null,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isInvalid ? 0.12 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isInvalid ? LucideIcons.folderX : _backendIcon(w),
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          w.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (w.pinned) ...[
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.pin,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                      if (isInvalid)
                        _Badge(
                          theme: theme,
                          label: '授权失效',
                          color: theme.colorScheme.error,
                        )
                      else if (isCurrent)
                        _Badge(
                          theme: theme,
                          label: '当前',
                          color: theme.colorScheme.primary,
                        ),
                      if (isFull)
                        _Badge(
                          theme: theme,
                          label: '完整终端',
                          color: _kFullScopeColor,
                        ),
                      if (w.isolatedHome)
                        _Badge(
                          theme: theme,
                          label: '独立 HOME',
                          color: _kIsolatedColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      color: isInvalid
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (agentCount > 0)
              Tooltip(
                message: '$agentCount 个智能体绑定了这个工作区',
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.bot,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$agentCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(LucideIcons.ellipsis, size: 18),
              tooltip: '更多操作',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }

  // 单行副标题：后端 · 位置 · 时间。失效时直接给出修复指引。
  String _subtitle() {
    final w = workspace;
    if (isInvalid) {
      return switch (w.backendType) {
        WorkspaceBackendType.localSaf => '本地文件夹 · 点按重新授权',
        WorkspaceBackendType.ssh ||
        WorkspaceBackendType.termux =>
          '${_backendLabel(w.backendType)} · 连接不可用，点按编辑连接',
        WorkspaceBackendType.prootLocal => '内置终端 · 环境不可用',
      };
    }
    final time = _relativeTime(w.lastOpenedAt);
    if (w.scope == WorkspaceScope.full) {
      return '${_backendLabel(w.backendType)} · 整个环境，命令全部需确认 · $time';
    }
    final location = switch (w.backendType) {
      // SAF 的 root 是 content:// URI，只能显示 displayPath。
      WorkspaceBackendType.localSaf => w.displayPath ?? w.name,
      // 内置终端的 displayPath 带「内置终端 ·」前缀，直接用 root 避免重复。
      WorkspaceBackendType.prootLocal => w.root,
      WorkspaceBackendType.ssh => connectionLabel == null
          ? w.root
          : '$connectionLabel · ${w.root}',
      WorkspaceBackendType.termux => w.root,
    };
    return '${_backendLabel(w.backendType)} · $location · $time';
  }

  static Color _backendColor(Workspace w) => switch (w.backendType) {
    WorkspaceBackendType.localSaf => _kLocalColor,
    WorkspaceBackendType.prootLocal => _kProotColor,
    WorkspaceBackendType.ssh => _kSshColor,
    WorkspaceBackendType.termux => _kTermuxColor,
  };

  static IconData _backendIcon(Workspace w) => switch (w.backendType) {
    WorkspaceBackendType.localSaf => LucideIcons.folder,
    WorkspaceBackendType.prootLocal => LucideIcons.squareTerminal,
    WorkspaceBackendType.ssh => LucideIcons.server,
    WorkspaceBackendType.termux => LucideIcons.terminal,
  };

  static String _backendLabel(WorkspaceBackendType type) => switch (type) {
    WorkspaceBackendType.localSaf => '本地文件夹',
    WorkspaceBackendType.termux => 'Termux',
    WorkspaceBackendType.ssh => 'SSH',
    WorkspaceBackendType.prootLocal => '内置终端',
  };

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}

/// 顶部失效汇总横幅：一个失效时直接修复它，多个时修复第一个（其余仍在行内标红）。
class _InvalidBanner extends StatelessWidget {
  const _InvalidBanner({
    required this.count,
    required this.firstName,
    required this.onFix,
  });

  final int count;
  final String firstName;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '「$firstName」的访问授权已失效'
                  : '$count 个工作区的访问授权已失效',
              style: theme.textTheme.bodyMedium?.copyWith(color: error),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: error,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onFix,
            child: Text(count == 1 ? '修复' : '修复第一个'),
          ),
        ],
      ),
    );
  }
}

/// 设置行：与后台执行等设置页的行同规格——内边距 14/12、标题 14 号 w600、
/// 说明 12 号、左侧 18 号图标。[trailing] 缺省时显示 [value] + 箭头。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.description,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value != null)
                      Text(
                        value!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 16, color: muted),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.theme, required this.label, required this.color});

  final ThemeData theme;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
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
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
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
            Text('还没有任何工作区', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '在主终端里选一个目录,或打开本地文件夹 / 连接 SSH / Termux',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.folderPlus, size: 18),
              label: const Text('新建工作区'),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // 与 ModelSettingsCard 一致
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
