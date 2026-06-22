// 设 (settings) tab: appearance entries, MCP group and the reusable setting rows.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/sidebar_layout_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_avatar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_buttons.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';

/// 设置 entry leading gear, `#1976d2`.
const Color _cogBlue = Color(0xFF1976D2);

/// 侧边栏宽度 toggle button background, `rgba(0,0,0,0.04)`.
const Color _panelButtonBg = Color(0x0A000000);

/// 用户头像 row tint `rgba(255,193,7,0.10)` + its `#ffc107` left accent.
const Color _userRowBg = Color(0x1AFFC107);

const Color _userRowAccent = Color(0xFFFFC107);

/// 用户头像 avatar background, `#87d068`.
const Color _userAvatarBg = Color(0xFF87D068);

/// 兼容 API chip outline, MUI `grey.400` `#bdbdbd`.
const Color _chipBorderColor = Color(0xFFBDBDBD);

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sidebarSettingsControllerProvider);
    final c = ref.read(sidebarSettingsControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        const _SettingsEntryRow(),
        const _SettingsDivider(),
        const _UserAvatarRow(),
        const _SettingsDivider(),
        // 常规设置 (7 项) — fully migrated. 消息分割线 / 代码块可复制 drive the chat
        // view now; the rest persist and light up as their chat widgets land.
        // 「侧边栏显示方式」已并入底部「侧边栏布局」对话框（与宽度同管）。
        _SettingsGroup(
          title: '常规设置',
          subtitle: '7 个基础功能设置',
          children: [
            _SwitchSettingRow(
              title: '消息分割线',
              description: '在消息之间显示分割线',
              value: s.showMessageDivider,
              onChanged: c.setShowMessageDivider,
            ),
            _SwitchSettingRow(
              title: '代码块可复制',
              description: '允许复制代码块的内容',
              value: s.copyableCodeBlocks,
              onChanged: c.setCopyableCodeBlocks,
            ),
            _SwitchSettingRow(
              title: '渲染用户输入',
              description: '渲染用户输入的 Markdown 格式（关闭后用户消息显示为纯文本）',
              value: s.renderUserInputAsMarkdown,
              onChanged: c.setRenderUserInputAsMarkdown,
              comingSoon: true,
            ),
            _SwitchSettingRow(
              title: '自动下滑',
              description: '新消息时自动滚动到聊天底部',
              value: s.autoScrollToBottom,
              onChanged: c.setAutoScrollToBottom,
            ),
            _SelectSettingRow<MessageStyle>(
              title: '消息样式',
              description: '选择聊天消息的显示样式',
              value: s.messageStyle,
              options: [for (final v in MessageStyle.values) (v, v.label)],
              onChanged: c.setMessageStyle,
            ),
            _SelectSettingRow<MessageNavigation>(
              title: '对话导航',
              description: '显示上下按钮快速跳转到上一条/下一条消息',
              value: s.messageNavigation,
              options: [for (final v in MessageNavigation.values) (v, v.label)],
              onChanged: c.setMessageNavigation,
              comingSoon: true,
            ),
            _SwitchSettingRow(
              title: 'Token 用量指示',
              description: '在右侧显示上下文 Token 用量呼吸灯',
              value: s.showContextTokenIndicator,
              onChanged: c.setShowContextTokenIndicator,
              comingSoon: true,
            ),
          ],
        ),
        const _SettingsDivider(),
        // 上下文设置 — contextCount / maxOutputTokens wired in ChatController.
        _SettingsGroup(
          title: '上下文设置',
          subtitle:
              '消息: ${s.contextCount >= 100 ? '最大' : '${s.contextCount} 条'}'
              ' | 输出: ${s.enableMaxOutputTokens ? _formatInt(s.maxOutputTokens) : '默认'}',
          chipLabel: '兼容 API',
          children: [
            _SliderSettingRow(
              title: '上下文消息数量',
              description: '携带的历史消息条数，0 = 无记忆（每次独立对话）',
              value: s.contextCount.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              valueLabel: s.contextCount >= 100 ? '最大' : '${s.contextCount}',
              marks: {0.0: '0', 50.0: '50', 100.0: '最大'},
              onChanged: (v) => c.setContextCount(v.round()),
            ),
            _SwitchSettingRow(
              title: '启用最大输出限制',
              description: '关闭则使用模型默认值',
              value: s.enableMaxOutputTokens,
              onChanged: c.setEnableMaxOutputTokens,
            ),
            if (s.enableMaxOutputTokens)
              _NumberSettingRow(
                title: '最大输出 Token',
                description: '单次回复的 token 上限',
                value: s.maxOutputTokens,
                min: 256,
                max: 200000,
                onChanged: c.setMaxOutputTokens,
              ),
            _NumberSettingRow(
              title: '上下文窗口大小',
              description: '模型可处理的总 Token 数（仅供参考，不限制实际发送）',
              value: s.contextWindowSize,
              min: 1000,
              max: 2000000,
              onChanged: c.setContextWindowSize,
            ),
          ],
        ),
        const _SettingsDivider(),
        // 输入设置 — UI + persist.
        _SettingsGroup(
          title: '输入设置',
          subtitle: '粘贴和输入相关的功能设置',
          children: [
            _SwitchSettingRow(
              title: '长文本粘贴为文件',
              description: '粘贴超长文本时自动转为文件附件',
              value: s.pasteLongTextAsFile,
              onChanged: c.setPasteLongTextAsFile,
            ),
            if (s.pasteLongTextAsFile)
              _NumberSettingRow(
                title: '触发阈值',
                description: '超过该字符数转为文件',
                value: s.pasteLongTextThreshold,
                min: 100,
                max: 10000,
                onChanged: c.setPasteLongTextThreshold,
              ),
          ],
        ),
        const _SettingsDivider(),
        // 代码块设置 — UI + persist; consumed by 代码块视图 later.
        _SettingsGroup(
          title: '代码块设置',
          subtitle: '配置代码显示和编辑功能',
          comingSoon: true,
          children: [
            const _ComingSoonNote(text: '设置会先保存，接入代码块视图后生效。'),
            _SwitchSettingRow(
              title: '显示行号',
              description: '在代码块左侧显示行号',
              value: s.codeShowLineNumbers,
              onChanged: c.setCodeShowLineNumbers,
            ),
            _SwitchSettingRow(
              title: '可折叠',
              description: '允许折叠/展开代码块',
              value: s.codeCollapsible,
              onChanged: c.setCodeCollapsible,
            ),
            _SwitchSettingRow(
              title: '自动换行',
              description: '过长的代码行自动换行',
              value: s.codeWrappable,
              onChanged: c.setCodeWrappable,
            ),
            _SwitchSettingRow(
              title: '默认折叠',
              description: '代码块默认以折叠状态显示',
              value: s.codeDefaultCollapsed,
              onChanged: c.setCodeDefaultCollapsed,
            ),
            _SwitchSettingRow(
              title: 'Mermaid 图表',
              description: '渲染 Mermaid 流程图 / 时序图',
              value: s.mermaidEnabled,
              onChanged: c.setMermaidEnabled,
            ),
            // 高亮主题：Flutter 暂无 Shiki 同款高亮器，主题列表无法复刻；先展示占位。
            const _StaticSettingRow(
              title: '代码高亮主题',
              value: '自动（跟随应用主题）',
              comingSoon: true,
            ),
          ],
        ),
        const _SettingsDivider(),
        // 数学公式设置 — 引擎下拉删除（Flutter 用 flutter_math 原生渲染）。
        _SettingsGroup(
          title: '数学公式设置',
          subtitle: '渲染引擎: KaTeX',
          children: [
            const _StaticSettingRow(
              title: '渲染引擎',
              value: 'KaTeX（flutter_math，原生渲染）',
            ),
            _SwitchSettingRow(
              title: '单美元符号',
              description: r'识别 $...$ 作为行内公式',
              value: s.mathEnableSingleDollar,
              onChanged: c.setMathEnableSingleDollar,
            ),
          ],
        ),
        const _SettingsDivider(),
        // MCP 工具 — 总开关 / 调用模式 / 内联服务器列表，均已接入对话（工具调用）。
        const _McpToolsGroup(),
      ],
    );
  }
}

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
    return InkWell(
      onTap: () => context.push('${AppRouter.mcpServerPath}/${server.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_mcpTypeIcon(server.type), size: 15, color: color),
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
            const SizedBox(width: 8),
            Switch(
              value: server.isActive,
              onChanged: toolsEnabled
                  ? (v) => ref
                        .read(mcpServersProvider.notifier)
                        .toggleActive(server.id, isActive: v)
                  : null,
            ),
          ],
        ),
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

/// Shows a transient 即将支持 toast for affordances whose subsystem is not yet
/// ported (e.g. 头像上传).
void _showComingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$what即将支持'),
        duration: const Duration(seconds: 2),
      ),
    );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    // `Divider my: 0.5` → 4px above/below a 1px line.
    return const Divider(height: 9, thickness: 1);
  }
}

class _SettingsEntryRow extends ConsumerWidget {
  const _SettingsEntryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push(AppRouter.settingsPath),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  const Icon(LucideIcons.cog, size: 20, color: _cogBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '设置',
                          style: TextStyle(
                            fontSize: 15.2,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '进入完整设置页面',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: theme.dividerColor,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // 侧边栏布局 toggle → 打开布局对话框（显示方式 + 宽度）。
          Material(
            color: _panelButtonBg,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => showSidebarLayoutDialog(context, ref),
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  LucideIcons.panelLeft,
                  size: 18,
                  color: kSidebarMutedIcon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatarRow extends StatelessWidget {
  const _UserAvatarRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: const BoxDecoration(
        color: _userRowBg,
        border: Border(left: BorderSide(color: _userRowAccent, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SidebarAvatar(
            text: '我',
            background: _userAvatarBg,
            size: 36,
            fontSize: 22.86,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '用户头像',
                  style: TextStyle(
                    fontSize: 14.4,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '设置您的个人头像',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 头像上传 / 裁剪子系统未移植。
          SidebarMutedIconButton(
            icon: LucideIcons.user,
            size: 16,
            box: 28,
            onPressed: () => _showComingSoon(context, '头像上传'),
          ),
        ],
      ),
    );
  }
}

/// A collapsible 设置 group: a tappable header (title + subtitle + optional chip
/// / 即将支持 badge + rotating chevron) over an expandable body. Mirrors the web
/// `SettingGroup` accordion; collapsed by default.
class _SettingsGroup extends StatefulWidget {
  const _SettingsGroup({
    required this.title,
    required this.subtitle,
    required this.children,
    this.chipLabel,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? chipLabel;
  final bool comingSoon;

  @override
  State<_SettingsGroup> createState() => _SettingsGroupState();
}

class _SettingsGroupState extends State<_SettingsGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.2,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (widget.chipLabel != null) ...[
                            const SizedBox(width: 6),
                            _Chip(label: widget.chipLabel!, color: textPrimary),
                          ],
                        ],
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.comingSoon) ...[
                  const _ComingSoonChip(),
                  const SizedBox(width: 4),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: kSidebarMutedIcon,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// Shared layout for a 设置 item (web `SettingItem`): title (+ 即将支持 chip) and an
/// optional description on the left, a [trailing] control on the right. When
/// [onTap] is set the whole row is tappable (used by the numeric rows).
class _SettingItemShell extends StatelessWidget {
  const _SettingItemShell({
    required this.title,
    required this.trailing,
    this.description,
    this.comingSoon = false,
    this.onTap,
  });

  final String title;
  final String? description;
  final Widget trailing;
  final bool comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      const _ComingSoonChip(),
                    ],
                  ],
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A boolean 设置 item with a trailing [Switch].
class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      description: description,
      comingSoon: comingSoon,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// A 设置 item whose value is chosen from a dropdown of [options] `(value, 标签)`.
class _SelectSettingRow<T> extends StatelessWidget {
  const _SelectSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String title;
  final String description;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      description: description,
      comingSoon: comingSoon,
      trailing: DropdownButton<T>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(8),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: [
          for (final (v, label) in options)
            DropdownMenuItem<T>(value: v, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// A numeric 设置 item: shows the current value and opens a number prompt on tap.
class _NumberSettingRow extends StatelessWidget {
  const _NumberSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingItemShell(
      title: title,
      description: description,
      onTap: () async {
        final result = await _promptNumber(
          context,
          title: title,
          initial: value,
          min: min,
          max: max,
        );
        if (result != null) onChanged(result);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatInt(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.pencil, size: 14, color: kSidebarMutedIcon),
        ],
      ),
    );
  }
}

/// A 设置 item rendered as a labelled slider over `[min, max]`.
class _SliderSettingRow extends StatelessWidget {
  const _SliderSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.marks,
  });

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  /// Optional tick-mark labels keyed by their slider value (e.g.
  /// `{0: '0', 50: '50', 100: '最大'}`). When non-null a row of labels is
  /// rendered below the slider track, matching the original web UI.
  final Map<double, String>? marks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Text(
            description,
            style: TextStyle(fontSize: 11.5, height: 1.3, color: textSecondary),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
          if (marks != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final entry in marks!.entries)
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 10,
                        color: textSecondary,
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

/// A read-only 设置 item: a label and a fixed value (e.g. 渲染引擎 / 高亮主题占位).
class _StaticSettingRow extends StatelessWidget {
  const _StaticSettingRow({
    required this.title,
    required this.value,
    this.comingSoon = false,
  });

  final String title;
  final String value;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      comingSoon: comingSoon,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The amber 即将支持 badge. Re-declared here (rather than reusing the settings
/// feature's chip) because the chat feature must not import another feature's
class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x1FFFA000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66FFA000)),
      ),
      child: const Text(
        '即将支持',
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: Color(0xFFB07400),
        ),
      ),
    );
  }
}

/// A compact info note at the top of an 即将支持 group body, explaining the
/// settings persist now and take effect once the subsystem lands.
class _ComingSoonNote extends StatelessWidget {
  const _ComingSoonNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 2, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompts for an integer in `[min, max]`, returning the clamped value or null
/// on 取消.
Future<int?> _promptNumber(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  final controller = TextEditingController(text: initial.toString());
  int? read() {
    final parsed = int.tryParse(controller.text.trim());
    if (parsed == null) return null;
    return parsed.clamp(min, max);
  }

  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          helperText: '范围 ${_formatInt(min)} – ${_formatInt(max)}',
        ),
        onSubmitted: (_) => Navigator.of(dialogContext).pop(read()),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.of(dialogContext).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.of(dialogContext).pop(read());
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

/// The 兼容 API pill: 20px tall, 1px grey outline, 10.4px / 500 label.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: _chipBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.4,
          height: 1,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
