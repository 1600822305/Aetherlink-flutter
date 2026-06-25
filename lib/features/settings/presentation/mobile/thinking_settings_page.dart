import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/thinking_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/shared/domain/thinking_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/thinking_styled_view.dart';
import 'package:aetherlink_flutter/shared/widgets/thinking_timeline_view.dart';

/// The "思考过程设置" sub-page (外观设置 → this page), a port of the original
/// `src/pages/Settings/ThinkingProcessSettings.tsx`.
///
/// Mirrors the original's two cards — 思考过程显示 (style select + 自动折叠 +
/// 工具内联 + the per-style instructions) and 实时预览 (hidden when the style is
/// `hidden`) — and persists every option through [ThinkingSettingsController].
/// The display style + 自动折叠 re-render the chat thinking block live; the
/// 工具内联 toggle is saved only (Flutter has no thinking-phase tool grouping
/// yet) and carries an inline "即将支持" note instead of faking the behaviour.
class ThinkingSettingsPage extends ConsumerWidget {
  const ThinkingSettingsPage({super.key});

  static const String _title = '思考过程设置';

  static const Color _brandHue = Color(0xFF9333EA); // 原版脑/眼图标紫色

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(thinkingSettingsControllerProvider);
    final controller = ref.read(thinkingSettingsControllerProvider.notifier);

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
        title: const Text(_title),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _DisplayCard(settings: settings, controller: controller),
          if (settings.displayStyle != ThinkingDisplayStyle.hidden)
            _PreviewCard(settings: settings),
        ],
      ),
    );
  }
}

/// 思考过程显示 card: the style select, the two switches and the per-style
/// instructions, all under a brain-tinted header.
class _DisplayCard extends StatelessWidget {
  const _DisplayCard({required this.settings, required this.controller});

  final ThinkingSettings settings;
  final ThinkingSettingsController controller;

  static const Map<ThinkingDisplayStyle, String> _styleLabels = {
    ThinkingDisplayStyle.timeline: '时间线模式（思考+工具步骤）',
    ThinkingDisplayStyle.compact: '紧凑模式（可折叠）',
    ThinkingDisplayStyle.full: '完整模式（始终展开）',
    ThinkingDisplayStyle.minimal: '极简模式（小图标）',
    ThinkingDisplayStyle.bubble: '气泡模式（聊天气泡）',
    ThinkingDisplayStyle.card: '卡片模式（突出显示）',
    ThinkingDisplayStyle.hidden: '隐藏（不显示思考过程）',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.brain,
            hue: ThinkingSettingsPage._brandHue,
            title: '思考过程显示',
            tooltip: '配置AI思考过程的显示方式和行为',
            description: '自定义AI思考过程的显示方式和自动折叠行为',
          ),
          const _CardDivider(),
          _Select<ThinkingDisplayStyle>(
            label: '显示样式',
            value: settings.displayStyle,
            items: _styleLabels,
            onChanged: controller.setDisplayStyle,
          ),
          const SizedBox(height: 16),
          _DescribedSwitchRow(
            title: '思考完成后自动折叠',
            description: '开启后，思考完成时思考块默认折叠，点击可展开查看。',
            value: settings.thoughtAutoCollapse,
            onChanged: controller.setThoughtAutoCollapse,
          ),
          const _CardDivider(),
          _DescribedSwitchRow(
            title: '思考过程内显示工具调用',
            description: '将思考阶段发起的工具调用以简化样式内嵌进思考块；关闭后工具调用始终独立显示在消息下方。',
            value: settings.thinkingToolInline,
            onChanged: controller.setThinkingToolInline,
          ),
          const _CardDivider(),
          Text(
            '设置AI助手思考过程的显示方式：\n'
            '• 时间线模式：思考与工具调用交替排列，竖线连接因果链（推荐）\n'
            '• 紧凑模式：标准卡片样式，可折叠展开\n'
            '• 完整模式：始终展开显示全部内容\n'
            '• 极简模式：只显示小图标，点击查看内容\n'
            '• 气泡模式：类似聊天气泡的圆润设计\n'
            '• 卡片模式：突出的渐变卡片设计\n'
            '• 隐藏：完全不显示思考过程',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sample tool blocks for the timeline preview.
final List<ToolBlock> _sampleToolBlocks = [
  ToolBlock(
    id: 'preview-tool-1',
    messageId: 'preview-msg',
    status: MessageBlockStatus.success,
    createdAt: DateTime.now(),
    toolId: 'search_web',
    toolName: 'search_web',
    arguments: const {'query': '如何提高工作效率'},
    content: '{"results": [{"title": "提高效率的10个方法", "url": "https://example.com"}]}',
  ),
  ToolBlock(
    id: 'preview-tool-2',
    messageId: 'preview-msg',
    status: MessageBlockStatus.success,
    createdAt: DateTime.now(),
    toolId: 'read_url',
    toolName: 'read_url',
    arguments: const {'url': 'https://example.com/article'},
    content: '文章内容：番茄工作法是一种有效的时间管理方法...',
  ),
];

/// 实时预览 card: renders a sample [ThinkingStyledView] that reflects the chosen
/// style + 自动折叠 live (mirrors the original `previewThinkingBlock`).
class _PreviewCard extends StatefulWidget {
  const _PreviewCard({required this.settings});

  final ThinkingSettings settings;

  static const String sample =
      '用户询问了关于"如何提高工作效率"的问题。我需要从多个角度来分析这个问题：\n\n'
      '首先，我应该考虑工作效率的定义。工作效率通常指在单位时间内完成的工作量和质量。'
      '提高工作效率可以从以下几个方面入手：\n\n'
      '1. 时间管理\n'
      '- 使用番茄工作法，将工作分解为25分钟的专注时段\n'
      '- 制定优先级清单，先处理重要且紧急的任务\n'
      '- 避免多任务处理，专注于一件事情\n\n'
      '2. 工作环境优化\n'
      '- 保持工作区域整洁有序\n'
      '- 减少干扰因素，如关闭不必要的通知\n\n'
      '我觉得这个回答涵盖了工作效率的主要方面，既实用又全面。';

  @override
  State<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<_PreviewCard> {
  late bool _expanded;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.settings.thoughtAutoCollapse;
  }

  @override
  void didUpdateWidget(_PreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed the preview's expanded state when 自动折叠 changes.
    if (oldWidget.settings.thoughtAutoCollapse !=
        widget.settings.thoughtAutoCollapse) {
      _expanded = !widget.settings.thoughtAutoCollapse;
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _PreviewCard.sample));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;
    final styleLabel = _DisplayCard._styleLabels[settings.displayStyle] ?? '';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.eye,
            hue: ThinkingSettingsPage._brandHue,
            title: '实时预览',
            tooltip: '预览当前选择的思考过程显示样式',
            description: '实时查看当前设置下的思考过程显示效果',
          ),
          const _CardDivider(),
          Text(
            '当前样式：$styleLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: settings.displayStyle == ThinkingDisplayStyle.timeline
                ? ThinkingTimelineView(
                    thinkingContent: _PreviewCard.sample,
                    thinkingSeconds: 3.5,
                    isThinking: false,
                    thoughtAutoCollapse: settings.thoughtAutoCollapse,
                    inlineToolBlocks: _sampleToolBlocks,
                    markdownBuilder: (context, content, style) => GptMarkdown(
                      content,
                      style: style ?? theme.textTheme.bodyMedium,
                    ),
                  )
                : ThinkingStyledView(
                    style: settings.displayStyle,
                    content: _PreviewCard.sample,
                    isThinking: false,
                    seconds: 3.5,
                    expanded: _expanded,
                    copied: _copied,
                    onToggleExpanded: () =>
                        setState(() => _expanded = !_expanded),
                    onCopy: _copy,
                    markdownBuilder: (context, content, style) => GptMarkdown(
                      content,
                      style: style ?? theme.textTheme.bodyMedium,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card scaffolding (mirrors `message_bubble_settings_page.dart`)
// ---------------------------------------------------------------------------

/// A 16px-gap, 20px-padded, 24px-radius card with a 1px divider border.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: Theme.of(context).dividerColor),
    );
  }
}

/// A card header: the tinted icon avatar plus the title (with optional Info
/// tooltip) over an optional description.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.hue,
    required this.title,
    this.tooltip,
    this.description,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String? tooltip;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 20, color: hue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
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

/// A "saved-only" banner explaining a setting is not wired to the chat view yet.
class _PendingNote extends StatelessWidget {
  const _PendingNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hue = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: hue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: hue),
            ),
          ),
        ],
      ),
    );
  }
}

/// A switch row with a title and a muted sub-description.
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
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(LucideIcons.chevronDown, size: 18),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
      ),
      items: [
        for (final entry in items.entries)
          DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
