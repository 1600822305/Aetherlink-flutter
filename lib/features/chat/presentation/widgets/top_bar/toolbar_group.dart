import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/top_toolbar_component_catalog.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/top_bar/toolbar_actions.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/top_bar/toolbar_buttons.dart';

/// A 聚合按钮: a single toolbar icon that pops up a sheet of its
/// [TopToolbarGroup.children]. Each row runs the same action the component
/// would inline on the bar ([componentAction]) — the group only changes
/// *where* a component lives, never *what it does*.
class GroupButton extends StatelessWidget {
  const GroupButton({super.key, required this.group});

  final TopToolbarGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ToolbarIconButton(
      icon: topToolbarGroupIcon(group.icon, color: theme.colorScheme.onSurface),
      tooltip: group.label,
      onPressed: group.children.isEmpty
          ? null
          : () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => _GroupSheet(group: group, hostContext: context),
            ),
    );
  }
}

/// The 聚合按钮 sheet: one full-width tappable row per grouped component. A tap
/// closes the sheet and runs the component's action against [hostContext] (the
/// toolbar's context — the sheet's own is gone once popped). 清空内容 keeps its
/// two-step confirm inside the sheet (arm on the first tap, auto-disarm after
/// 3s, clear and close on the second), and 话题名称 renders as an inert row.
class _GroupSheet extends ConsumerStatefulWidget {
  const _GroupSheet({required this.group, required this.hostContext});

  final TopToolbarGroup group;
  final BuildContext hostContext;

  @override
  ConsumerState<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends ConsumerState<_GroupSheet> {
  bool _clearConfirm = false;
  Timer? _clearTimer;

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  void _onClearTap() {
    final topicId = ref.read(currentTopicProvider).value?.id;
    if (topicId == null) return;
    if (_clearConfirm) {
      _clearTimer?.cancel();
      Navigator.of(context).pop();
      ref.read(topicsProvider.notifier).clearMessages(topicId);
      return;
    }
    setState(() => _clearConfirm = true);
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _clearConfirm = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.group.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            for (final component in widget.group.children)
              _row(context, theme, component),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ThemeData theme,
    TopToolbarComponent component,
  ) {
    final color = theme.colorScheme.onSurface;

    if (component == TopToolbarComponent.topicName) {
      final name = ref.watch(currentTopicProvider).value?.name;
      return ListTile(
        dense: true,
        leading: topToolbarComponentIcon(component, color: color),
        title: Text(
          name ?? topToolbarComponentName(component),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (component == TopToolbarComponent.clearButton) {
      final hasTopic = ref.watch(currentTopicProvider).value != null;
      final confirm = _clearConfirm;
      return ListTile(
        dense: true,
        enabled: hasTopic,
        leading: confirm
            ? const Icon(
                LucideIcons.alertTriangle,
                size: 20,
                color: clearConfirmColor,
              )
            : topToolbarComponentIcon(
                component,
                color: hasTopic ? color : theme.disabledColor,
              ),
        title: Text(
          confirm ? '确认清空' : topToolbarComponentName(component),
          style: confirm ? const TextStyle(color: clearConfirmColor) : null,
        ),
        onTap: hasTopic ? _onClearTap : null,
      );
    }

    final action = componentAction(
      component,
      context: widget.hostContext,
      ref: ref,
    );
    return ListTile(
      dense: true,
      enabled: action != null,
      leading: topToolbarComponentIcon(
        component,
        color: action != null ? color : theme.disabledColor,
      ),
      title: Text(topToolbarComponentName(component)),
      onTap: action == null
          ? null
          : () {
              Navigator.of(context).pop();
              action();
            },
    );
  }
}
