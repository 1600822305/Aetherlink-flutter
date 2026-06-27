import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/settings_tools.dart';

/// Level-2 detail page for an assistant MCP server (e.g. @aether/settings).
/// Shows the server description, a global enable switch, and tools grouped by
/// domain — each domain row links to the Level-3 tool-list page.
class McpAssistantDetailPage extends ConsumerWidget {
  const McpAssistantDetailPage({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(mcpServersProvider);
    final servers = serversAsync.asData?.value ?? const <McpServer>[];
    final server = _find(servers, serverId);

    if (server == null) {
      return Scaffold(
        appBar: const ModelSettingsAppBar(title: '智能助手'),
        body: Center(
          child: Text(
            '助手不存在',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final allTools = builtinToolsFor(server.name);
    final disabled = server.disabledTools?.toSet() ?? const <String>{};

    // Group tools by domain.
    final domainMap = <String, List<String>>{};
    for (final tool in allTools) {
      final domain = inferSettingsDomain(tool.name);
      domainMap.putIfAbsent(domain, () => []).add(tool.name);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: ModelSettingsAppBar(title: server.name),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // Server info card.
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        LucideIcons.bot,
                        size: 22,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '内置服务器',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomSwitch(
                      value: server.isActive,
                      onChanged: (v) => ref
                          .read(mcpServersProvider.notifier)
                          .toggleActive(server.id, isActive: v),
                    ),
                  ],
                ),
                if (server.description != null &&
                    server.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    server.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Domain groups.
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    '工具领域',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                for (var i = 0; i < domainMap.length; i++) ...[
                  _DomainRow(
                    serverId: server.id,
                    domain: domainMap.keys.elementAt(i),
                    toolNames: domainMap.values.elementAt(i),
                    disabledTools: disabled,
                  ),
                  if (i < domainMap.length - 1)
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  McpServer? _find(List<McpServer> servers, String id) {
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// A single domain row: icon + domain label + enabled/total chip + chevron.
class _DomainRow extends StatelessWidget {
  const _DomainRow({
    required this.serverId,
    required this.domain,
    required this.toolNames,
    required this.disabledTools,
  });

  final String serverId;
  final String domain;
  final List<String> toolNames;
  final Set<String> disabledTools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount = toolNames
        .where((n) => !disabledTools.contains(n))
        .length;
    final total = toolNames.length;

    final (icon, color, label) = _domainMeta(domain);

    final chipColor = enabledCount == total
        ? const Color(0xFF22C55E)
        : enabledCount == 0
        ? theme.colorScheme.error
        : const Color(0xFFF59E0B);

    return InkWell(
      onTap: () =>
          context.push(AppRouter.mcpAssistantDomainPath(serverId, domain)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$enabledCount/$total 个工具',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: chipColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color, String) _domainMeta(String domain) =>
      switch (domain) {
        'providers' => (LucideIcons.brain, const Color(0xFFEAB308), '模型管理'),
        _ => (LucideIcons.wrench, const Color(0xFF94A3B8), '通用工具'),
      };
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
