import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// Port of the web `MCPServerQuickPanel`
/// (`src/components/input/buttons/MCPServerQuickPanel.tsx`) — the full-screen
/// panel the 输入框 MCP 工具 button opens. The presentation chrome (full-screen
/// dialog, header, tab strip, close button, card mode ≥600px) is the same shell
/// as [showModelSelectorDialog] so the two全屏对话框 feel identical.
///
/// Wired to the MCP features that already exist:
///   • 总开关 → [McpToolsController.setEnabled]
///   • 外部服务器 / 内置工具 / 智能助手 lists → [McpServers] (`mcpServersProvider`)
///   • 逐服务器开关 → [McpServers.toggleActive]
///   • 内置/助手「添加」→ [McpServers.addBuiltin]
///   • 「管理 MCP 服务器」/「前往配置」→ [AppRouter.mcpServerPath]
///
/// 桥梁模式 → [McpToolsController.setBridgeMode]; the 技能 总开关 →
/// [McpToolsController.setSkillsEnabled]; the 技能 tab lists 启用 skills and binds
/// them to the current assistant ([Assistants.toggleSkill]). The 智能助手 rows are
/// UI-only — adding / toggling works, but tapping a row does not navigate to a
/// detail page yet.
Future<void> showMcpQuickPanel(BuildContext context) {
  // Drop the chat input's focus first so the modal route has no node to restore
  // on pop — otherwise closing this full-screen panel re-focuses the input box
  // (and re-raises the keyboard) on the way back to the chat screen.
  FocusManager.instance.primaryFocus?.unfocus();
  return showGeneralDialog<void>(
    context: context,
    barrierColor: const Color(0x80000000),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    pageBuilder: (context, _, _) => const _McpQuickPanelView(),
    transitionBuilder: (context, animation, _, child) => child,
    transitionDuration: Duration.zero,
  );
}

/// Structural design tokens resolved from the active [ThemeData] so the panel
/// follows the selected 主题风格 preset (its `ColorScheme`) instead of fixed
/// light/dark values — the same derivation the model selector dialog uses, so
/// the two 全屏对话框 stay in sync. Only the semantic accents ([success] /
/// [amber] / [violet]) stay fixed, matching the web's intentional status colors.
class _Tokens {
  _Tokens(this.theme);

  final ThemeData theme;
  ColorScheme get _cs => theme.colorScheme;
  Brightness get brightness => theme.brightness;
  bool get dark => brightness == Brightness.dark;

  Color get bgPaper => _cs.surface;
  Color get textPrimary => _cs.onSurface;
  Color get textSecondary => _cs.onSurfaceVariant;
  Color get textDisabled => _cs.onSurface.withValues(alpha: 0.38);
  Color get border => _cs.onSurface.withValues(alpha: 0.12);
  Color get primary => _cs.primary;
  Color get hover => _cs.primary.withValues(alpha: dark ? 0.16 : 0.08);
  // Pill-style tab strip "track" — matches the 语音功能 settings page so the
  // chat panel and the settings page share the same segmented-control look.
  Color get tabTrack => _cs.onSurface.withValues(alpha: 0.06);

  // 运行中 chip / 管理服务器 button accent (web #10b981).
  static const Color success = Color(0xFF10B981);
  // 技能 / 管理技能 accent (web #f59e0b).
  static const Color amber = Color(0xFFF59E0B);
  // 桥梁模式 accent (web #8b5cf6).
  static const Color violet = Color(0xFF8B5CF6);
}

/// `(icon, color, label)` per transport type — verbatim from the web
/// `SERVER_TYPE_CONFIG` so the avatars / chips match the original panel.
({IconData icon, Color color, String label}) _typeConfig(McpServerType type) {
  return switch (type) {
    McpServerType.httpStream => (
      icon: LucideIcons.wifi,
      color: const Color(0xFFFF5722),
      label: 'HTTP Stream',
    ),
    McpServerType.sse => (
      icon: LucideIcons.server,
      color: const Color(0xFF2196F3),
      label: 'SSE',
    ),
    McpServerType.streamableHttp => (
      icon: LucideIcons.wifi,
      color: const Color(0xFF00BCD4),
      label: 'Streamable HTTP',
    ),
    McpServerType.stdio => (
      icon: LucideIcons.terminal,
      color: const Color(0xFFFF9800),
      label: 'stdio',
    ),
    McpServerType.inMemory => (
      icon: LucideIcons.cpu,
      color: const Color(0xFF4CAF50),
      label: 'In Memory',
    ),
  };
}

class _McpQuickPanelView extends ConsumerStatefulWidget {
  const _McpQuickPanelView();

  @override
  ConsumerState<_McpQuickPanelView> createState() => _McpQuickPanelViewState();
}

class _McpQuickPanelViewState extends ConsumerState<_McpQuickPanelView> {
  // 0 = 工具, 1 = 技能 (web `activeTab`).
  int _mainTab = 0;
  // 0 = 外部服务器, 1 = 内置工具, 2 = 智能助手 (web `subTab`).
  int _subTab = 0;

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final t = _Tokens(Theme.of(context));
    final mq = MediaQuery.of(context);
    final fullScreen = mq.size.width < 600;

    final body = _body(t, fullScreen, mq);

    if (fullScreen) {
      return Material(color: t.bgPaper, child: body);
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: mq.size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.bgPaper,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 11),
                  blurRadius: 15,
                  spreadRadius: -7,
                ),
                BoxShadow(
                  color: Color(0x24000000),
                  offset: Offset(0, 24),
                  blurRadius: 38,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 9),
                  blurRadius: 46,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(color: Colors.transparent, child: body),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(_Tokens t, bool fullScreen, MediaQueryData mq) {
    final toolsState = ref.watch(mcpToolsControllerProvider);
    final serversAsync = ref.watch(mcpServersProvider);
    final servers = serversAsync.asData?.value ?? const <McpServer>[];
    final loading = serversAsync.isLoading && !serversAsync.hasValue;
    final activeCount = servers.where((s) => s.isActive).length;

    final topPad = fullScreen
        ? (mq.padding.top > 12 ? mq.padding.top : 12.0)
        : 16.0;
    final safeLeft = fullScreen ? mq.padding.left : 0.0;
    final safeRight = fullScreen ? mq.padding.right : 0.0;

    final content = _mainTab == 0
        ? _toolsTab(t, toolsState.bridgeMode, servers, loading)
        : _skillsTab(t);

    final column = Column(
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            fullScreen ? 12 : 16,
            topPad,
            fullScreen ? 8 : 12,
            8,
          ),
          child: _header(t, toolsState, activeCount),
        ),
        _mainTabs(t),
        if (fullScreen) Expanded(child: content) else Flexible(child: content),
        _bottomActions(t, fullScreen, mq),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(left: safeLeft, right: safeRight),
      child: column,
    );
  }

  // ───────────────────────────── Header ─────────────────────────────

  Widget _header(_Tokens t, McpToolsState toolsState, int activeCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'MCP 工具',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: t.textPrimary,
            ),
          ),
        ),
        if (_mainTab == 0 && activeCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CountChip(
              label: '$activeCount 运行中',
              color: _Tokens.success,
              dark: t.dark,
            ),
          ),
        if (_mainTab == 0)
          _McpSwitch(
            value: toolsState.enabled,
            onChanged: (v) => ref
                .read(mcpToolsControllerProvider.notifier)
                .setEnabled(enabled: v),
          )
        else
          _McpSwitch(
            value: toolsState.skillsEnabled,
            onChanged: (v) => ref
                .read(mcpToolsControllerProvider.notifier)
                .setSkillsEnabled(enabled: v),
          ),
        const SizedBox(width: 4),
        _CloseButton(tokens: t, onTap: _close),
      ],
    );
  }

  Widget _mainTabs(_Tokens t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.tabTrack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              tokens: t,
              icon: LucideIcons.plug,
              label: '工具',
              active: _mainTab == 0,
              onTap: () => setState(() => _mainTab = 0),
            ),
          ),
          Expanded(
            child: _TabButton(
              tokens: t,
              icon: LucideIcons.zap,
              label: '技能',
              active: _mainTab == 1,
              onTap: () => setState(() => _mainTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Tab 0: 工具 ───────────────────────────

  Widget _toolsTab(
    _Tokens t,
    bool bridgeMode,
    List<McpServer> servers,
    bool loading,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bridgeModeBox(t, bridgeMode),
        Expanded(
          child: loading
              ? const Center(child: _LoadingSpinner())
              : servers.isEmpty
              ? _toolsEmptyState(t)
              : _toolsContent(t, servers),
        ),
      ],
    );
  }

  Widget _bridgeModeBox(_Tokens t, bool bridgeMode) {
    const accent = _Tokens.violet;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bridgeMode
            ? accent.withValues(alpha: t.dark ? 0.12 : 0.06)
            : t.textPrimary.withValues(alpha: t.dark ? 0.03 : 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bridgeMode ? accent.withValues(alpha: 0.3) : t.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔌 桥梁模式',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: bridgeMode ? accent : t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bridgeMode ? '已启用 — 1 个工具替代全部，按需动态调用' : '关闭 — 传统模式注入所有工具',
                  style: TextStyle(fontSize: 12, color: t.textSecondary),
                ),
              ],
            ),
          ),
          _McpSwitch(
            value: bridgeMode,
            onChanged: (v) => ref
                .read(mcpToolsControllerProvider.notifier)
                .setBridgeMode(enabled: v),
          ),
        ],
      ),
    );
  }

  Widget _toolsEmptyState(_Tokens t) {
    return _EmptyState(
      tokens: t,
      icon: LucideIcons.plug,
      title: '还没有配置 MCP 服务器',
      subtitle: 'MCP 服务器可以为 AI 提供额外的工具和能力',
      buttonLabel: '前往配置',
      onPressed: () {
        _close();
        context.push(AppRouter.mcpServerPath);
      },
    );
  }

  Widget _toolsContent(_Tokens t, List<McpServer> servers) {
    // Match the MCP server settings page: each sub-tab only lists the servers
    // the user has already added. Adding new built-in / assistant tools is now
    // exclusively done from the settings page's 「添加」 button — the quick
    // panel is a runtime switchboard, not a catalog.
    final external = servers
        .where((s) => !isBuiltinMcpServerName(s.name))
        .toList();
    final builtinNames = kBuiltinMcpServers
        .where((s) => s.category != McpServerCategory.assistant)
        .map((s) => s.name)
        .toSet();
    final assistantNames = kBuiltinMcpServers
        .where((s) => s.category == McpServerCategory.assistant)
        .map((s) => s.name)
        .toSet();
    final builtinAdded = servers
        .where((s) => builtinNames.contains(s.name))
        .toList();
    final assistantAdded = servers
        .where((s) => assistantNames.contains(s.name))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _subTabs(t),
        Expanded(
          child: switch (_subTab) {
            0 => _externalList(t, external),
            1 => _builtinList(t, builtinAdded),
            _ => _assistantList(t, assistantAdded),
          },
        ),
      ],
    );
  }

  Widget _subTabs(_Tokens t) {
    Widget tab(IconData icon, String label, int index) => Expanded(
      child: _TabButton(
        tokens: t,
        icon: icon,
        label: label,
        active: _subTab == index,
        onTap: () => setState(() => _subTab = index),
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.tabTrack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          tab(LucideIcons.server, '外部服务器', 0),
          tab(LucideIcons.cpu, '内置工具', 1),
          tab(LucideIcons.zap, '智能助手', 2),
        ],
      ),
    );
  }

  Widget _externalList(_Tokens t, List<McpServer> external) {
    if (external.isEmpty) {
      return _SubEmpty(
        tokens: t,
        icon: LucideIcons.plug,
        title: '还没有外部服务器',
        subtitle: '前往设置页添加 MCP 服务器',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: external.length,
      separatorBuilder: (_, _) => _rowDivider(t),
      itemBuilder: (context, i) {
        final server = external[i];
        final cfg = _typeConfig(server.type);
        return _ServerRow(
          tokens: t,
          avatar: _TypeAvatar(icon: cfg.icon, color: cfg.color),
          title: server.name,
          subtitle: _TypeChip(label: cfg.label, color: cfg.color),
          trailing: _McpSwitch(
            value: server.isActive,
            onChanged: (v) => ref
                .read(mcpServersProvider.notifier)
                .toggleActive(server.id, isActive: v),
          ),
        );
      },
    );
  }

  Widget _builtinList(_Tokens t, List<McpServer> added) {
    if (added.isEmpty) {
      return _SubEmpty(
        tokens: t,
        icon: LucideIcons.cpu,
        title: '还没有启用内置工具',
        subtitle: '前往下方「管理 MCP 服务器」添加',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: added.length,
      separatorBuilder: (_, _) => _rowDivider(t),
      itemBuilder: (context, i) {
        final server = added[i];
        return _ServerRow(
          tokens: t,
          avatar: const _EmojiAvatar(emoji: '⚙️', color: Color(0xFF4CAF50)),
          title: server.name,
          subtitle: _DescText(text: server.description ?? '内置工具', tokens: t),
          trailing: _McpSwitch(
            value: server.isActive,
            onChanged: (v) => ref
                .read(mcpServersProvider.notifier)
                .toggleActive(server.id, isActive: v),
          ),
        );
      },
    );
  }

  Widget _assistantList(_Tokens t, List<McpServer> added) {
    if (added.isEmpty) {
      return _SubEmpty(
        tokens: t,
        icon: LucideIcons.bot,
        title: '还没有启用智能助手',
        subtitle: '前往下方「管理 MCP 服务器」添加',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: added.length,
      separatorBuilder: (_, _) => _rowDivider(t),
      itemBuilder: (context, i) {
        final server = added[i];
        return _ServerRow(
          tokens: t,
          onTap: () {
            _close();
            context.push(AppRouter.mcpAssistantDetailPath(server.id));
          },
          avatar: const _EmojiAvatar(emoji: '🤖', color: Color(0xFF2196F3)),
          title: server.name,
          subtitle: _DescText(text: server.description ?? '智能助手', tokens: t),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _McpSwitch(
                value: server.isActive,
                onChanged: (v) => ref
                    .read(mcpServersProvider.notifier)
                    .toggleActive(server.id, isActive: v),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: t.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────── Tab 1: 技能 ───────────────────────────

  Widget _skillsTab(_Tokens t) {
    final skillsAsync = ref.watch(skillsProvider);
    final loading = skillsAsync.isLoading && !skillsAsync.hasValue;
    final enabled = (skillsAsync.asData?.value ?? const <Skill>[])
        .where((s) => s.enabled)
        .toList();
    final assistant = ref.watch(currentAssistantProvider);
    final boundIds = assistant?.skillIds?.toSet() ?? const <String>{};

    if (loading) return const Center(child: _LoadingSpinner());
    if (enabled.isEmpty) {
      return _EmptyState(
        tokens: t,
        icon: LucideIcons.zap,
        title: '还没有启用任何技能',
        subtitle: '在设置 → 技能管理中启用技能后，在这里绑定给当前助手',
        buttonLabel: '前往技能管理',
        onPressed: () {
          _close();
          context.push(AppRouter.skillsPath);
        },
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: enabled.length + 1,
      separatorBuilder: (context, i) =>
          i < enabled.length - 1 ? _rowDivider(t) : const SizedBox.shrink(),
      itemBuilder: (context, i) {
        if (i == enabled.length) return _skillsHowItWorks(t);
        final skill = enabled[i];
        final bound = boundIds.contains(skill.id);
        return Opacity(
          opacity: bound ? 1 : 0.6,
          child: _ServerRow(
            tokens: t,
            avatar: _EmojiAvatar(
              emoji: skill.emoji ?? '🔧',
              color: _Tokens.amber,
            ),
            title: skill.name,
            subtitle: _DescText(text: skill.description, tokens: t),
            trailing: _McpSwitch(
              value: bound,
              onChanged: assistant == null
                  ? null
                  : (v) => ref
                        .read(assistantsProvider.notifier)
                        .toggleSkill(assistant.id, skill.id),
            ),
          ),
        );
      },
    );
  }

  Widget _skillsHowItWorks(_Tokens t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Tokens.amber.withValues(alpha: t.dark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tokens.amber.withValues(alpha: 0.15)),
      ),
      child: Text(
        '开关控制技能是否绑定到当前助手。绑定后 AI 会自动匹配，并通过 read_skill 读取技能的完整指令。',
        style: TextStyle(fontSize: 12, height: 1.5, color: t.textSecondary),
      ),
    );
  }

  // ─────────────────────────── Bottom bar ───────────────────────────

  Widget _bottomActions(_Tokens t, bool fullScreen, MediaQueryData mq) {
    final bottom = fullScreen
        ? (mq.padding.bottom + 16).clamp(16.0, double.infinity)
        : 16.0;
    final isTools = _mainTab == 0;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _close();
                context.push(
                  isTools ? AppRouter.mcpServerPath : AppRouter.skillsPath,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: isTools ? _Tokens.success : _Tokens.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(LucideIcons.settings, size: 16),
              label: Text(
                isTools ? '管理 MCP 服务器' : '管理技能',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _close,
              style: OutlinedButton.styleFrom(
                foregroundColor: t.textPrimary,
                side: BorderSide(color: t.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('关闭'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider(_Tokens t) =>
      Divider(height: 1, indent: 60, color: t.border);
}

// ─────────────────────────── Shared widgets ───────────────────────────

/// A list row: leading avatar, title + optional subtitle, trailing action.
class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.tokens,
    required this.avatar,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final _Tokens tokens;
  final Widget avatar;
  final String title;
  final Widget? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final leftContent = Row(
      children: [
        avatar,
        const SizedBox(width: 12),
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: tokens.textPrimary,
                ),
              ),
              if (subtitle != null) ...[const SizedBox(height: 3), subtitle!],
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: onTap == null
                ? leftContent
                : InkWell(onTap: onTap, child: leftContent),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _EmojiAvatar extends StatelessWidget {
  const _EmojiAvatar({required this.emoji, required this.color});
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 17)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _DescText extends StatelessWidget {
  const _DescText({required this.text, required this.tokens});
  final String text;
  final _Tokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, height: 1.35, color: tokens.textSecondary),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.color,
    required this.dark,
  });
  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: dark ? color : const Color(0xFF166534),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final _Tokens tokens;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: tokens.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.primary,
                side: BorderSide(color: tokens.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(LucideIcons.settings, size: 16),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubEmpty extends StatelessWidget {
  const _SubEmpty({
    required this.tokens,
    required this.title,
    this.icon,
    this.subtitle,
  });

  final _Tokens tokens;
  final String title;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 48,
                color: tokens.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Minimal centered spinner placeholder while the server list hydrates.
class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// The compact pill switch — a local copy of the settings `CustomSwitch`
/// (the import-boundary rule forbids the chat feature from importing the
/// settings feature's presentation). Renders its [value] at full fidelity when
/// [onChanged] is null (used for the 即将支持 placeholders).
class _McpSwitch extends StatelessWidget {
  const _McpSwitch({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 32;
  static const double _trackHeight = 16;
  static const double _thumbSize = 12;
  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = onChanged != null;
    final trackColor = value
        ? theme.colorScheme.primary
        : (isDark ? const Color(0xFF8796A5) : const Color(0xFFAAB4BE));

    final pill = AnimatedContainer(
      duration: _duration,
      width: _trackWidth,
      height: _trackHeight,
      decoration: BoxDecoration(
        color: enabled ? trackColor : trackColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _duration,
            curve: Curves.easeInOut,
            left: value ? 18 : 2,
            top: (_trackHeight - _thumbSize) / 2,
            child: Container(
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.7),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!enabled) return pill;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.instance.onSwitch();
        onChanged!(!value);
      },
      child: pill,
    );
  }
}

/// Pill-style tab pill matching the 语音功能 settings page `_TabHeader` (and the
/// MCP server settings page) — the white "card" that slides under the active
/// tab, with onSurface text and a soft 1px shadow. Rendered inside a [Container]
/// "track" (see [_mainTabs] / [_subTabs]).
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _Tokens tokens;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? tokens.textPrimary : tokens.textSecondary;
    // Pill segmented controls swap state instantly (iOS UISegmentedControl
    // behaviour). An AnimatedContainer here would cross-fade the white
    // "card" + shadow on both buttons for 200ms, producing a visible flicker
    // — Flutter's built-in TabBar avoids that by sliding a single shared
    // indicator between tabs, but we're hand-rolling the strip here, so the
    // safest equivalent is just a static [Container].
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? tokens.bgPaper : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.tokens, required this.onTap});
  final _Tokens tokens;
  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? widget.tokens.hover : Colors.transparent,
          ),
          child: Icon(
            Icons.close,
            size: 22,
            color: widget.tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
