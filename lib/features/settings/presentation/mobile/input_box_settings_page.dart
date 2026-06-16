import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/input_box_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_button_catalog.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_composer.dart';

/// The "输入框管理设置" sub-page (外观设置 → this page), a 1:1 reproduction of the
/// original `src/pages/Settings/InputBoxSettings.tsx`.
///
/// The page is fully wired to [InputBoxSettingsController]: the 输入框风格 dropdown
/// drives [InputBoxStyle] and the drag-and-drop config drives the left / right
/// button layout, both of which the shared [InputBoxComposer] reads — so the
/// live preview here and the real chat composer reflect the configuration
/// immediately. Mirrors the original's metrics (font sizes, card radius,
/// paddings, spacing, the per-area tint/border colors) and renders the
/// configurable buttons with their exact glyphs (lucide originals via
/// `lucide_icons_flutter`, the non-lucide `tools` / `search` / `ai-debate` /
/// `quick-phrase` glyphs as ported SVG assets, per ADR-0009).
class InputBoxSettingsPage extends ConsumerStatefulWidget {
  const InputBoxSettingsPage({super.key});

  static const String _title = '输入框管理设置';

  @override
  ConsumerState<InputBoxSettingsPage> createState() =>
      _InputBoxSettingsPageState();
}

class _InputBoxSettingsPageState extends ConsumerState<InputBoxSettingsPage> {
  // The preview composer is display-only, so it gets its own throwaway
  // controller (never sent anywhere).
  final TextEditingController _previewController = TextEditingController();

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  void _onStyleChanged(InputBoxStyle style) =>
      ref.read(inputBoxSettingsControllerProvider.notifier).setStyle(style);

  /// Append [id] to [area] (or, for [_ButtonArea.available], drop it from both
  /// lists), matching the original's "move to this list" drop. The id is first
  /// removed wherever it currently sits.
  void _moveToArea(InputBoxButtonId id, _ButtonArea area) {
    final settings = ref.read(inputBoxSettingsControllerProvider);
    final left = [...settings.leftButtons]..remove(id);
    final right = [...settings.rightButtons]..remove(id);
    switch (area) {
      case _ButtonArea.left:
        left.add(id);
      case _ButtonArea.right:
        right.add(id);
      case _ButtonArea.available:
        break; // removed from both → back to the available pool
    }
    ref
        .read(inputBoxSettingsControllerProvider.notifier)
        .updateLayout(left: left, right: right);
  }

  /// Insert [id] right before [anchor] within [area] (the original's reorder /
  /// cross-list drop at a specific index). Dropping before an item in the
  /// available pool simply removes [id] (available is unordered).
  void _insertBefore(
    InputBoxButtonId id,
    _ButtonArea area,
    InputBoxButtonId anchor,
  ) {
    final settings = ref.read(inputBoxSettingsControllerProvider);
    final left = [...settings.leftButtons]..remove(id);
    final right = [...settings.rightButtons]..remove(id);
    final List<InputBoxButtonId>? target = switch (area) {
      _ButtonArea.left => left,
      _ButtonArea.right => right,
      _ButtonArea.available => null,
    };
    if (target != null) {
      final idx = target.indexOf(anchor);
      target.insert(idx < 0 ? target.length : idx, id);
    }
    ref
        .read(inputBoxSettingsControllerProvider.notifier)
        .updateLayout(left: left, right: right);
  }

  /// The original `handleToggleVisibility`: a button visible in either list is
  /// removed from both; an unused button is appended to the left list.
  void _toggleVisibility(InputBoxButtonId id) {
    final settings = ref.read(inputBoxSettingsControllerProvider);
    final inUse =
        settings.leftButtons.contains(id) || settings.rightButtons.contains(id);
    final notifier = ref.read(inputBoxSettingsControllerProvider.notifier);
    if (inUse) {
      notifier.updateLayout(
        left: settings.leftButtons.where((b) => b != id).toList(),
        right: settings.rightButtons.where((b) => b != id).toList(),
      );
    } else {
      notifier.updateLayout(
        left: [...settings.leftButtons, id],
        right: settings.rightButtons,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(inputBoxSettingsControllerProvider);

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
        // The original AppBar title: h6 (1.125rem = 18px) at weight 600.
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(InputBoxSettingsPage._title),
      ),
      body: ListView(
        // The original Scrollbar `padding: 16px` + the device safe-area inset.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _PreviewCard(
            settings: settings,
            previewController: _previewController,
            onToggleVisibility: _toggleVisibility,
            onMoveToArea: _moveToArea,
            onInsertBefore: _insertBefore,
          ),
          const SizedBox(height: 12), // original `<Divider sx={{ mb: 1.5 }} />`
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          _StyleCard(style: settings.style, onChanged: _onStyleChanged),
          const SizedBox(height: 20), // original bottom spacer
        ],
      ),
    );
  }
}

/// `CARD_STYLES.base`: `borderRadius: 2` (16px), a 1px divider border and
/// `overflow: hidden`, with no shadow (the page's Papers use `elevation={0}`).
class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [child],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card #1: the live preview, the current-config caption and the button-layout
/// drag config.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.settings,
    required this.previewController,
    required this.onToggleVisibility,
    required this.onMoveToArea,
    required this.onInsertBefore,
  });

  final InputBoxSettings settings;
  final TextEditingController previewController;
  final void Function(InputBoxButtonId) onToggleVisibility;
  final void Function(InputBoxButtonId, _ButtonArea) onMoveToArea;
  final void Function(InputBoxButtonId, _ButtonArea, InputBoxButtonId)
  onInsertBefore;

  static const String _previewTitle = '实时预览';
  static const String _previewLabel = '实时预览效果';
  static const String _currentConfig = '当前配置：';
  static const String _layoutTitle = '自定义输入框按钮布局';
  static const String _layoutDescription =
      '拖拽按钮来自定义左右布局，点击眼睛图标来显示/隐藏按钮。配置后可在上方预览中查看效果：';

  String _styleLabel(InputBoxStyle style) => switch (style) {
    InputBoxStyle.defaultStyle => '默认风格',
    InputBoxStyle.modern => '现代风格',
    InputBoxStyle.minimal => '简约风格',
  };

  String _summary() =>
      '左侧 ${settings.leftButtons.length} 个按钮，右侧 ${settings.rightButtons.length} 个按钮。'
      '按钮将按配置的左右布局显示在输入框底部。';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // subtitle1, weight 600, 0.95rem (15.2px), p1.5 pb0.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              _previewTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15.2,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8), // subtitle1 `mb: 1`
          // The preview surface (`action.hover` tint, radius 16, minHeight 100).
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 100),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Text(
                        _previewLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.8,
                          color: secondary,
                        ),
                      ),
                    ),
                    InputBoxComposer(
                      settings: settings,
                      controller: previewController,
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8), // currentConfig `mt: 1`
          // currentConfig caption, centered, 0.8rem (12.8px), p1.5 pt0.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              '$_currentConfig ${_styleLabel(settings.style)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12.8,
                color: secondary,
              ),
            ),
          ),
          // The button-layout block (`mt: 2, pt: 2, borderTop 1px`).
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // subtitle1, default (18.29px, weight 400), px1.5, mb1.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _layoutTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 128 / 7,
                      height: 1.75,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // body2 (14px) text.secondary, px1.5, mb2.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _layoutDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DraggableButtonConfig(
                  settings: settings,
                  onToggleVisibility: onToggleVisibility,
                  onMoveToArea: onMoveToArea,
                  onInsertBefore: onInsertBefore,
                ),
                const SizedBox(height: 12), // summary `mt: 1.5`
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Text(
                    _summary(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: secondary,
                    ),
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

/// Card #2: the 输入框风格 dropdown and its multi-line description.
class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.style, required this.onChanged});

  final InputBoxStyle style;
  final ValueChanged<InputBoxStyle> onChanged;

  static const String _title = '输入框风格';
  static const String _label = '输入框风格';
  static const String _description =
      '选择聊天输入框和工具栏的视觉风格：\n'
      '• 默认风格：标准圆角，适中阴影，经典外观\n'
      '• 现代风格：更圆润的边角，立体阴影，毛玻璃背景效果\n'
      '• 简约风格：尖锐边角，无阴影，清爽简洁';

  static const List<(InputBoxStyle, String)> _options = [
    (InputBoxStyle.defaultStyle, '默认风格'),
    (InputBoxStyle.modern, '现代风格'),
    (InputBoxStyle.minimal, '简约风格'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.dividerColor),
    );

    return _BaseCard(
      padding: const EdgeInsets.all(12), // Paper `p: 1.5`
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // subtitle1, weight 600, 0.95rem (15.2px), mb1.5.
          Text(
            _title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15.2,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<InputBoxStyle>(
            initialValue: style,
            isExpanded: true,
            icon: Icon(
              LucideIcons.chevronDown,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 14.4,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              labelText: _label,
              isDense: true,
              labelStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            items: [
              for (final (value, text) in _options)
                DropdownMenuItem<InputBoxStyle>(
                  value: value,
                  child: Text(text),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
          const SizedBox(height: 4), // description `mt: 0.5`
          // body2 (0.8rem = 12.8px) text.secondary, line-height 1.5.
          Text(
            _description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.8,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Which list a button currently belongs to (the drag-and-drop areas).
enum _ButtonArea { left, right, available }

/// A 1:1 port of the original `DraggableButtonConfig`: three drop areas (left /
/// right / available) with cross-area drag, in-list reordering (drop a button
/// onto another to insert before it) and an eye toggle to show/hide a button.
///
/// Built on Flutter's own [LongPressDraggable] / [DragTarget] (no extra
/// dependency); a long press starts the drag to avoid accidental moves.
class _DraggableButtonConfig extends StatelessWidget {
  const _DraggableButtonConfig({
    required this.settings,
    required this.onToggleVisibility,
    required this.onMoveToArea,
    required this.onInsertBefore,
  });

  final InputBoxSettings settings;
  final void Function(InputBoxButtonId) onToggleVisibility;
  final void Function(InputBoxButtonId, _ButtonArea) onMoveToArea;
  final void Function(InputBoxButtonId, _ButtonArea, InputBoxButtonId)
  onInsertBefore;

  // The original per-area tint + dashed-border colors.
  static const Color _leftTint = Color.fromRGBO(25, 118, 210, 0.02);
  static const Color _leftBorder = Color(0xFF90CAF9);
  static const Color _rightTint = Color.fromRGBO(76, 175, 80, 0.02);
  static const Color _rightBorder = Color(0xFFA5D6A7);
  static const Color _availTint = Color.fromRGBO(158, 158, 158, 0.02);
  static const Color _availBorder = Color(0xFFBDBDBD);

  static const String _leftTitle = '左侧按钮';
  static const String _rightTitle = '右侧按钮';
  static const String _availTitle = '可用按钮';
  static const String _dragHere = '拖拽按钮到这里';
  static const String _dragToUse = '拖拽按钮到上方左右区域来使用，或拖拽已使用的按钮回到这里来移除';
  static const String _releaseToRemove = '松开鼠标移除按钮';
  static const String _allUsed = '所有按钮都已使用，拖拽按钮到这里可以移除';

  List<InputBoxButtonId> get _available => [
    for (final id in InputBoxButtonId.values)
      if (!settings.leftButtons.contains(id) &&
          !settings.rightButtons.contains(id))
        id,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The original stacks left/right on mobile (`xs: column`) and lays them
        // out side by side from the `md` breakpoint (`md: row`).
        final isWide = constraints.maxWidth >= 900;
        final left = _AreaColumn(
          title: _leftTitle,
          count: settings.leftButtons.length,
          tint: _leftTint,
          borderColor: _leftBorder,
          minHeight: 150,
          area: _ButtonArea.left,
          buttons: settings.leftButtons,
          emptyText: _dragHere,
          isGrid: false,
          onToggleVisibility: onToggleVisibility,
          onMoveToArea: onMoveToArea,
          onInsertBefore: onInsertBefore,
        );
        final right = _AreaColumn(
          title: _rightTitle,
          count: settings.rightButtons.length,
          tint: _rightTint,
          borderColor: _rightBorder,
          minHeight: 150,
          area: _ButtonArea.right,
          buttons: settings.rightButtons,
          emptyText: _dragHere,
          isGrid: false,
          onToggleVisibility: onToggleVisibility,
          onMoveToArea: onMoveToArea,
          onInsertBefore: onInsertBefore,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 12),
                  Expanded(child: right),
                ],
              )
            else ...[
              left,
              const SizedBox(height: 12),
              right,
            ],
            const SizedBox(height: 12), // available area `mt: 1.5`
            _AvailableArea(
              title: _availTitle,
              subtitle: _dragToUse,
              tint: _availTint,
              borderColor: _availBorder,
              buttons: _available,
              allUsedText: _allUsed,
              releaseText: _releaseToRemove,
              onToggleVisibility: onToggleVisibility,
              onMoveToArea: onMoveToArea,
            ),
          ],
        );
      },
    );
  }
}

/// A left / right drop area: a titled, dashed, tinted column of button items.
class _AreaColumn extends StatelessWidget {
  const _AreaColumn({
    required this.title,
    required this.count,
    required this.tint,
    required this.borderColor,
    required this.minHeight,
    required this.area,
    required this.buttons,
    required this.emptyText,
    required this.isGrid,
    required this.onToggleVisibility,
    required this.onMoveToArea,
    required this.onInsertBefore,
  });

  final String title;
  final int count;
  final Color tint;
  final Color borderColor;
  final double minHeight;
  final _ButtonArea area;
  final List<InputBoxButtonId> buttons;
  final String emptyText;
  final bool isGrid;
  final void Function(InputBoxButtonId) onToggleVisibility;
  final void Function(InputBoxButtonId, _ButtonArea) onMoveToArea;
  final void Function(InputBoxButtonId, _ButtonArea, InputBoxButtonId)
  onInsertBefore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title (subtitle1 weight600 0.9rem) + count caption, `mb: 0.5`.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 14.4,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8), // count caption `ml: 1`
              Text(
                '($count个)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DragTarget<InputBoxButtonId>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (d) => onMoveToArea(d.data, area),
          builder: (context, candidate, rejected) {
            return _DashedContainer(
              borderColor: borderColor,
              radius: 8,
              fillColor: candidate.isNotEmpty
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : tint,
              padding: const EdgeInsets.all(6), // Paper `p: 0.75`
              constraints: BoxConstraints(minHeight: minHeight),
              child: buttons.isEmpty
                  ? _Placeholder(text: emptyText)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final id in buttons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _DraggableButton(
                              id: id,
                              area: area,
                              visible: true,
                              onToggleVisibility: onToggleVisibility,
                              onInsertBefore: onInsertBefore,
                            ),
                          ),
                      ],
                    ),
            );
          },
        ),
      ],
    );
  }
}

/// The available-buttons drop area: a titled, dashed, tinted responsive grid of
/// hidden (greyscaled) button items; dropping a used button here removes it.
class _AvailableArea extends StatelessWidget {
  const _AvailableArea({
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.borderColor,
    required this.buttons,
    required this.allUsedText,
    required this.releaseText,
    required this.onToggleVisibility,
    required this.onMoveToArea,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final Color borderColor;
  final List<InputBoxButtonId> buttons;
  final String allUsedText;
  final String releaseText;
  final void Function(InputBoxButtonId) onToggleVisibility;
  final void Function(InputBoxButtonId, _ButtonArea) onMoveToArea;

  int _columns(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '$title (${buttons.length}个)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14.4,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DragTarget<InputBoxButtonId>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (d) =>
              onMoveToArea(d.data, _ButtonArea.available),
          builder: (context, candidate, rejected) {
            final dragging = candidate.isNotEmpty;
            return _DashedContainer(
              borderColor: borderColor,
              radius: 8,
              fillColor: dragging
                  ? const Color.fromRGBO(158, 158, 158, 0.1)
                  : tint,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minHeight: 80),
              child: buttons.isEmpty
                  ? _Placeholder(text: dragging ? releaseText : allUsedText)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 6.0;
                        final cols = _columns(constraints.maxWidth);
                        final itemWidth =
                            (constraints.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final id in buttons)
                              SizedBox(
                                width: itemWidth,
                                child: _DraggableButton(
                                  id: id,
                                  area: _ButtonArea.available,
                                  visible: false,
                                  onToggleVisibility: onToggleVisibility,
                                  onInsertBefore: null,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }
}

/// One configurable button: a draggable list item (drag handle + glyph + label
/// / description + eye toggle) that is itself a drop target so a button dropped
/// onto it is inserted before it (the original's reorder).
class _DraggableButton extends StatelessWidget {
  const _DraggableButton({
    required this.id,
    required this.area,
    required this.visible,
    required this.onToggleVisibility,
    required this.onInsertBefore,
  });

  final InputBoxButtonId id;
  final _ButtonArea area;
  final bool visible;
  final void Function(InputBoxButtonId) onToggleVisibility;
  final void Function(InputBoxButtonId, _ButtonArea, InputBoxButtonId)?
  onInsertBefore;

  static const double _feedbackWidth = 260;

  @override
  Widget build(BuildContext context) {
    final item = _ButtonItem(
      id: id,
      visible: visible,
      onToggleVisibility: onToggleVisibility,
    );

    // Long-press (not an immediate pan) starts the drag, so a tap or a scroll
    // over the tile no longer accidentally moves/removes a button.
    final draggable = LongPressDraggable<InputBoxButtonId>(
      data: id,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: Transform.rotate(
        angle: 2 * math.pi / 180, // the original `transform: rotate(2deg)`
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: _feedbackWidth,
            child: _ButtonItem(
              id: id,
              visible: visible,
              dragging: true,
              onToggleVisibility: onToggleVisibility,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: item),
      child: item,
    );

    final insertBefore = onInsertBefore;
    if (insertBefore == null) return draggable;

    // A drop onto this item inserts the dragged button before it.
    return DragTarget<InputBoxButtonId>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onAcceptWithDetails: (d) => insertBefore(d.data, area, id),
      builder: (context, candidate, rejected) => draggable,
    );
  }
}

/// The visual of a button item (`renderButtonItem`): a grip handle, the glyph,
/// the label + description and the eye toggle. Hidden buttons are greyscaled and
/// dashed-bordered; visible buttons are solid-bordered.
class _ButtonItem extends StatelessWidget {
  const _ButtonItem({
    required this.id,
    required this.visible,
    required this.onToggleVisibility,
    this.dragging = false,
  });

  final InputBoxButtonId id;
  final bool visible;
  final bool dragging;
  final void Function(InputBoxButtonId) onToggleVisibility;

  // Luminance weights for the original's `filter: grayscale(100%)`.
  static const List<double> _greyscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = inputBoxButtonInfo(id);
    final glyphColor = info.color ?? theme.colorScheme.onSurface;
    final disabled = theme.disabledColor;

    final content = Padding(
      // ListItem `py: 0.5, px: 1.5`.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Drag handle (`GripVertical`, ListItemIcon minWidth 36).
          SizedBox(
            width: 36,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                LucideIcons.gripVertical,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          // The button glyph (`size 18`, brand color).
          SizedBox(
            width: 36,
            child: Align(
              alignment: Alignment.centerLeft,
              child: inputBoxListIcon(id, color: glyphColor, size: 18),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14.4,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2), // secondary `mt: 0.25`
                Text(
                  info.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Eye toggle (`Eye` visible / `EyeOff` hidden), `ml: 1`.
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: Icon(
                visible ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: visible ? theme.colorScheme.primary : disabled,
              ),
              tooltip: visible ? '隐藏按钮' : '显示按钮',
              onPressed: () => onToggleVisibility(id),
            ),
          ),
        ],
      ),
    );

    // Visible items get a solid border; hidden items a dashed one + greyscale.
    final Widget bordered = visible
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: dragging
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
              ),
            ),
            child: content,
          )
        : _DashedContainer(
            borderColor: dragging ? theme.colorScheme.primary : disabled,
            radius: 8,
            fillColor: theme.colorScheme.surface,
            padding: EdgeInsets.zero,
            child: content,
          );

    if (visible) return bordered;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_greyscale),
      child: bordered,
    );
  }
}

/// An empty-area placeholder (`body2`, italic, 0.8rem, centered, `py: 3`).
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 12.8,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A rounded box with a dashed border (Flutter has no native dashed border), for
/// the drop areas and the hidden button items (the original's `border: 1px
/// dashed`).
class _DashedContainer extends StatelessWidget {
  const _DashedContainer({
    required this.child,
    required this.borderColor,
    required this.radius,
    required this.fillColor,
    required this.padding,
    this.constraints,
  });

  final Widget child;
  final Color borderColor;
  final double radius;
  final Color fillColor;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: borderColor,
        radius: radius,
      ),
      child: Container(
        constraints: constraints,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _strokeWidth = 1;
  static const double _dashLength = 4;
  static const double _gapLength = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(_strokeWidth / 2);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
