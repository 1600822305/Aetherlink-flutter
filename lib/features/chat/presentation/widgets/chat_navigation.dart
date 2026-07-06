import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// A navigation command dispatched by [ChatNavigationOverlay] and executed by
/// the message list state (which owns the scroll + observer controllers).
enum ChatNavigationAction { top, prevMessage, nextMessage, bottom }

/// Bridges the floating navigation panel to the message list: the panel
/// dispatches a [ChatNavigationAction]; `_MessageListViewState` listens,
/// performs the scroll and clears it (same pattern as the mini-map's
/// `scrollToMessageIdProvider`).
class ChatNavigationRequestNotifier extends Notifier<ChatNavigationAction?> {
  @override
  ChatNavigationAction? build() => null;
  void dispatch(ChatNavigationAction action) => state = action;
  void clear() => state = null;
}

final chatNavigationRequestProvider =
    NotifierProvider<ChatNavigationRequestNotifier, ChatNavigationAction?>(
      ChatNavigationRequestNotifier.new,
    );

/// 对话导航 (设置 tab 常规设置 → [SidebarSettings.messageNavigation])：the port
/// of the web `ChatNavigation.tsx`, adapted for mobile.
///
/// When set to 上下按钮, a pulsing indicator sits on the right edge at the
/// vertical center of the message area; tapping it (or swiping it left)
/// reveals a floating vertical panel with 回到顶部 / 上一条消息 / 下一条消息 /
/// 回到底部 buttons. The panel auto-hides after 2.5s of inactivity, like the
/// web original's hide timer. Renders nothing when set to 不显示.
class ChatNavigationOverlay extends ConsumerStatefulWidget {
  const ChatNavigationOverlay({super.key});

  @override
  ConsumerState<ChatNavigationOverlay> createState() =>
      _ChatNavigationOverlayState();
}

class _ChatNavigationOverlayState extends ConsumerState<ChatNavigationOverlay>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  Timer? _hideTimer;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _show() {
    Haptics.instance.onNavigation();
    setState(() => _visible = true);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _dispatch(ChatNavigationAction action) {
    Haptics.instance.onNavigation();
    _resetHideTimer();
    ref.read(chatNavigationRequestProvider.notifier).dispatch(action);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      sidebarSettingsControllerProvider.select(
        (s) => s.messageNavigation == MessageNavigation.buttons,
      ),
    );
    if (!enabled) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: _visible
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _NavigationPanel(onAction: _dispatch),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _show,
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -100) _show();
              },
              // A generous invisible hit area around the slim indicator, so
              // the tap / left-swipe reveal is easy to trigger.
              child: SizedBox(
                width: 28,
                height: 140,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.3,
                      end: 0.7,
                    ).animate(_pulse),
                    child: Container(
                      width: 5,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// The floating vertical button column: 回到顶部 / 上一条 / 下一条 / 回到底部.
class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({required this.onAction});

  final ValueChanged<ChatNavigationAction> onAction;

  static const List<(ChatNavigationAction, IconData, String)> _buttons = [
    (ChatNavigationAction.top, LucideIcons.arrowUp, '回到顶部'),
    (ChatNavigationAction.prevMessage, LucideIcons.chevronUp, '上一条消息'),
    (ChatNavigationAction.nextMessage, LucideIcons.chevronDown, '下一条消息'),
    (ChatNavigationAction.bottom, LucideIcons.arrowDown, '回到底部'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: (isDark ? const Color(0xFF121212) : Colors.white).withValues(
        alpha: 0.92,
      ),
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (action, icon, tooltip) in _buttons)
              Tooltip(
                message: tooltip,
                child: InkWell(
                  onTap: () => onAction(action),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      icon,
                      size: 19,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
