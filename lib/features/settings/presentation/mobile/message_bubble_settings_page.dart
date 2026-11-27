import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/settings/application/message_bubble_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/color_picker.dart';

/// 「信息气泡管理」页（外观设置 → 本页）。
///
/// 布局：顶部固定一块实时预览（用户 + AI 消息，含工具栏 / 功能气泡），下面是
/// 「操作 / 尺寸 / 头像 / 颜色」四个 tab。所有设置改动即存
/// （[MessageBubbleSettingsController]），预览随之刷新，不用滚动就能看到效果。
/// 工具栏按钮收纳用 chip 点选：高亮 = 外露，其余收进末尾「更多」。
class MessageBubbleSettingsPage extends ConsumerStatefulWidget {
  const MessageBubbleSettingsPage({super.key});

  static const String _title = '信息气泡管理';

  @override
  ConsumerState<MessageBubbleSettingsPage> createState() =>
      _MessageBubbleSettingsPageState();
}

class _MessageBubbleSettingsPageState
    extends ConsumerState<MessageBubbleSettingsPage>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;

  late final TabController _tabController = TabController(
    length: _tabCount,
    vsync: this,
  )..addListener(_onTabChanged);

  int _index = 0;
  double _swipeDx = 0;

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  void _onSwipeEnd() {
    if (_swipeDx.abs() <= 60) return;
    final next = (_tabController.index + (_swipeDx < 0 ? 1 : -1)).clamp(
      0,
      _tabCount - 1,
    );
    if (next != _tabController.index) _tabController.animateTo(next);
  }

  Future<void> _confirmResetAll(
    MessageBubbleSettingsController controller,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复全部默认？'),
        content: const Text(
          '显示模式、气泡宽度、头像和名称、隐藏气泡、工具栏按钮收纳和自定义颜色'
          '都会恢复为默认值，此操作不能撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    controller.resetAll();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已恢复全部默认设置')));
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(messageBubbleSettingsControllerProvider);
    final controller = ref.read(
      messageBubbleSettingsControllerProvider.notifier,
    );

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
                : context.go(AppRouter.appearancePath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(MessageBubbleSettingsPage._title),
        actions: [
          TextButton(
            onPressed: settings == const MessageBubbleSettings()
                ? null
                : () => _confirmResetAll(controller),
            child: const Text('恢复默认'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 固定预览：不随 tab 内容滚动。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: _LivePreview(settings: settings),
          ),
          _TabBarHeader(controller: _tabController),
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (_) => _swipeDx = 0,
              onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
              onHorizontalDragEnd: (_) => _onSwipeEnd(),
              child: IndexedStack(
                index: _index,
                sizing: StackFit.expand,
                children: [
                  _TabList(
                    children: [
                      _ActionsGroup(settings: settings, controller: controller),
                      if (settings.messageActionMode ==
                          MessageActionMode.toolbar)
                        _ToolbarChipsGroup(
                          settings: settings,
                          controller: controller,
                        ),
                    ],
                  ),
                  _TabList(
                    children: [
                      _SizeGroup(settings: settings, controller: controller),
                    ],
                  ),
                  _TabList(
                    children: [
                      _AvatarGroup(settings: settings, controller: controller),
                    ],
                  ),
                  _TabList(
                    children: [
                      _HideGroup(settings: settings, controller: controller),
                      _ColorsGroup(settings: settings, controller: controller),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个 tab 的滚动区（含底部安全区）。
class _TabList extends StatelessWidget {
  const _TabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }
}

/// 下划线式四等分 tab：操作 / 尺寸 / 头像 / 颜色。
class _TabBarHeader extends StatelessWidget {
  const _TabBarHeader({required this.controller});

  final TabController controller;

  static const List<String> _tabs = ['操作', '尺寸', '头像', '颜色'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: controller,
        dividerColor: theme.dividerColor,
        indicatorColor: theme.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        tabs: [for (final label in _tabs) Tab(height: 42, text: label)],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 分组列表骨架
// ---------------------------------------------------------------------------

/// 分组：灰色小标题（可带右侧操作）+ 白色圆角卡，行之间细分隔线。
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: theme.dividerColor));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 2, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}

/// 一行：标题（可带一行说明）+ 右侧控件。
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Row(
      title: title,
      subtitle: subtitle,
      trailing: CustomSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// 紧凑分段控件（2~3 个选项）。
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: v == value ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: v == value
                      ? [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.08),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                    color: v == value ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 操作 tab
// ---------------------------------------------------------------------------

class _ActionsGroup extends StatelessWidget {
  const _ActionsGroup({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final isBubbles = settings.messageActionMode == MessageActionMode.bubbles;
    return _Group(
      title: '消息操作',
      children: [
        _Row(
          title: '显示模式',
          trailing: _Segmented<MessageActionMode>(
            value: settings.messageActionMode,
            options: const [
              (MessageActionMode.bubbles, '功能气泡'),
              (MessageActionMode.toolbar, '工具栏'),
            ],
            onChanged: controller.setMessageActionMode,
          ),
        ),
        if (isBubbles)
          _SwitchRow(
            title: '显示功能气泡',
            subtitle: '气泡上方的播放 / 版本切换小按钮',
            value: settings.showMicroBubbles,
            onChanged: controller.setShowMicroBubbles,
          ),
        if (isBubbles && settings.showMicroBubbles) ...[
          _SwitchRow(
            title: '显示播放按钮',
            subtitle: '把 AI 回复转成语音',
            value: settings.showTTSButton,
            onChanged: controller.setShowTTSButton,
          ),
          _Row(
            title: '版本切换',
            subtitle: '列表：弹出全部版本；箭头：左右切换',
            trailing: _Segmented<VersionSwitchStyle>(
              value: settings.versionSwitchStyle,
              options: const [
                (VersionSwitchStyle.popup, '列表'),
                (VersionSwitchStyle.arrows, '‹ 2 ›'),
              ],
              onChanged: controller.setVersionSwitchStyle,
            ),
          ),
        ],
      ],
    );
  }
}

/// 工具栏按钮收纳：chip 点选，高亮 = 外露，其余收进「更多」。
/// 重新生成与重新发送共用一个 chip。
class _ToolbarChipsGroup extends StatelessWidget {
  const _ToolbarChipsGroup({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  List<String> get _collapsed =>
      settings.collapsedActionIds ?? kDefaultCollapsedActionIds;

  void _toggle(MessageActionId id) {
    final next = {..._collapsed};
    final names = id == MessageActionId.regenerate
        ? const ['regenerate', 'resend']
        : [id.name];
    final collapse = !next.contains(id.name);
    for (final name in names) {
      collapse ? next.add(name) : next.remove(name);
    }
    controller.setCollapsedActionIds(next.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final collapsed = _collapsed.toSet();
    final isPreset = settings.collapsedActionIds == null ||
        (collapsed.length == kDefaultCollapsedActionIds.length &&
            collapsed.containsAll(kDefaultCollapsedActionIds));
    final exposedCount = _kToolbarOrder
        .where((id) => !collapsed.contains(id.name))
        .length;

    return _Group(
      title: '工具栏按钮 · 高亮外露 $exposedCount 个，其余收进「⋯」',
      trailing: isPreset
          ? null
          : GestureDetector(
              onTap: () => controller.setCollapsedActionIds(
                kDefaultCollapsedActionIds.toList(),
              ),
              child: Text(
                '恢复预设',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                ),
              ),
            ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final id in _kToolbarOrder)
                _ActionChip(
                  icon: kMessageActionCatalog[id]!.icon,
                  label: kMessageActionCatalog[id]!.label,
                  selected: !collapsed.contains(id.name),
                  onTap: () => _toggle(id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.1)
                : cs.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI 消息工具栏的按钮顺序（预览与 chip 共用）。
const List<MessageActionId> _kToolbarOrder = [
  MessageActionId.copy,
  MessageActionId.edit,
  MessageActionId.export,
  MessageActionId.regenerate,
  MessageActionId.regenerateWithModel,
  MessageActionId.tts,
  MessageActionId.translate,
  MessageActionId.versionHistory,
  MessageActionId.fork,
  MessageActionId.branch,
  MessageActionId.saveToKnowledge,
  MessageActionId.delete,
];

// ---------------------------------------------------------------------------
// 尺寸 / 头像 / 颜色 tab
// ---------------------------------------------------------------------------

class _SizeGroup extends StatelessWidget {
  const _SizeGroup({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: child,
    );
    return _Group(
      title: '气泡宽度（占聊天区宽度）',
      children: [
        pad(
          _WidthSlider(
            icon: LucideIcons.bot,
            label: 'AI消息最大宽度',
            value: settings.messageBubbleMaxWidth,
            min: 50,
            max: 100,
            onChanged: controller.setMessageBubbleMaxWidth,
          ),
        ),
        pad(
          _WidthSlider(
            icon: LucideIcons.user,
            label: '用户消息最大宽度',
            value: settings.userMessageMaxWidth,
            min: 50,
            max: 100,
            onChanged: controller.setUserMessageMaxWidth,
          ),
        ),
        pad(
          _WidthSlider(
            icon: LucideIcons.minimize2,
            label: '消息最小宽度',
            value: settings.messageBubbleMinWidth,
            min: 10,
            max: 90,
            onChanged: controller.setMessageBubbleMinWidth,
          ),
        ),
      ],
    );
  }
}

class _AvatarGroup extends StatelessWidget {
  const _AvatarGroup({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _Group(
      title: '头像和名称',
      children: [
        _SwitchRow(
          title: '用户头像',
          value: settings.showUserAvatar,
          onChanged: controller.setShowUserAvatar,
        ),
        _SwitchRow(
          title: '用户名称',
          value: settings.showUserName,
          onChanged: controller.setShowUserName,
        ),
        _SwitchRow(
          title: '模型头像',
          value: settings.showModelAvatar,
          onChanged: controller.setShowModelAvatar,
        ),
        _SwitchRow(
          title: '模型名称',
          value: settings.showModelName,
          onChanged: controller.setShowModelName,
        ),
      ],
    );
  }
}

class _HideGroup extends StatelessWidget {
  const _HideGroup({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _Group(
      title: '隐藏气泡',
      children: [
        _SwitchRow(
          title: '隐藏用户气泡',
          subtitle: '去掉背景，只显示文字',
          value: settings.hideUserBubble,
          onChanged: controller.setHideUserBubble,
        ),
        _SwitchRow(
          title: '隐藏 AI 气泡',
          subtitle: '去掉背景，只显示文字',
          value: settings.hideAIBubble,
          onChanged: controller.setHideAIBubble,
        ),
      ],
    );
  }
}

class _ColorsGroup extends StatelessWidget {
  const _ColorsGroup({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = settings.customBubbleColors;
    void update(CustomBubbleColors next) =>
        controller.setCustomBubbleColors(next);

    Widget head(String text) => Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          title: '自定义颜色',
          trailing: GestureDetector(
            onTap: controller.resetCustomBubbleColors,
            child: Text(
              '重置默认',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 120),
                      head('背景色'),
                      head('文字色'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ColorRow(
                    icon: LucideIcons.user,
                    label: '用户消息',
                    bubbleColor: colors.userBubbleColor.isEmpty
                        ? '#1976d2'
                        : colors.userBubbleColor,
                    textColor: colors.userTextColor.isEmpty
                        ? '#ffffff'
                        : colors.userTextColor,
                    onBubbleChanged: (c) =>
                        update(colors.copyWith(userBubbleColor: c)),
                    onTextChanged: (c) =>
                        update(colors.copyWith(userTextColor: c)),
                  ),
                  const SizedBox(height: 8),
                  _ColorRow(
                    icon: LucideIcons.bot,
                    label: 'AI回复',
                    bubbleColor: colors.aiBubbleColor.isEmpty
                        ? '#f5f5f5'
                        : colors.aiBubbleColor,
                    textColor: colors.aiTextColor.isEmpty
                        ? '#333333'
                        : colors.aiTextColor,
                    onBubbleChanged: (c) =>
                        update(colors.copyWith(aiBubbleColor: c)),
                    onTextChanged: (c) =>
                        update(colors.copyWith(aiTextColor: c)),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            '文字色同时控制气泡内文字和工具栏按钮的颜色。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 固定实时预览
// ---------------------------------------------------------------------------

/// 页面顶部的固定预览：用户 + AI 消息，反映颜色 / 宽度 / 头像名称 / 隐藏气泡；
/// AI 消息下方按显示模式画工具栏（外露图标 + 「⋯」）或上方的功能气泡。
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.settings});

  final MessageBubbleSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final colors = settings.customBubbleColors;

    final userBubble =
        colorFromHex(colors.userBubbleColor) ??
        ext?.bubbleUser ??
        const Color(0xFF1976D2);
    final userText =
        colorFromHex(colors.userTextColor) ?? theme.colorScheme.onSurface;
    final aiBubble =
        colorFromHex(colors.aiBubbleColor) ??
        ext?.bubbleAi ??
        const Color(0xFFF5F5F5);
    final aiText =
        colorFromHex(colors.aiTextColor) ?? theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewMessage(
          isUser: true,
          showAvatar: settings.showUserAvatar,
          showName: settings.showUserName,
          avatarColor: theme.colorScheme.primary,
          avatarText: 'U',
          name: '用户',
          time: '12:30',
          sampleText: '你好，帮我写个启动脚本',
          bubbleColor: userBubble,
          textColor: userText,
          hideBubble: settings.hideUserBubble,
          maxWidthFactor: settings.userMessageMaxWidth / 100,
        ),
        const SizedBox(height: 8),
        if (settings.messageActionMode == MessageActionMode.bubbles &&
            settings.showMicroBubbles)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _MicroBubbles(settings: settings),
          ),
        _PreviewMessage(
          isUser: false,
          showAvatar: settings.showModelAvatar,
          showName: settings.showModelName,
          avatarColor: theme.colorScheme.secondary,
          avatarText: 'AI',
          name: 'AI助手',
          time: '12:32',
          sampleText: '好的！下面是一个 bash 启动脚本，保存为 start.sh 后直接运行即可。',
          bubbleColor: aiBubble,
          textColor: aiText,
          hideBubble: settings.hideAIBubble,
          maxWidthFactor: settings.messageBubbleMaxWidth / 100,
        ),
        if (settings.messageActionMode == MessageActionMode.toolbar)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: _PreviewToolbar(
              collapsed:
                  (settings.collapsedActionIds ?? kDefaultCollapsedActionIds)
                      .toSet(),
              color: aiText.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

/// 工具栏预览：外露图标 + 末尾「⋯」（点开列出收进去的按钮）。
class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({required this.collapsed, required this.color});

  final Set<String> collapsed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inline = [
      for (final id in _kToolbarOrder)
        if (!collapsed.contains(id.name)) id,
    ];
    final hidden = [
      for (final id in _kToolbarOrder)
        if (collapsed.contains(id.name)) id,
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final id in inline)
          Icon(
            kMessageActionCatalog[id]!.icon,
            size: 15,
            color: id == MessageActionId.delete
                ? theme.colorScheme.error
                : color,
          ),
        if (hidden.isNotEmpty)
          PopupMenuButton<void>(
            tooltip: '更多',
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            itemBuilder: (_) => [
              for (final id in hidden)
                PopupMenuItem<void>(
                  enabled: false,
                  height: 36,
                  child: Row(
                    children: [
                      Icon(kMessageActionCatalog[id]!.icon, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        kMessageActionCatalog[id]!.label,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
            child: Icon(LucideIcons.ellipsis, size: 16, color: color),
          ),
      ],
    );
  }
}

/// 功能气泡模式下 AI 消息上方的小气泡（播放 / 版本）。
class _MicroBubbles extends StatelessWidget {
  const _MicroBubbles({required this.settings});

  final MessageBubbleSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(IconData? icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        if (settings.showTTSButton) ...[
          pill(LucideIcons.play, '播放'),
          const SizedBox(width: 5),
        ],
        settings.versionSwitchStyle == VersionSwitchStyle.arrows
            ? pill(null, '‹ 2/3 ›')
            : pill(LucideIcons.history, '版本 2'),
      ],
    );
  }
}

/// A single labelled width slider: icon + label on the left, the slider in the
/// middle and the `${value}%` readout on the right. Range/step mirror the
/// original (step 5).
class _WidthSlider extends StatelessWidget {
  const _WidthSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ 5,
            label: '$value%',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One color row in the 自定义气泡颜色 grid: a labelled left cell plus the
/// background and text [ColorPicker] swatches.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.icon,
    required this.label,
    required this.bubbleColor,
    required this.textColor,
    required this.onBubbleChanged,
    required this.onTextChanged,
  });

  final IconData icon;
  final String label;
  final String bubbleColor;
  final String textColor;
  final ValueChanged<String> onBubbleChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurface),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ColorPicker(value: bubbleColor, onChanged: onBubbleChanged),
          ),
        ),
        Expanded(
          child: Center(
            child: ColorPicker(value: textColor, onChanged: onTextChanged),
          ),
        ),
      ],
    );
  }
}

/// A single preview row (avatar + name/time header over the bubble), aligned to
/// the right for the user and the left for the AI.
class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.isUser,
    required this.showAvatar,
    required this.showName,
    required this.avatarColor,
    required this.avatarText,
    required this.name,
    required this.time,
    required this.sampleText,
    required this.bubbleColor,
    required this.textColor,
    required this.hideBubble,
    required this.maxWidthFactor,
  });

  final bool isUser;
  final bool showAvatar;
  final bool showName;
  final Color avatarColor;
  final String avatarText;
  final String name;
  final String time;
  final String sampleText;
  final Color bubbleColor;
  final Color textColor;
  final bool hideBubble;
  final double maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColor,
        borderRadius: BorderRadius.circular(6), // 25% of 24px
      ),
      child: Text(
        avatarText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final header = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isUser ? TextDirection.rtl : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar) avatar,
        if (showAvatar) const SizedBox(width: 8),
        Column(
          crossAxisAlignment: align,
          children: [
            if (showName)
              Text(
                name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              time,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * maxWidthFactor;
        // Fill the row so [align] can push the user bubble to the right and the
        // AI bubble to the left (mirroring the original `alignItems: flex-end` /
        // `flex-start`); without the full width the column shrink-wraps to its
        // content and every bubble hugs the left edge.
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: align,
            children: [
              if (showAvatar || showName) ...[
                header,
                const SizedBox(height: 6),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hideBubble ? Colors.transparent : bubbleColor,
                    borderRadius: BorderRadius.circular(hideBubble ? 0 : 12),
                  ),
                  child: Text(
                    sampleText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

