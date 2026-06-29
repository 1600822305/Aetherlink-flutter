import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/top_toolbar_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/top_toolbar_component_catalog.dart';

/// What a DIY-canvas drag carries. A single sealed type lets one [DragTarget]
/// handle the three drop intents: placing a single component, creating a new
/// 聚合按钮, and repositioning an existing one.
sealed class _DiyDragItem {
  const _DiyDragItem();
}

class _ComponentDrag extends _DiyDragItem {
  const _ComponentDrag(this.component);

  final TopToolbarComponent component;
}

class _NewGroupDrag extends _DiyDragItem {
  const _NewGroupDrag();
}

class _MoveGroupDrag extends _DiyDragItem {
  const _MoveGroupDrag(this.groupId);

  final String groupId;
}

/// The "顶部工具栏设置" sub-page (外观设置 → this page), a 1:1 reproduction of the
/// original `src/pages/Settings/TopToolbarDIYSettings.tsx`.
///
/// The page is fully wired to [TopToolbarSettingsController]: long-pressing a
/// card in the "可用组件" grid and dropping it onto the preview places it at a
/// free x / y position, the eye-off button removes it, 重置布局 clears every
/// position, 矫正对齐 vertically centers them and the 模型选择器显示样式 radio drives
/// [ModelSelectorDisplayStyle] — all reflected live in the layout preview.
///
/// Mirrors the original's metrics (font sizes, the elevation-2 card, the dashed
/// top preview border, paddings, the per-section tint) and renders the eight
/// components with their exact glyphs (lucide originals via
/// `lucide_icons_flutter`, the non-lucide `menuButton` / `searchButton` /
/// `condenseButton` glyphs as ported SVG assets, per ADR-0009).
///
/// Applying the layout to the real chat top bar (the original's
/// instructions.step6) is intentionally left as a seam: the configuration lives
/// in [TopToolbarSettingsController] but the live `ChatPage` top bar still uses
/// its fixed layout, so this page edits and previews the layout faithfully
/// without re-architecting the main chat screen.
class TopToolbarSettingsPage extends ConsumerStatefulWidget {
  const TopToolbarSettingsPage({super.key});

  static const String _title = '顶部工具栏 DIY 设置';

  @override
  ConsumerState<TopToolbarSettingsPage> createState() =>
      _TopToolbarSettingsPageState();
}

class _TopToolbarSettingsPageState
    extends ConsumerState<TopToolbarSettingsPage> {
  /// Keyed onto the preview's positioning box so a drop's global pointer offset
  /// can be converted to the x / y percentages the layout stores (`handleDrop`).
  final GlobalKey _previewKey = GlobalKey();

  /// The original `Toolbar minHeight: 56px !important`.
  static const double _previewHeight = 56;

  /// MUI `shape.borderRadius: 8` (`themes.ts`).
  static const double _radius = 8;

  /// MUI `subtitle1` resolves to `pxToRem(16)` scaled by the 16/14 coefficient.
  static const double _subtitle1Size = 128 / 7;

  void _onDrop(DragTargetDetails<_DiyDragItem> details) {
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final size = box.size;
    if (size.width == 0 || size.height == 0) return;
    final x = local.dx / size.width * 100;
    final y = local.dy / size.height * 100;
    final notifier = ref.read(topToolbarSettingsControllerProvider.notifier);
    switch (details.data) {
      case _ComponentDrag(:final component):
        notifier.placeComponent(component, x, y);
      case _MoveGroupDrag(:final groupId):
        notifier.moveGroup(groupId, x, y);
      case _NewGroupDrag():
        final id = notifier.addGroup(x, y);
        _openGroupEditor(id);
    }
  }

  void _openGroupEditor(String groupId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _GroupEditorSheet(groupId: groupId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(topToolbarSettingsControllerProvider);

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
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
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
        title: const Text(TopToolbarSettingsPage._title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('重置布局'),
                onPressed: () => ref
                    .read(topToolbarSettingsControllerProvider.notifier)
                    .resetLayout(),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _DiyCard(
            settings: settings,
            previewKey: _previewKey,
            previewHeight: _previewHeight,
            radius: _radius,
            subtitle1Size: _subtitle1Size,
            onDrop: _onDrop,
            onRemove: (c) => ref
                .read(topToolbarSettingsControllerProvider.notifier)
                .removeComponent(c),
            onAlign: () => ref
                .read(topToolbarSettingsControllerProvider.notifier)
                .alignLayout(),
            onModelSelectorStyle: (s) => ref
                .read(topToolbarSettingsControllerProvider.notifier)
                .setModelSelectorDisplayStyle(s),
            onEditGroup: _openGroupEditor,
          ),
          const _InstructionsCard(radius: _radius),
        ],
      ),
    );
  }
}

/// The original's `<Paper elevation={2}>` holding the preview, the component
/// panel, the align button and the model-selector radio group.
class _DiyCard extends StatelessWidget {
  const _DiyCard({
    required this.settings,
    required this.previewKey,
    required this.previewHeight,
    required this.radius,
    required this.subtitle1Size,
    required this.onDrop,
    required this.onRemove,
    required this.onAlign,
    required this.onModelSelectorStyle,
    required this.onEditGroup,
  });

  final TopToolbarSettings settings;
  final GlobalKey previewKey;
  final double previewHeight;
  final double radius;
  final double subtitle1Size;
  final ValueChanged<DragTargetDetails<_DiyDragItem>> onDrop;
  final ValueChanged<TopToolbarComponent> onRemove;
  final VoidCallback onAlign;
  final ValueChanged<ModelSelectorDisplayStyle> onModelSelectorStyle;
  final ValueChanged<String> onEditGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placed = {for (final p in settings.positions) p.component};

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview header.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  LucideIcons.wand2,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'DIY 布局预览',
                  style: TextStyle(
                    fontSize: subtitle1Size,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                const _InfoTooltip(message: '拖拽下方组件到此区域进行自由布局'),
              ],
            ),
          ),
          // Preview area: a faux toolbar with a dashed top border.
          DragTarget<_DiyDragItem>(
            onAcceptWithDetails: onDrop,
            builder: (context, candidate, rejected) {
              final dragging = candidate.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: CustomPaint(
                  foregroundPainter: _DashedTopBorderPainter(
                    color: dragging
                        ? _successColor(theme)
                        : theme.colorScheme.primary,
                  ),
                  child: SizedBox(
                    key: previewKey,
                    height: previewHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (settings.positions.isEmpty &&
                                settings.groups.isEmpty)
                              _EmptyPreviewHint(theme: theme),
                            for (final pos in settings.positions)
                              Positioned(
                                left: pos.x / 100 * w,
                                top: pos.y / 100 * h,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, -0.5),
                                  child: _PreviewComponent(
                                    component: pos.component,
                                    displayStyle:
                                        settings.modelSelectorDisplayStyle,
                                  ),
                                ),
                              ),
                            for (final group in settings.groups)
                              Positioned(
                                left: group.x / 100 * w,
                                top: group.y / 100 * h,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, -0.5),
                                  child: _GroupPreviewChip(
                                    group: group,
                                    onTap: () => onEditGroup(group.id),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          // Component panel.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '可用组件',
                      style: TextStyle(
                        fontSize: subtitle1Size,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _InfoTooltip(message: '长按组件拖拽到上方预览区域进行布局'),
                  ],
                ),
                const SizedBox(height: 16),
                _ComponentGrid(
                  placed: placed,
                  radius: radius,
                  onRemove: onRemove,
                ),
                const SizedBox(height: 16),
                Text(
                  '💡 提示：长按组件0.3秒后开始拖拽到上方预览区域。长按时卡片会变黄色提示。已放置的组件下方有小眼睛按钮，点击可隐藏。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Align button.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
              icon: const Icon(LucideIcons.settings, size: 16),
              label: const Text('矫正对齐'),
              onPressed: settings.positions.isEmpty && settings.groups.isEmpty
                  ? null
                  : onAlign,
            ),
          ),
          // Model selector display style.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '模型选择器显示样式',
                      style: TextStyle(
                        fontSize: subtitle1Size,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _InfoTooltip(message: '选择模型选择器在DIY布局中的显示样式'),
                  ],
                ),
                const SizedBox(height: 16),
                RadioGroup<ModelSelectorDisplayStyle>(
                  groupValue: settings.modelSelectorDisplayStyle,
                  onChanged: (v) {
                    if (v != null) onModelSelectorStyle(v);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModelSelectorRadio(
                        value: ModelSelectorDisplayStyle.icon,
                        label: '图标模式（只显示机器人图标）',
                        onTap: () => onModelSelectorStyle(
                          ModelSelectorDisplayStyle.icon,
                        ),
                      ),
                      _ModelSelectorRadio(
                        value: ModelSelectorDisplayStyle.text,
                        label: '文字模式（显示模型名+供应商名）',
                        onTap: () => onModelSelectorStyle(
                          ModelSelectorDisplayStyle.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '图标模式更紧凑，文字模式更直观显示当前模型。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

/// The empty-preview placeholder (`Hand` + 提示文字).
class _EmptyPreviewHint extends StatelessWidget {
  const _EmptyPreviewHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.hand,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            '拖拽下方组件到此区域',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One placed component as it renders inside the preview toolbar
/// (`renderRealToolbarComponent`).
class _PreviewComponent extends StatelessWidget {
  const _PreviewComponent({
    required this.component,
    required this.displayStyle,
  });

  final TopToolbarComponent component;
  final ModelSelectorDisplayStyle displayStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;

    if (component == TopToolbarComponent.topicName) {
      return Text(
        '示例话题',
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      );
    }

    if (component == TopToolbarComponent.modelSelector &&
        displayStyle == ModelSelectorDisplayStyle.text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.bot, size: 16, color: color),
            const SizedBox(width: 4),
            Text('GPT-4', style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      );
    }

    // Every other component is an icon button-sized glyph.
    return Padding(
      padding: const EdgeInsets.all(6),
      child: topToolbarComponentIcon(component, color: color),
    );
  }
}

/// The responsive "可用组件" grid (MUI `Grid size={{ xs: 3, sm: 2, md: 1.5 }}`):
/// 4 columns on phones, 6 on tablets, 8 on wide screens.
class _ComponentGrid extends StatelessWidget {
  const _ComponentGrid({
    required this.placed,
    required this.radius,
    required this.onRemove,
  });

  final Set<TopToolbarComponent> placed;
  final double radius;
  final ValueChanged<TopToolbarComponent> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final width = constraints.maxWidth;
        final columns = width < 600
            ? 4
            : width < 900
            ? 6
            : 8;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final component in TopToolbarComponent.values)
              SizedBox(
                width: cellWidth,
                child: _ComponentCard(
                  component: component,
                  isPlaced: placed.contains(component),
                  radius: radius,
                  onRemove: () => onRemove(component),
                ),
              ),
            SizedBox(
              width: cellWidth,
              child: _GroupCreateCard(radius: radius),
            ),
          ],
        );
      },
    );
  }
}

/// The draggable "聚合按钮" card in the 可用组件 grid. Dropping it on the preview
/// creates a fresh, empty group and opens its editor. Unlike a component card
/// it is never "placed" (a layout can hold many groups), so it has no remove
/// affordance here — removal lives in the group editor.
class _GroupCreateCard extends StatelessWidget {
  const _GroupCreateCard({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80, minHeight: 60),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Icon(
                LucideIcons.plus,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              '聚合按钮',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.6,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    return Center(
      child: LongPressDraggable<_DiyDragItem>(
        data: const _NewGroupDrag(),
        delay: const Duration(milliseconds: 300),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: const _DragBadge(
          icon: Icon(LucideIcons.plus, color: Colors.white, size: 16),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: card),
        child: card,
      ),
    );
  }
}

/// A single draggable component card plus, when placed, its eye-off remove
/// button. Long-press (0.3s) starts the drag, matching the original.
class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.component,
    required this.isPlaced,
    required this.radius,
    required this.onRemove,
  });

  final TopToolbarComponent component;
  final bool isPlaced;
  final double radius;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = _successColor(theme);
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80, minHeight: 60),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isPlaced ? success : theme.dividerColor,
            width: isPlaced ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: topToolbarComponentIcon(
                component,
                color: theme.colorScheme.primary,
                size: 14,
              ),
            ),
            Text(
              topToolbarComponentName(component),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.6,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (isPlaced)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '已放置',
                  style: TextStyle(fontSize: 8.8, color: success),
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: LongPressDraggable<_DiyDragItem>(
            data: _ComponentDrag(component),
            delay: const Duration(milliseconds: 300),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragBadge(
              icon: topToolbarComponentIcon(
                component,
                color: Colors.white,
                size: 16,
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: card),
            child: card,
          ),
        ),
        if (isPlaced)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _RemoveButton(onRemove: onRemove),
          ),
      ],
    );
  }
}

/// The 20px circular eye-off button below a placed card
/// (`handleRemoveComponent`).
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 20,
      height: 20,
      child: Material(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRemove,
          child: Icon(
            LucideIcons.eyeOff,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The floating 32px badge shown under the pointer while dragging
/// (`renderDraggedComponent`).
class _DragBadge extends StatelessWidget {
  const _DragBadge({required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    // pointerDragAnchorStrategy anchors the feedback's top-left to the pointer;
    // shift it so the badge is visually centered on the finger like the original.
    return Transform.translate(
      offset: const Offset(-16, -16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xE6197BD2), // rgba(25, 118, 210, 0.9)
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000), // rgba(0,0,0,0.3)
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}

/// One model-selector radio row (`FormControlLabel` + a small `Radio`), driven
/// by the enclosing [RadioGroup]; tapping the label selects it too.
class _ModelSelectorRadio extends StatelessWidget {
  const _ModelSelectorRadio({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final ModelSelectorDisplayStyle value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Radio<ModelSelectorDisplayStyle>(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// The usage-instructions `<Paper elevation={0}>` with its 6-step list.
class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.radius});

  final double radius;

  static const List<String> _steps = [
    '首先在「组件显示设置」中开启需要的组件',
    '长按「可用组件」中的组件并拖拽到预览区域',
    '可以将组件放置在工具栏的任意位置',
    '点击已放置组件右上角的红色关闭按钮可移除单个组件',
    '点击「重置布局」可以清除所有自定义位置',
    '设置会实时保存并应用到聊天页面',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎨 DIY 布局使用说明',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == _steps.length - 1 ? 0 : 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: bodyStyle),
                    Expanded(child: Text(_steps[i], style: bodyStyle)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small info IconButton wrapped in a tooltip (the original's tooltip-wrapped
/// `Info` `IconButton size="small"`).
class _InfoTooltip extends StatelessWidget {
  const _InfoTooltip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: message,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        icon: Icon(
          LucideIcons.info,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: () {},
      ),
    );
  }
}

/// Paints the preview's 2px dashed top border (`border-top: 2px dashed`).
class _DashedTopBorderPainter extends CustomPainter {
  const _DashedTopBorderPainter({required this.color});

  final Color color;

  static const double _strokeWidth = 2;
  static const double _dashLength = 5;
  static const double _gapLength = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    const y = _strokeWidth / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dashLength).clamp(0, size.width), y),
        paint,
      );
      x += _dashLength + _gapLength;
    }
  }

  @override
  bool shouldRepaint(_DashedTopBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// MUI `success.main`, light / dark variants.
Color _successColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF66BB6A)
    : const Color(0xFF2E7D32);

/// A placed 聚合按钮 in the preview: a labelled chip that long-press-drags to
/// reposition (carrying a [_MoveGroupDrag]) and taps to open its editor.
class _GroupPreviewChip extends StatelessWidget {
  const _GroupPreviewChip({required this.group, required this.onTap});

  final TopToolbarGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              topToolbarGroupIcon(
                group.icon,
                color: theme.colorScheme.onPrimaryContainer,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                group.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<_DiyDragItem>(
      data: _MoveGroupDrag(group.id),
      delay: const Duration(milliseconds: 300),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragBadge(
        icon: topToolbarGroupIcon(group.icon, color: Colors.white, size: 16),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: chip,
    );
  }
}

/// The bottom-sheet editor for one 聚合按钮: rename, pick a glyph, reorder /
/// remove its children, add more components, or delete the group. It reads the
/// group live from [TopToolbarSettingsController] so edits reflect instantly,
/// and closes itself if the group is removed.
class _GroupEditorSheet extends ConsumerStatefulWidget {
  const _GroupEditorSheet({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends ConsumerState<_GroupEditorSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final group = ref
        .read(topToolbarSettingsControllerProvider)
        .groups
        .where((g) => g.id == widget.groupId)
        .firstOrNull;
    _nameController = TextEditingController(text: group?.label ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(topToolbarSettingsControllerProvider);
    final notifier = ref.read(topToolbarSettingsControllerProvider.notifier);
    final group = settings.groups
        .where((g) => g.id == widget.groupId)
        .firstOrNull;
    if (group == null) return const SizedBox.shrink();

    final available = TopToolbarComponent.values
        .where((c) => !group.children.contains(c))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        // Keep clear of the keyboard (viewInsets) AND the home-indicator /
        // gesture bar (padding) so the bottom actions aren't clipped.
        16 +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '编辑聚合按钮',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  notifier.renameGroup(group.id, value),
            ),
            const SizedBox(height: 16),
            Text(
              '图标',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in TopToolbarGroupIcon.values)
                  _IconChoice(
                    icon: icon,
                    selected: group.icon == icon,
                    onTap: () => notifier.setGroupIcon(group.id, icon),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '包含功能（长按拖动排序）',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (group.children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '还没有功能，从下方添加',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: group.children.length,
                onReorderItem: (oldIndex, newIndex) =>
                    notifier.reorderGroupChildren(group.id, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final component = group.children[index];
                  return ListTile(
                    key: ValueKey(component),
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        LucideIcons.gripVertical,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Row(
                      children: [
                        topToolbarComponentIcon(
                          component,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          topToolbarComponentName(component),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      color: theme.colorScheme.error,
                      onPressed: () =>
                          notifier.removeGroupChild(group.id, component),
                    ),
                  );
                },
              ),
            if (available.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '添加功能',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final component in available)
                    ActionChip(
                      avatar: topToolbarComponentIcon(
                        component,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      label: Text(topToolbarComponentName(component)),
                      onPressed: () =>
                          notifier.addGroupChild(group.id, component),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  notifier.removeGroup(group.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('删除此聚合按钮'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable glyph in the group editor's icon picker.
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final TopToolbarGroupIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: topToolbarGroupIcon(
          icon,
          color: selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
