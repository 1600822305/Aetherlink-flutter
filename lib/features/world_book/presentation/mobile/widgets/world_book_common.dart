// 世界书页面通用小部件：分节标题 / 描边卡片 / 页面 AppBar / bottom-sheet 外壳。
// 视觉与知识库页（knowledge_common.dart）保持一致。

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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
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
