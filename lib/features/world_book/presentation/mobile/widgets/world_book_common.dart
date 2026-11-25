// 世界书页面通用小部件：分节标题 / 描边卡片 / 紧凑行 / 徽标 / 页面 AppBar /
// bottom-sheet 外壳。行与卡片规格与其他设置页一致（ModelSettingsCard 圆角 16
// + 轻阴影；行内边距 14/12、标题 14 号 w600、说明 12 号）。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WorldBookSectionHeader extends StatelessWidget {
  const WorldBookSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null)
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

class WorldBookOutlinedCard extends StatelessWidget {
  const WorldBookOutlinedCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // 与 ModelSettingsCard 一致
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // 透明 Material：行内 InkWell 的水波纹画在卡片背景之上。
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// 列表行左侧的 32×32 图标底块；[active] 为 false 时置灰。
class WorldBookIconTile extends StatelessWidget {
  const WorldBookIconTile({super.key, required this.icon, this.active = true});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// 名称旁的小徽标；[color] 缺省为中性灰。
class WorldBookBadge extends StatelessWidget {
  const WorldBookBadge(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: c,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 世界书页面统一的紧凑行：图标 + 标题（可带徽标）+ 单行说明 + 右侧控件。
/// [dimmed] 时标题与说明变淡（书 / 条目已关闭），右侧开关保持可点。
class WorldBookTile extends StatelessWidget {
  const WorldBookTile({
    super.key,
    required this.title,
    this.leading,
    this.titleBadges = const <Widget>[],
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.dimmed = false,
  });

  final String title;
  final Widget? leading;
  final List<Widget> titleBadges;
  final Widget? subtitle;
  final int subtitleMaxLines;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, trailing == null ? 14 : 8, 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Opacity(
                opacity: dimmed ? 0.55 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...titleBadges,
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        maxLines: subtitleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.3,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 行尾 32×32 的「⋯」菜单按钮（比默认 48 的 PopupMenuButton 紧凑）。
class WorldBookMoreMenu<T> extends StatelessWidget {
  const WorldBookMoreMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.tooltip = '更多操作',
  });

  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<T>(
        popUpAnimationStyle: AnimationStyle.noAnimation,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(
          LucideIcons.ellipsis,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (_) => items,
      ),
    );
  }
}

/// 列表底部的灰色说明文字。
class WorldBookHint extends StatelessWidget {
  const WorldBookHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 与知识库页同款的设置子页 AppBar。
PreferredSizeWidget buildWorldBookAppBar(
  BuildContext context, {
  required String title,
  required VoidCallback onBack,
  List<Widget> actions = const <Widget>[],
}) {
  final theme = Theme.of(context);
  return AppBar(
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
        onPressed: onBack,
      ),
    ),
    titleTextStyle: theme.textTheme.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    ),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    actions: [...actions, const SizedBox(width: 4)],
  );
}

/// Bottom-sheet 外壳：键盘避让 + 限高 + 标题 + 底部「取消 / 确认」。
class WorldBookSheetScaffold extends StatelessWidget {
  const WorldBookSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: children,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onConfirm,
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通用确认对话框；[destructive] 时确认按钮用 error 色。
Future<bool> confirmWorldBookAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
