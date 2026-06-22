import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/settings_tools.dart';

/// Level-3 page: lists every tool in a specific domain, with per-tool
/// enable/disable switches and permission badges. The top-right global switch
/// toggles all tools in this domain at once.
class McpToolDomainDetailPage extends ConsumerWidget {
  const McpToolDomainDetailPage({
    required this.serverId,
    required this.domain,
    super.key,
  });

  final String serverId;
  final String domain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(mcpServersProvider);
    final servers = serversAsync.asData?.value ?? const <McpServer>[];
    final server = _find(servers, serverId);

    final domainLabel = _domainLabel(domain);

    if (server == null) {
      return Scaffold(
        appBar: ModelSettingsAppBar(title: domainLabel),
        body: Center(
          child: Text(
            '服务器不存在',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final allTools = builtinToolsFor(server.name);
    final domainTools = allTools
        .where((t) => inferSettingsDomain(t.name) == domain)
        .toList();
    final disabled = server.disabledTools?.toSet() ?? const <String>{};
    final enabledCount = domainTools
        .where((t) => !disabled.contains(t.name))
        .length;
    final allEnabled = enabledCount == domainTools.length;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: domainLabel,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$enabledCount/${domainTools.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomSwitch(
                    value: allEnabled,
                    onChanged: (v) {
                      _toggleAll(ref, server, domainTools, enable: v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < domainTools.length; i++) ...[
                  _ToolRow(
                    server: server,
                    tool: domainTools[i],
                    isEnabled: !disabled.contains(domainTools[i].name),
                  ),
                  if (i < domainTools.length - 1)
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAll(
    WidgetRef ref,
    McpServer server,
    List<McpToolDefinition> domainTools, {
    required bool enable,
  }) {
    final current = server.disabledTools?.toSet() ?? <String>{};
    final domainNames = domainTools.map((t) => t.name).toSet();
    final updated = enable
        ? current.difference(domainNames)
        : current.union(domainNames);
    ref
        .read(mcpServersProvider.notifier)
        .edit(server.copyWith(disabledTools: updated.toList()));
  }

  McpServer? _find(List<McpServer> servers, String id) {
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  static String _domainLabel(String domain) => switch (domain) {
    'providers' => '模型管理',
    _ => '通用工具',
  };
}

/// A single tool row: permission badge + name + description + enable switch.
class _ToolRow extends ConsumerWidget {
  const _ToolRow({
    required this.server,
    required this.tool,
    required this.isEnabled,
  });

  final McpServer server;
  final McpToolDefinition tool;
  final bool isEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final permission = inferSettingsPermission(tool.name);
    final (permLabel, permColor) = _permissionMeta(permission);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tool.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _PermChip(label: permLabel, color: permColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tool.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CustomSwitch(value: isEnabled, onChanged: (v) => _toggle(ref, v)),
        ],
      ),
    );
  }

  void _toggle(WidgetRef ref, bool enable) {
    final current = server.disabledTools?.toSet() ?? <String>{};
    final updated = enable
        ? (Set<String>.of(current)..remove(tool.name))
        : (Set<String>.of(current)..add(tool.name));
    ref
        .read(mcpServersProvider.notifier)
        .edit(server.copyWith(disabledTools: updated.toList()));
  }

  static (String, Color) _permissionMeta(SettingsToolPermission perm) =>
      switch (perm) {
        SettingsToolPermission.read => ('只读', const Color(0xFF22C55E)),
        SettingsToolPermission.write => ('写入', const Color(0xFFF59E0B)),
        SettingsToolPermission.confirm => ('需确认', const Color(0xFFEF4444)),
      };
}

class _PermChip extends StatelessWidget {
  const _PermChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

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
