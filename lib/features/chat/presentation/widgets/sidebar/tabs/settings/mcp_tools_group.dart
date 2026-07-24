part of 'settings_tab.dart';

/// The 设置 tab's MCP 工具 group (port of `MCPSidebarControls`): the 启用 MCP 工具
/// 总开关, the 工具调用模式 (函数调用 / 提示词注入), an inline list of configured
/// 服务器 settings page. All of these are live: the toggle / mode feed
/// `ChatController._mcpSetup`, which exposes the active servers' tools to the
/// model and runs the tool-call loop (Phase C/D).
class _McpToolsGroup extends ConsumerWidget {
  const _McpToolsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(mcpToolsControllerProvider);
    final controller = ref.read(mcpToolsControllerProvider.notifier);
    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];
    final activeCount = servers.where((s) => s.isActive).length;
    final modeLabel = tools.mode.label;

    return _SettingsGroup(
      title: 'MCP 工具',
      subtitle: activeCount > 0
          ? '$activeCount 个服务器运行中 | 模式: $modeLabel'
          : '模式: $modeLabel',
      children: [
        _SwitchSettingRow(
          title: '启用 MCP 工具',
          description: '在对话中向模型提供已激活服务器的工具',
          value: tools.enabled,
          onChanged: (v) => controller.setEnabled(enabled: v),
        ),
        _SelectSettingRow<McpMode>(
          title: '工具调用模式',
          description: '函数调用：模型自动调用工具（推荐）；提示词注入：通过提示词指导 AI 使用工具',
          value: tools.mode,
          options: [for (final m in McpMode.values) (m, m.label)],
          onChanged: controller.setMode,
        ),
        if (servers.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 6, 16, 6),
            child: Text(
              '还没有配置 MCP 服务器',
              style: TextStyle(fontSize: 12, color: kSidebarMutedIcon),
            ),
          )
        else
          for (final server in servers)
            _McpServerRow(server: server, toolsEnabled: tools.enabled),
        _SettingItemShell(
          title: '管理服务器',
          description: '添加、导入与配置 MCP 服务器',
          onTap: () => context.push(AppRouter.mcpServerPath),
          trailing: const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: kSidebarMutedIcon,
          ),
        ),
      ],
    );
  }
}

/// MCP tools content without the wrapping [_SettingsGroup] accordion — used by
/// the grouped-mode detail view which provides its own header/back navigation.
class _McpToolsGroupContent extends ConsumerWidget {
  const _McpToolsGroupContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(mcpToolsControllerProvider);
    final controller = ref.read(mcpToolsControllerProvider.notifier);
    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwitchSettingRow(
          title: '启用 MCP 工具',
          description: '在对话中向模型提供已激活服务器的工具',
          value: tools.enabled,
          onChanged: (v) => controller.setEnabled(enabled: v),
        ),
        _SelectSettingRow<McpMode>(
          title: '工具调用模式',
          description: '函数调用：模型自动调用工具（推荐）；提示词注入：通过提示词指导 AI 使用工具',
          value: tools.mode,
          options: [for (final m in McpMode.values) (m, m.label)],
          onChanged: controller.setMode,
        ),
        if (servers.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 6, 16, 6),
            child: Text(
              '还没有配置 MCP 服务器',
              style: TextStyle(fontSize: 12, color: kSidebarMutedIcon),
            ),
          )
        else
          for (final server in servers)
            _McpServerRow(server: server, toolsEnabled: tools.enabled),
        _SettingItemShell(
          title: '管理服务器',
          description: '添加、导入与配置 MCP 服务器',
          onTap: () => context.push(AppRouter.mcpServerPath),
          trailing: const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: kSidebarMutedIcon,
          ),
        ),
      ],
    );
  }
}

/// Clickable group entry row for grouped mode top-level view. Similar to the
/// assistant tab's `_GroupEntry` — icon + title + subtitle + chevron.
class _SettingsGroupEntry extends StatelessWidget {
  const _SettingsGroupEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.43,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.66,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 16, color: textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header shown when inside a settings group detail: back arrow + icon + title.
class _SettingsGroupDetailHeader extends StatelessWidget {
  const _SettingsGroupDetailHeader({
    required this.icon,
    required this.title,
    required this.onBack,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final String title;
  final VoidCallback onBack;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBack,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(LucideIcons.arrowLeft, size: 18, color: textPrimary),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single configured-server row inside [_McpToolsGroup]: a type-tinted glyph,
/// the server name + short transport label, and an active switch that flips the
/// server's `isActive` via [McpServers.toggleActive] (disabled until 启用 MCP
/// 工具 is on). Tapping the row opens the server's 详情 page. Mirrors the inline
/// server list of the web `MCPSidebarControls`.
class _McpServerRow extends ConsumerWidget {
  const _McpServerRow({required this.server, required this.toolsEnabled});

  final McpServer server;
  final bool toolsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _mcpTypeColor(server.type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () =>
                  context.push('${AppRouter.mcpServerPath}/${server.id}'),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _mcpTypeIcon(server.type),
                      size: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          server.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _mcpTypeShortLabel(server.type),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CustomSwitch(
            value: server.isActive,
            onChanged: toolsEnabled
                ? (v) => ref
                      .read(mcpServersProvider.notifier)
                      .toggleActive(server.id, isActive: v)
                : null,
          ),
        ],
      ),
    );
  }
}

IconData _mcpTypeIcon(McpServerType type) => switch (type) {
  McpServerType.sse ||
  McpServerType.streamableHttp ||
  McpServerType.httpStream => LucideIcons.globe,
  McpServerType.stdio => LucideIcons.terminal,
  McpServerType.inMemory => LucideIcons.database,
};

Color _mcpTypeColor(McpServerType type) => switch (type) {
  McpServerType.sse => const Color(0xFF2196F3),
  McpServerType.streamableHttp => const Color(0xFF00BCD4),
  McpServerType.httpStream => const Color(0xFF9C27B0),
  McpServerType.stdio => const Color(0xFFFF9800),
  McpServerType.inMemory => const Color(0xFF4CAF50),
};

String _mcpTypeShortLabel(McpServerType type) => switch (type) {
  McpServerType.sse => 'SSE',
  McpServerType.streamableHttp => 'Streamable HTTP',
  McpServerType.httpStream => 'HTTP Stream',
  McpServerType.stdio => 'stdio',
  McpServerType.inMemory => '内存',
};

/// Formats an int with thousands separators, e.g. `100000` → `100,000`.
String _formatInt(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
