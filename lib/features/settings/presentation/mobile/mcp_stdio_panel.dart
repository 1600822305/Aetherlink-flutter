import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/remote_mcp_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_server_edit_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// stdio（移动端）面板的强调色（终端橙）。
const Color kStdioAccent = Color(0xFFFF9800);

/// 同页内其他 tab 的卡片样式：24px 圆角、1px 分隔线描边、surface 填充。
class _StdioCard extends StatelessWidget {
  const _StdioCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

/// The 终端 stdio tab of the MCP 服务器 settings page — 移动端专用：stdio
/// server 是经工作区后端（proot 容器 / SSH）拉起的本地子进程，这里管配置
/// （命令/参数/环境变量/运行环境）+ 运行状态（状态点/重启/停止/日志）。
class McpStdioTab extends ConsumerWidget {
  const McpStdioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];
    final stdio = servers.where(StdioMcpConnectionManager.isStdio).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (stdio.isEmpty)
          _StdioEmptyState(theme: theme)
        else
          _StdioCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stdio.length; i++) ...[
                  _StdioServerRow(server: stdio[i]),
                  if (i < stdio.length - 1)
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        _StdioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.info, size: 16, color: kStdioAccent),
                  const SizedBox(width: 8),
                  Text(
                    '什么是终端 stdio MCP？',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'stdio MCP 服务器是运行在终端环境里的本地进程（如 npx -y '
                'some-mcp、uvx some-mcp），通过标准输入/输出通信。需要先在'
                '所选运行环境（proot 容器 / SSH 工作区）里装好 Node / '
                'Python 等运行时。',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the 添加 stdio 服务器 form and persists the new server on confirm.
Future<void> openAddStdioServer(BuildContext context, WidgetRef ref) async {
  final draft = await showMcpServerEditPage(context, stdioOnly: true);
  if (draft == null) return;
  await ref.read(mcpServersProvider.notifier).add(draft);
  if (context.mounted) AppToast.info(context, '服务器添加成功');
}

class _StdioEmptyState extends ConsumerWidget {
  const _StdioEmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StdioCard(
      child: Column(
        children: [
          const Icon(LucideIcons.terminal, size: 48, color: kStdioAccent),
          const SizedBox(height: 16),
          Text(
            '还没有配置 stdio 服务器',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'stdio MCP 服务器在终端环境（proot 容器 / SSH 工作区）里作为本地进程运行',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kStdioAccent),
            onPressed: () => openAddStdioServer(context, ref),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('添加 stdio 服务器'),
          ),
        ],
      ),
    );
  }
}

/// A configured stdio server row: status dot + name + command, 运行状态 chip,
/// active switch, and an actions menu (重启 / 停止 / 日志 / 编辑 / 删除).
class _StdioServerRow extends ConsumerStatefulWidget {
  const _StdioServerRow({required this.server});

  final McpServer server;

  @override
  ConsumerState<_StdioServerRow> createState() => _StdioServerRowState();
}

class _StdioServerRowState extends ConsumerState<_StdioServerRow> {
  StreamSubscription<String>? _sub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(stdioMcpConnectionManagerProvider).changes.listen((id) {
      if (id == widget.server.id && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = widget.server;
    final manager = ref.read(stdioMcpConnectionManagerProvider);
    final state = manager.stateOf(server.id);
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final workspaceName = workspaces
        .where((w) => w.id == server.workspaceId)
        .map((w) => w.name)
        .firstOrNull;

    final commandLine = [
      server.command ?? '',
      ...?server.args,
    ].join(' ').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openEdit(context),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kStdioAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      LucideIcons.terminal,
                      size: 20,
                      color: kStdioAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              server.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            _StatusChip(status: state.status),
                          ],
                        ),
                        if (commandLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            commandLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          workspaceName != null
                              ? '运行环境：$workspaceName'
                              : '未选择运行环境',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: workspaceName != null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          CustomSwitch(
            value: server.isActive,
            // toggleActive 内部启停真实进程（开 = 拉起 / 关 = 结束）。
            onChanged: (v) => ref
                .read(mcpServersProvider.notifier)
                .toggleActive(server.id, isActive: v),
          ),
          _busy
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<String>(
                  popUpAnimationStyle: AnimationStyle.noAnimation,
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'restart',
                      child: Text('启动 / 重启'),
                    ),
                    const PopupMenuItem(value: 'stop', child: Text('停止')),
                    const PopupMenuItem(value: 'logs', child: Text('查看日志')),
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final manager = ref.read(stdioMcpConnectionManagerProvider);
    final server = widget.server;
    switch (action) {
      case 'restart':
        setState(() => _busy = true);
        try {
          await manager.restartServer(server);
          if (context.mounted) AppToast.info(context, '${server.name} 已启动');
        } catch (e) {
          if (context.mounted) AppToast.info(context, '启动失败：$e');
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case 'stop':
        await manager.closeServer(server);
        if (context.mounted) AppToast.info(context, '${server.name} 已停止');
      case 'logs':
        if (context.mounted) {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _StdioLogSheet(server: server),
          );
        }
      case 'edit':
        await _openEdit(context);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除服务器'),
            content: Text('确定删除「${server.name}」吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await manager.closeServer(server);
        await ref.read(mcpServersProvider.notifier).remove(server.id);
        if (context.mounted) AppToast.info(context, '已删除');
    }
  }

  Future<void> _openEdit(BuildContext context) async {
    final updated = await showMcpServerEditPage(
      context,
      initial: widget.server,
      stdioOnly: true,
    );
    if (updated == null) return;
    await ref.read(mcpServersProvider.notifier).edit(updated);
    // 配置变了，旧进程作废，下次调用按新配置拉起。
    await ref.read(stdioMcpConnectionManagerProvider).closeServer(updated);
    if (context.mounted) AppToast.info(context, '已保存');
  }
}

/// 运行状态小圆点 chip：已停止（灰）/ 启动中（橙）/ 运行中（绿）/ 错误（红）。
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final StdioMcpStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      StdioMcpStatus.stopped => ('已停止', theme.colorScheme.onSurfaceVariant),
      StdioMcpStatus.starting => ('启动中', kStdioAccent),
      StdioMcpStatus.running => ('运行中', const Color(0xFF22C55E)),
      StdioMcpStatus.error => ('错误', theme.colorScheme.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// stdio server 的进程日志（stderr + 非 JSON stdout）底部弹层，实时追加。
class _StdioLogSheet extends ConsumerStatefulWidget {
  const _StdioLogSheet({required this.server});

  final McpServer server;

  @override
  ConsumerState<_StdioLogSheet> createState() => _StdioLogSheetState();
}

class _StdioLogSheetState extends ConsumerState<_StdioLogSheet> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(stdioMcpConnectionManagerProvider).changes.listen((id) {
      if (id == widget.server.id && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref
        .read(stdioMcpConnectionManagerProvider)
        .stateOf(widget.server.id);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.scrollText,
                  size: 20,
                  color: kStdioAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.server.name} · 进程日志',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusChip(status: state.status),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Flexible(
            child: state.logs.isEmpty && state.error == null
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      32,
                      32,
                      32,
                      32 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    child: Text(
                      '暂无日志（进程尚未启动或没有输出）',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    reverse: true,
                    // 弹层内 paddingOf 的 bottom 已被消耗为 0，用 viewPaddingOf
                    // 才能避开底部手势条（安全区）。
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.viewPaddingOf(context).bottom + 16,
                    ),
                    children: [
                      if (state.error != null)
                        Text(
                          state.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.5,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      for (final line in state.logs.reversed)
                        Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
