// 智能体 MCP 页（设计初稿 §决策 30）：顶栏三点菜单 →「MCP」。
// 管理当前智能体档案接入的外部 MCP 服务器（远程 SSE/HTTP + 移动端
// stdio），底层复用 settings 的 MCP 服务器库（经 app/di/mcp_servers_access
// seam）。开关与真实服务器状态联动：开 = 启用服务器（isActive）+ 接入
// 档案 mcpServerIds；关 = 移出档案 + 停用服务器（同步关掉 stdio 进程 /
// 远程连接，与设置 → MCP 服务器列表双向一致）。stdio 行实时显示运行状态。
// UI 风格对齐技能页（agent_skills_page.dart）：列表行 + 开关 + 说明行。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/remote_mcp_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_connection_manager.dart';

Future<void> showAgentMcpPage(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const AgentMcpPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class AgentMcpPage extends ConsumerWidget {
  const AgentMcpPage({super.key});

  /// 可接入智能体的外部 MCP 服务器类型（内置 server 由档案工具集分组覆盖）。
  static const Set<McpServerType> _kExternalTypes = {
    McpServerType.sse,
    McpServerType.streamableHttp,
    McpServerType.httpStream,
    McpServerType.stdio,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profileId = ref.watch(selectedAgentProfileIdProvider);
    final profile = ref
        .watch(agentProfilesProvider)
        .where((p) => p.id == profileId)
        .firstOrNull;
    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];
    final external = [
      for (final s in servers)
        if (_kExternalTypes.contains(s.type)) s,
    ];
    final selected = profile?.mcpServerIds ?? const <String>{};
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        title: const Text(
          'MCP',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            tooltip: 'MCP 服务器设置',
            icon: const Icon(LucideIcons.settings, size: 20),
            onPressed: () => context.push(AppRouter.mcpServerPath),
          ),
        ],
      ),
      body: profile == null
          ? Center(
              child: Text(
                '先在侧边栏选择一个智能体',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '接入后「${profile.emoji} ${profile.name}」可调用该服务器的工具'
                          '（仅 Code/Auto 模式；Code 逐次审批）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${selected.length} 已接入',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: external.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '没有可接入的 MCP 服务器\n点右上角进入 MCP 服务器设置添加',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            24 + bottomPad,
                          ),
                          children: [
                            for (final s in external)
                              _row(
                                context,
                                ref,
                                theme,
                                server: s,
                                enabled: s.isActive && selected.contains(s.id),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  /// 开 = 启用服务器 + 接入当前档案；关 = 移出档案 + 停用服务器
  /// （toggleActive 内部同步关掉 stdio 进程 / 远程连接），与设置 →
  /// MCP 服务器列表双向联动。
  Future<void> _toggle(
    WidgetRef ref,
    McpServer server, {
    required bool enabled,
  }) async {
    final profileId = ref.read(selectedAgentProfileIdProvider);
    final profile = ref
        .read(agentProfilesProvider)
        .where((p) => p.id == profileId)
        .firstOrNull;
    if (profile == null) return;
    final ids = {...profile.mcpServerIds};
    enabled ? ids.add(server.id) : ids.remove(server.id);
    await ref
        .read(agentProfilesProvider.notifier)
        .upsert(profile.copyWith(mcpServerIds: ids));
    if (server.isActive != enabled) {
      await ref
          .read(mcpServersProvider.notifier)
          .toggleActive(server.id, isActive: enabled);
    }
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme, {
    required McpServer server,
    required bool enabled,
  }) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isStdio = server.type == McpServerType.stdio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                isStdio ? LucideIcons.terminal : LucideIcons.server,
                size: 19,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isStdio)
                      // 实时运行状态（订阅连接管理器变更流）：开关关掉进程 /
                      // 进程意外退出都即时反映，不再是静态 UI。
                      StreamBuilder<String>(
                        stream: ref
                            .read(stdioMcpConnectionManagerProvider)
                            .changes
                            .where((id) => id == server.id),
                        builder: (context, _) {
                          final st = ref
                              .read(stdioMcpConnectionManagerProvider)
                              .stateOf(server.id);
                          final (label, color) = switch (st.status) {
                            StdioMcpStatus.running => ('运行中', Colors.green),
                            StdioMcpStatus.starting => ('启动中', Colors.amber),
                            StdioMcpStatus.error => ('错误', cs.error),
                            StdioMcpStatus.stopped => (
                              server.isActive ? '未运行' : '已停用',
                              cs.onSurfaceVariant,
                            ),
                          };
                          return Text(
                            'stdio · $label · ${server.command ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: color,
                            ),
                          );
                        },
                      )
                    else
                      Text(
                        '${server.type.name}'
                        '${server.isActive ? '' : ' · 已停用'}'
                        ' · ${server.baseUrl ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              CustomSwitch(
                value: enabled,
                onChanged: (v) => _toggle(ref, server, enabled: v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
