import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/settings/application/message_bubble_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';
import 'package:aetherlink_flutter/shared/widgets/color_picker.dart';

/// The "信息气泡管理" sub-page (外观设置 → this page), a port of the original
/// `src/pages/Settings/MessageBubbleSettings.tsx`.
///
/// Mirrors the original's five icon-tinted cards — 气泡功能设置 / 消息气泡宽度设置
/// / 头像和名称显示 / 隐藏气泡 / 自定义气泡颜色 (with a live preview) — and persists
/// every option through [MessageBubbleSettingsController]. The width / avatar /
/// hide / color settings re-render the chat bubbles live; the action-mode group
/// (operation mode, micro bubbles, TTS, version switch) is saved only — Flutter
/// has no message-action toolbar yet — and carries an inline "即将支持" note
/// instead of fake buttons.
///
/// The five cards are organised into a top tab strip (styled like 辅助模型设置页 —
/// a segmented pill TabBar): 功能 (气泡功能设置), 外观 (宽度 / 头像和名称 /
/// 隐藏气泡) and 颜色 (自定义气泡颜色 + 预览). Tab content swaps instantly via an
/// [IndexedStack] and a >60px horizontal swipe jumps to the adjacent tab.
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
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  )..addListener(_onTabChanged);

  // Drive the shown tab straight off the controller via an [IndexedStack] so
  // content swaps the moment a tab is tapped or swiped (the indicator still
  // slides), mirroring the MCP page.
  int _index = 0;

  // Horizontal swipe accumulator: a >60px drag jumps to the adjacent tab.
  double _swipeDx = 0;

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  void _onSwipeEnd() {
    if (_swipeDx.abs() <= 60) return;
    final next = (_tabController.index + (_swipeDx < 0 ? 1 : -1)).clamp(0, 2);
    if (next != _tabController.index) _tabController.animateTo(next);
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
      ),
      body: Column(
        children: [
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
                      _FunctionCard(settings: settings, controller: controller),
                    ],
                  ),
                  _TabList(
                    children: [
                      _WidthCard(settings: settings, controller: controller),
                      _AvatarCard(settings: settings, controller: controller),
                      _HideBubbleCard(
                        settings: settings,
                        controller: controller,
                      ),
                    ],
                  ),
                  _TabList(
                    children: [
                      _ColorsCard(settings: settings, controller: controller),
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

/// The scrollable body of a single tab: the cards, with the page's standard
/// 16px padding (plus the bottom safe-area inset).
class _TabList extends StatelessWidget {
  const _TabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }
}

/// The tab strip below the app bar, styled like 辅助模型设置页 (`auxiliary_model_
/// settings_page`'s `_SegmentedTabBar`): a rounded bordered track holding
/// scrollable pill tabs (icon + label) with a tinted rounded indicator.
class _TabBarHeader extends StatelessWidget {
  const _TabBarHeader({required this.controller});

  final TabController controller;

  static const List<(IconData, String)> _tabs = [
    (LucideIcons.sliders, '功能'),
    (LucideIcons.layout, '外观'),
    (LucideIcons.palette, '颜色'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            for (final (icon, label) in _tabs)
              Tab(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15),
                    const SizedBox(width: 5),
                    Text(label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 气泡功能设置
// ---------------------------------------------------------------------------

/// 气泡功能设置: the operation-mode select plus (in bubbles mode) the micro
/// bubbles / TTS switches and the version-switch select. None of these drive
/// the chat view yet, so an inline note marks them saved-only (即将支持).
class _FunctionCard extends StatelessWidget {
  const _FunctionCard({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  static const Map<MessageActionMode, String> _modes = {
    MessageActionMode.bubbles: '功能气泡模式',
    MessageActionMode.toolbar: '底部工具栏模式（默认）',
  };
  static const Map<VersionSwitchStyle, String> _versionStyles = {
    VersionSwitchStyle.popup: '弹出列表（默认）',
    VersionSwitchStyle.arrows: '箭头式切换 < 2 >',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isBubbles = settings.messageActionMode == MessageActionMode.bubbles;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: LucideIcons.sliders,
            hue: primary,
            title: '气泡功能设置',
            tooltip: '设置信息气泡的功能和显示方式',
          ),
          const SizedBox(height: 12),
          _Select<MessageActionMode>(
            label: '消息操作显示模式',
            value: settings.messageActionMode,
            items: _modes,
            onChanged: controller.setMessageActionMode,
          ),
          if (isBubbles) ...[
            const _CardDivider(),
            _SubSwitchRow(
              icon: LucideIcons.sliders,
              hue: const Color(0xFF6366F1), // indigo
              title: '显示功能气泡',
              description: '在消息气泡上方显示播放和版本切换的小功能气泡',
              value: settings.showMicroBubbles,
              onChanged: controller.setShowMicroBubbles,
            ),
            if (settings.showMicroBubbles) ...[
              const _CardDivider(),
              _SubSwitchRow(
                icon: LucideIcons.volume2,
                hue: const Color(0xFF10B981), // emerald
                title: '显示播放按钮',
                description: '在AI消息气泡上显示语音播放按钮，可将回复内容转为语音',
                value: settings.showTTSButton,
                onChanged: controller.setShowTTSButton,
              ),
              const _CardDivider(),
              _Select<VersionSwitchStyle>(
                label: '版本切换样式',
                value: settings.versionSwitchStyle,
                items: _versionStyles,
                onChanged: controller.setVersionSwitchStyle,
              ),
              const SizedBox(height: 8),
              Text(
                '设置版本历史的显示和切换方式：弹出列表点击后弹出所有版本；箭头式用左右箭头在版本间切换。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 消息气泡宽度设置
// ---------------------------------------------------------------------------

/// 消息气泡宽度设置: the AI-max / user-max / min width sliders (all in %).
class _WidthCard extends StatelessWidget {
  const _WidthCard({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.maximize2,
            hue: Color(0xFF10B981), // emerald
            title: '消息气泡宽度设置',
            tooltip: '自定义聊天界面中消息气泡的宽度范围，适配不同设备屏幕',
          ),
          const SizedBox(height: 12),
          _WidthSlider(
            icon: LucideIcons.bot,
            label: 'AI消息最大宽度',
            value: settings.messageBubbleMaxWidth,
            min: 50,
            max: 100,
            onChanged: controller.setMessageBubbleMaxWidth,
          ),
          _WidthSlider(
            icon: LucideIcons.user,
            label: '用户消息最大宽度',
            value: settings.userMessageMaxWidth,
            min: 50,
            max: 100,
            onChanged: controller.setUserMessageMaxWidth,
          ),
          _WidthSlider(
            icon: LucideIcons.minimize2,
            label: '消息最小宽度',
            value: settings.messageBubbleMinWidth,
            min: 10,
            max: 90,
            onChanged: controller.setMessageBubbleMinWidth,
          ),
        ],
      ),
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

// ---------------------------------------------------------------------------
// 头像和名称显示
// ---------------------------------------------------------------------------

/// 头像和名称显示: the four show-avatar / show-name switches.
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.user,
            hue: Color(0xFFF59E0B), // amber
            title: '头像和名称显示',
            tooltip: '自定义聊天界面中用户和模型的头像及名称显示',
          ),
          const _CardDivider(),
          _PlainSwitchRow(
            title: '显示用户头像',
            value: settings.showUserAvatar,
            onChanged: controller.setShowUserAvatar,
          ),
          const SizedBox(height: 12),
          _PlainSwitchRow(
            title: '显示用户名称',
            value: settings.showUserName,
            onChanged: controller.setShowUserName,
          ),
          const SizedBox(height: 12),
          _PlainSwitchRow(
            title: '显示模型头像',
            value: settings.showModelAvatar,
            onChanged: controller.setShowModelAvatar,
          ),
          const SizedBox(height: 12),
          _PlainSwitchRow(
            title: '显示模型名称',
            value: settings.showModelName,
            onChanged: controller.setShowModelName,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 隐藏气泡
// ---------------------------------------------------------------------------

/// 隐藏气泡: hide the user / AI bubble background (content stays visible).
class _HideBubbleCard extends StatelessWidget {
  const _HideBubbleCard({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.eyeOff,
            hue: Color(0xFFEF4444), // red
            title: '隐藏气泡',
            tooltip: '隐藏消息气泡的背景，只显示内容',
          ),
          const _CardDivider(),
          _DescribedSwitchRow(
            title: '隐藏用户气泡',
            description: '隐藏用户消息的气泡背景，只显示消息内容',
            value: settings.hideUserBubble,
            onChanged: controller.setHideUserBubble,
          ),
          const SizedBox(height: 12),
          _DescribedSwitchRow(
            title: '隐藏AI气泡',
            description: '隐藏AI回复的气泡背景，只显示消息内容',
            value: settings.hideAIBubble,
            onChanged: controller.setHideAIBubble,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 自定义气泡颜色
// ---------------------------------------------------------------------------

/// 自定义气泡颜色: the user / AI background & text color pickers, a reset button
/// and the live [_MessageBubblePreview].
class _ColorsCard extends StatelessWidget {
  const _ColorsCard({required this.settings, required this.controller});

  final MessageBubbleSettings settings;
  final MessageBubbleSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = settings.customBubbleColors;

    void update(CustomBubbleColors next) =>
        controller.setCustomBubbleColors(next);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _CardHeader(
                  icon: LucideIcons.palette,
                  hue: Color(0xFFEC4899), // pink
                  title: '自定义气泡颜色',
                  tooltip: '自定义用户和AI消息气泡的背景色和字体颜色',
                ),
              ),
              const SizedBox(width: 12),
              ModelTonalButton(
                label: '重置默认',
                icon: LucideIcons.rotateCcw,
                onPressed: controller.resetCustomBubbleColors,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Header row: 空 / 背景色 / 字体色.
          Row(
            children: [
              const SizedBox(width: 120),
              Expanded(
                child: Text(
                  '背景色',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '字体色',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ColorRow(
            icon: LucideIcons.user,
            label: '用户消息',
            // The original placeholder defaults when a slot is empty.
            bubbleColor: colors.userBubbleColor.isEmpty
                ? '#1976d2'
                : colors.userBubbleColor,
            textColor: colors.userTextColor.isEmpty
                ? '#ffffff'
                : colors.userTextColor,
            onBubbleChanged: (c) => update(colors.copyWith(userBubbleColor: c)),
            onTextChanged: (c) => update(colors.copyWith(userTextColor: c)),
          ),
          const SizedBox(height: 12),
          _ColorRow(
            icon: LucideIcons.bot,
            label: 'AI回复',
            bubbleColor: colors.aiBubbleColor.isEmpty
                ? '#f5f5f5'
                : colors.aiBubbleColor,
            textColor: colors.aiTextColor.isEmpty
                ? '#333333'
                : colors.aiTextColor,
            onBubbleChanged: (c) => update(colors.copyWith(aiBubbleColor: c)),
            onTextChanged: (c) => update(colors.copyWith(aiTextColor: c)),
          ),
          const SizedBox(height: 12),
          Text(
            '提示：字体颜色同时控制气泡内文字和工具栏按钮的颜色。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _MessageBubblePreview(settings: settings),
        ],
      ),
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

// ---------------------------------------------------------------------------
// 实时预览
// ---------------------------------------------------------------------------

/// A live preview of a user + AI bubble, a port of `MessageBubblePreview.tsx`.
/// Reflects the custom colors (falling back to the theme bubble tokens), the
/// widths, the avatar/name toggles and the hide-bubble toggles.
class _MessageBubblePreview extends StatelessWidget {
  const _MessageBubblePreview({required this.settings});

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实时预览',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _PreviewMessage(
            isUser: true,
            showAvatar: settings.showUserAvatar,
            showName: settings.showUserName,
            avatarColor: theme.colorScheme.primary,
            avatarText: 'U',
            name: '用户',
            time: '12:30',
            sampleText: '你好！有什么可以帮助你的吗？',
            bubbleColor: userBubble,
            textColor: userText,
            hideBubble: settings.hideUserBubble,
            maxWidthFactor: settings.userMessageMaxWidth / 100,
          ),
          const SizedBox(height: 16),
          _PreviewMessage(
            isUser: false,
            showAvatar: settings.showModelAvatar,
            showName: settings.showModelName,
            avatarColor: theme.colorScheme.secondary,
            avatarText: 'AI',
            name: 'AI助手',
            time: '12:32',
            sampleText: '我是AI助手，很高兴为您服务！可以帮您解答问题、提供信息和协助完成各种任务。',
            bubbleColor: aiBubble,
            textColor: aiText,
            hideBubble: settings.hideAIBubble,
            maxWidthFactor: settings.messageBubbleMaxWidth / 100,
          ),
        ],
      ),
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

// ---------------------------------------------------------------------------
// Shared card scaffolding (mirrors `chat_interface_settings_page.dart`)
// ---------------------------------------------------------------------------

/// `MessageBubbleSettings.tsx` `cardStyle`, tightened for the tabbed layout: a
/// 12px-gap, 14px-padded, 18px-radius card with a 1px divider border, the paper
/// surface and no shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

/// A `my:2` (16px vertical) hairline divider, the original card section break.
class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: Theme.of(context).dividerColor),
    );
  }
}

/// A card header: the tinted icon avatar plus the title (with optional Info
/// tooltip holding the full description).
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.hue,
    required this.title,
    this.tooltip,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: hue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Icon(
                    LucideIcons.info,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A sub-setting row inside the function card: tinted icon + title/description
/// on the left, a [CustomSwitch] on the right.
class _SubSwitchRow extends StatelessWidget {
  const _SubSwitchRow({
    required this.icon,
    required this.hue,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: hue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CustomSwitch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// A plain switch row (`body2` label + switch), the avatar card's row style.
class _PlainSwitchRow extends StatelessWidget {
  const _PlainSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A switch row with a title and a muted sub-description, the hide-bubble row.
class _DescribedSwitchRow extends StatelessWidget {
  const _DescribedSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CustomSwitch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// A labelled outlined dropdown (the original MUI `Select size="small"`).
class _Select<T> extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<T>(
      label: label,
      value: value,
      borderRadius: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      options: [
        for (final entry in items.entries)
          AppSelectOption<T>(value: entry.key, label: entry.value),
      ],
      onChanged: onChanged,
    );
  }
}
