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
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor/parameter_editor.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/sidebar_layout_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';
import 'package:aetherlink_flutter/features/chat/application/user_avatar_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/avatar_edit_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_buttons.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/user_avatar_widget.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

part 'mcp_tools_group.dart';
part 'setting_rows.dart';

/// 设置 entry leading gear, `#1976d2`.
const Color _cogBlue = Color(0xFF1976D2);

/// 侧边栏宽度 toggle button background, `rgba(0,0,0,0.04)`.
const Color _panelButtonBg = Color(0x0A000000);

/// 用户头像 row tint `rgba(255,193,7,0.10)` + its `#ffc107` left accent.
const Color _userRowBg = Color(0x1AFFC107);

const Color _userRowAccent = Color(0xFFFFC107);

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  /// When non-null, the user has navigated into this group (grouped mode).
  String? _activeGroupId;

  void _enterGroup(String groupId) {
    setState(() => _activeGroupId = groupId);
  }

  void _exitGroup() {
    setState(() => _activeGroupId = null);
  }

  // ── Group children builders (shared by both modes) ─────────────────────

  List<Widget> _generalChildren(
    SidebarSettings s,
    SidebarSettingsController c,
  ) => [
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
      description: '显示上下按钮快速跳转消息',
      value: s.messageNavigation,
      options: [for (final v in MessageNavigation.values) (v, v.label)],
      onChanged: c.setMessageNavigation,
    ),
    if (s.messageNavigation == MessageNavigation.buttons)
      _SwitchSettingRow(
        title: '滚动时显示导航',
        description: '滚动时自动弹出导航，停止后隐藏',
        value: s.showNavigationOnScroll,
        onChanged: c.setShowNavigationOnScroll,
      ),
    _SwitchSettingRow(
      title: '显示 Token 用量',
      description: '在信息气泡底部工具栏显示 Token 用量',
      value: s.showMessageTokenUsage,
      onChanged: c.setShowMessageTokenUsage,
    ),
    _SwitchSettingRow(
      title: '消息可选中复制',
      description: '允许长按选中/复制聊天消息的正文内容',
      value: s.selectableMessageText,
      onChanged: c.setSelectableMessageText,
    ),
  ];

  List<Widget> _contextChildren(
    SidebarSettings s,
    SidebarSettingsController c,
  ) => [
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
  ];

  List<Widget> _inputChildren(SidebarSettings s, SidebarSettingsController c) =>
      [
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
      ];

  List<Widget> _codeChildren(SidebarSettings s, SidebarSettingsController c) =>
      [
        _SelectSettingRow<String>(
          title: '代码高亮主题',
          description: '190+ 语言语法高亮，28 种精选主题',
          value: s.codeHighlightTheme,
          options: const [
            ('auto', '自动（跟随主题）'),
            ('atom-one-dark-reasonable', 'Atom One Dark Reasonable'),
            ('atom-one-dark', 'Atom One Dark'),
            ('github-dark', 'GitHub Dark'),
            ('github-dark-dimmed', 'GitHub Dark Dimmed'),
            ('vs2015', 'VS2015 Dark'),
            ('monokai-sublime', 'Monokai Sublime'),
            ('dracula', 'Dracula'),
            ('nord', 'Nord'),
            ('solarized-dark', 'Solarized Dark'),
            ('tokyo-night-dark', 'Tokyo Night Dark'),
            ('androidstudio', 'Android Studio'),
            ('night-owl', 'Night Owl'),
            ('stackoverflow-dark', 'StackOverflow Dark'),
            ('gruvbox-dark', 'Gruvbox Dark'),
            ('a11y-dark', 'A11y Dark'),
            ('shades-of-purple', 'Shades of Purple'),
            ('panda-syntax-dark', 'Panda Dark'),
            ('github', 'GitHub'),
            ('atom-one-light', 'Atom One Light'),
            ('vs', 'VS Light'),
            ('xcode', 'Xcode'),
            ('idea', 'IntelliJ IDEA'),
            ('solarized-light', 'Solarized Light'),
            ('tokyo-night-light', 'Tokyo Night Light'),
            ('stackoverflow-light', 'StackOverflow Light'),
            ('gruvbox-light', 'Gruvbox Light'),
            ('a11y-light', 'A11y Light'),
            ('panda-syntax-light', 'Panda Light'),
          ],
          onChanged: c.setCodeHighlightTheme,
        ),
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
        if (s.codeCollapsible)
          _SwitchSettingRow(
            title: '默认折叠',
            description: '代码块默认以折叠状态显示',
            value: s.codeDefaultCollapsed,
            onChanged: c.setCodeDefaultCollapsed,
          ),
        _SliderSettingRow(
          title: '代码字体大小',
          description: '调整代码块内字体大小（10-24）',
          value: s.codeFontSize.toDouble(),
          min: 10,
          max: 24,
          divisions: 14,
          valueLabel: '${s.codeFontSize}',
          onChanged: (v) => c.setCodeFontSize(v.round()),
        ),
        _SwitchSettingRow(
          title: '固定高度',
          description: '展开后限制最大高度，内容在容器内滚动（配合全屏查看使用）',
          value: s.codeFixedHeight,
          onChanged: c.setCodeFixedHeight,
        ),
        if (s.codeFixedHeight)
          _SliderSettingRow(
            title: '最大高度',
            description: '代码块展开后的最大高度（px）',
            value: s.codeMaxHeight.toDouble(),
            min: 100,
            max: 800,
            divisions: 14,
            valueLabel: '${s.codeMaxHeight}',
            onChanged: (v) => c.setCodeMaxHeight(v.round()),
          ),
        _SwitchSettingRow(
          title: 'Mermaid 图表',
          description: '渲染 Mermaid 流程图 / 时序图 / 饼图 / 甘特图等',
          value: s.mermaidEnabled,
          onChanged: c.setMermaidEnabled,
        ),
      ];

  List<Widget> _mathChildren(
    SidebarSettings s,
    SidebarSettingsController c,
  ) => [
    const _StaticSettingRow(title: '渲染引擎', value: 'KaTeX（flutter_math，原生渲染）'),
    _SwitchSettingRow(
      title: '单美元符号',
      description: r'识别 $...$ 作为行内公式',
      value: s.mathEnableSingleDollar,
      onChanged: c.setMathEnableSingleDollar,
    ),
  ];

  // ── Group descriptors for grouped mode ─────────────────────────────────

  static const _groupDescriptors = <({String id, String title, IconData icon})>[
    (id: 'general', title: '常规设置', icon: LucideIcons.settings2),
    (id: 'context', title: '上下文设置', icon: LucideIcons.messageSquare),
    (id: 'parameters', title: '参数管理', icon: LucideIcons.sliders),
    (id: 'input', title: '输入设置', icon: LucideIcons.keyboard),
    (id: 'code', title: '代码块设置', icon: LucideIcons.code),
    (id: 'math', title: '数学公式设置', icon: LucideIcons.sigma),
    (id: 'mcp', title: 'MCP 工具', icon: LucideIcons.wrench),
  ];

  String _groupSubtitle(String id, SidebarSettings s) => switch (id) {
    'general' => '8 个基础功能设置',
    'context' =>
      '窗口: ${s.contextWindowSize > 0 ? _formatInt(s.contextWindowSize) : '自动'}'
          ' | 输出: ${s.enableMaxOutputTokens ? _formatInt(s.maxOutputTokens) : '默认'}',
    'parameters' => '模型参数配置与自定义参数',
    'input' => '粘贴和输入相关的功能设置',
    'code' => '配置代码显示和编辑功能',
    'math' => '渲染引擎: KaTeX',
    'mcp' => 'MCP 服务器与工具调用',
    _ => '',
  };

  List<Widget> _groupChildren(
    String id,
    SidebarSettings s,
    SidebarSettingsController c,
  ) => switch (id) {
    'general' => _generalChildren(s, c),
    'context' => _contextChildren(s, c),
    'parameters' => const [ParameterEditor()],
    'input' => _inputChildren(s, c),
    'code' => _codeChildren(s, c),
    'math' => _mathChildren(s, c),
    _ => const [],
  };

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sidebarSettingsControllerProvider);
    final c = ref.read(sidebarSettingsControllerProvider.notifier);
    final isGrouped = s.settingsLayoutMode == SettingsLayoutMode.grouped;

    if (isGrouped && _activeGroupId != null) {
      return _buildGroupDetail(s, c);
    }

    if (isGrouped) {
      return _buildGroupedTopLevel(s, c);
    }

    return _buildCompact(s, c);
  }

  /// Compact mode: existing accordion layout.
  Widget _buildCompact(SidebarSettings s, SidebarSettingsController c) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        const _SettingsEntryRow(),
        const _SettingsDivider(),
        const _UserAvatarRow(),
        const _SettingsDivider(),
        _SettingsGroup(
          title: '常规设置',
          subtitle: '8 个基础功能设置',
          children: _generalChildren(s, c),
        ),
        const _SettingsDivider(),
        _SettingsGroup(
          title: '上下文设置',
          subtitle:
              '窗口: ${s.contextWindowSize > 0 ? _formatInt(s.contextWindowSize) : '自动'}'
              ' | 输出: ${s.enableMaxOutputTokens ? _formatInt(s.maxOutputTokens) : '默认'}',
          children: _contextChildren(s, c),
        ),
        const _SettingsDivider(),
        const _SettingsGroup(
          title: '参数管理',
          subtitle: '模型参数配置与自定义参数',
          children: [ParameterEditor()],
        ),
        const _SettingsDivider(),
        _SettingsGroup(
          title: '输入设置',
          subtitle: '粘贴和输入相关的功能设置',
          children: _inputChildren(s, c),
        ),
        const _SettingsDivider(),
        _SettingsGroup(
          title: '代码块设置',
          subtitle: '配置代码显示和编辑功能',
          children: _codeChildren(s, c),
        ),
        const _SettingsDivider(),
        _SettingsGroup(
          title: '数学公式设置',
          subtitle: '渲染引擎: KaTeX',
          children: _mathChildren(s, c),
        ),
        const _SettingsDivider(),
        const _McpToolsGroup(),
      ],
    );
  }

  /// Grouped mode top-level: group entry rows (clickable, navigate into).
  Widget _buildGroupedTopLevel(SidebarSettings s, SidebarSettingsController c) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        const _SettingsEntryRow(),
        const _SettingsDivider(),
        const _UserAvatarRow(),
        const _SettingsDivider(),
        for (final g in _groupDescriptors)
          _SettingsGroupEntry(
            icon: g.icon,
            title: g.title,
            subtitle: _groupSubtitle(g.id, s),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _enterGroup(g.id),
          ),
      ],
    );
  }

  /// Grouped mode detail: inside a specific group, with back header.
  Widget _buildGroupDetail(SidebarSettings s, SidebarSettingsController c) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    final descriptor = _groupDescriptors
        .where((g) => g.id == _activeGroupId)
        .firstOrNull;
    if (descriptor == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeGroupId = null);
      });
      return const SizedBox.shrink();
    }

    final isMcp = _activeGroupId == 'mcp';
    final children = isMcp ? <Widget>[] : _groupChildren(_activeGroupId!, s, c);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back header
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: _SettingsGroupDetailHeader(
            icon: descriptor.icon,
            title: descriptor.title,
            onBack: _exitGroup,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),
        const _SettingsDivider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              if (isMcp)
                const _McpToolsGroupContent()
              else
                for (final child in children) child,
            ],
          ),
        ),
      ],
    );
  }
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

class _UserAvatarRow extends ConsumerWidget {
  const _UserAvatarRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final avatar = ref.watch(userAvatarControllerProvider);
    return GestureDetector(
      onTap: () => showAvatarEditSheet(context, ref),
      child: Container(
        decoration: const BoxDecoration(
          color: _userRowBg,
          border: Border(left: BorderSide(color: _userRowAccent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            UserAvatarWidget(avatar: avatar, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    avatar.name.isNotEmpty ? avatar.name : '用户头像',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.4,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    '设置您的头像与名称',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SidebarMutedIconButton(
              icon: LucideIcons.pencil,
              size: 16,
              box: 28,
              onPressed: () => showAvatarEditSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// A collapsible 设置 group: a tappable header (title + subtitle + optional
/// chip + rotating chevron) over an expandable body. Mirrors the web
/// `SettingGroup` accordion; collapsed by default.
class _SettingsGroup extends StatefulWidget {
  const _SettingsGroup({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

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
