// 「工具授权」设置页（工作区管理 → 工具授权）。
//
// 让用户按工具决定 AI 调用工作区配套 MCP 工具（@aether/file-editor 写操作、
// @aether/terminal 命令执行）时是否免审批（白名单）。读类工具本来就不需要
// 确认，页面只做说明。越出项目工作区 root 的终端命令不受白名单覆盖，
// 仍强制审批（双作用域设计稿 §4.1）。策略模型与持久化在
// shared/mcp_tools/settings/tool_auth_policy.dart。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

/// 打开工具授权设置页。
Future<void> showToolAuthSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ToolAuthSettingsPage()),
  );
}

class ToolAuthSettingsPage extends ConsumerWidget {
  const ToolAuthSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final policy = ref.watch(toolAuthPolicyProvider);

    final fileEditorTools = kToolAuthCatalog
        .where((m) => m.server == kFileEditorServerName)
        .toList();
    final terminalTools = kToolAuthCatalog
        .where((m) => m.server == kTerminalServerName)
        .toList();

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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('工具授权'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _HintCard(
            theme: theme,
            text: '开启「免授权」后，AI 调用该工具时不再弹确认。'
                '读取类工具（浏览目录 / 读文件 / 搜索等）本来就无需确认。'
                '越出项目工作区目录的终端命令无论如何设置都会要求确认。',
          ),
          const SizedBox(height: 16),
          _SectionHeader(theme: theme, title: '文件工具（@aether/file-editor）'),
          _ToolCard(
            theme: theme,
            tools: fileEditorTools,
            policy: policy,
            onChanged: (meta, v) => ref
                .read(toolAuthPolicyProvider.notifier)
                .setTool(meta.server, meta.name, autoApprove: v),
          ),
          const SizedBox(height: 16),
          _SectionHeader(theme: theme, title: '终端工具（@aether/terminal）'),
          _ToolCard(
            theme: theme,
            tools: terminalTools,
            policy: policy,
            onChanged: (meta, v) => ref
                .read(toolAuthPolicyProvider.notifier)
                .setTool(meta.server, meta.name, autoApprove: v),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.theme, required this.title});

  final ThemeData theme;
  final String title;

  @override
  Widget build(BuildContext context) {
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

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.theme,
    required this.tools,
    required this.policy,
    required this.onChanged,
  });

  final ThemeData theme;
  final List<ToolAuthMeta> tools;
  final ToolAuthPolicy policy;
  final void Function(ToolAuthMeta meta, bool autoApprove) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 16, color: theme.dividerColor),
            SwitchListTile(
              title: Row(
                children: [
                  Flexible(child: Text(tools[i].label)),
                  const SizedBox(width: 8),
                  _RiskBadge(theme: theme, risk: tools[i].risk),
                ],
              ),
              subtitle: Text(tools[i].description),
              value: policy.isAutoApproved(tools[i].server, tools[i].name),
              onChanged: (v) => onChanged(tools[i], v),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.theme, required this.risk});

  final ThemeData theme;
  final ToolAuthRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = risk == ToolAuthRisk.high
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;
    final label = risk == ToolAuthRisk.high ? '高危' : '中危';
    return Container(
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
