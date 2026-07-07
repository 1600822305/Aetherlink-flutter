import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// A navigation command executed by the message list state (which owns the
/// scroll + observer controllers).
enum ChatNavigationAction { top, prevMessage, nextMessage, bottom }

typedef ChatNavigationHandler = void Function(ChatNavigationAction action);

ChatNavigationHandler? _handler;

/// Registry bridging the floating panel to the message list, the same pattern
/// as the web `scrollControllerRegistry`: `_MessageListViewState` registers its
/// executor on mount and the panel invokes it directly — no provider event bus,
/// so repeated identical actions can never be deduplicated away.
void registerChatNavigationHandler(ChatNavigationHandler handler) =>
    _handler = handler;

void unregisterChatNavigationHandler(ChatNavigationHandler handler) {
  if (identical(_handler, handler)) _handler = null;
}

/// 对话导航 (设置 tab 常规设置 → [SidebarSettings.messageNavigation])：the port
/// of the web `ChatNavigation.tsx`, with the panel styling informed by
/// rikkahub's `MessageJumper`.
///
/// When set to 上下按钮, a pulsing indicator sits on the right edge at the
/// vertical center of the visible message area (above the keyboard, tracked
/// via [bottomInset]); tapping it or swiping it left reveals a floating
/// vertical panel with 滚动显示开关 / 回到顶部 / 上一条消息 / 下一条消息 /
/// 回到底部 buttons. With 滚动时显示导航 on, the panel also slides in while
/// the list is scrolling (rikkahub's `isRecentScroll` behaviour). The panel
/// auto-hides after the web original's 1.5s idle timer. When set to 常驻显示
/// the panel is pinned open — no reveal gesture and no auto-hide — so it stays
/// reachable on full-screen-gesture devices where the right-edge swipe belongs
/// to the system back gesture. Renders nothing when set to 不显示.
class ChatNavigationOverlay extends ConsumerStatefulWidget {
  const ChatNavigationOverlay({
    super.key,
    required this.isScrolling,
    this.bottomInset = 0,
    this.keyboardVisible = false,
  });

  /// Live scroll activity of the message list (driven by the chat page's
  /// [NotificationListener]); used for 滚动时显示导航.
  final ValueListenable<bool> isScrolling;

  /// Height covered by the composer + keyboard, so the overlay centers within
  /// the actually-visible message area (web: keyboard-aware `top` position).
  final double bottomInset;

  /// Shrinks the panel slightly while the keyboard is up (web: `scale: 0.85`).
  final bool keyboardVisible;

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
  );

  late final Animation<double> _pulseOpacity = Tween<double>(
    begin: 0.3,
    end: 0.7,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    widget.isScrolling.addListener(_onScrollActivity);
  }

  @override
  void didUpdateWidget(covariant ChatNavigationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.isScrolling, widget.isScrolling)) {
      oldWidget.isScrolling.removeListener(_onScrollActivity);
      widget.isScrolling.addListener(_onScrollActivity);
    }
  }

  @override
  void dispose() {
    widget.isScrolling.removeListener(_onScrollActivity);
    _hideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// 滚动时显示导航：panel shows while the list scrolls and hides 1s after it
  /// stops (web: throttled scroll listener + 1s hide timer).
  void _onScrollActivity() {
    if (!mounted) return;
    final settings = ref.read(sidebarSettingsControllerProvider);
    if (settings.messageNavigation != MessageNavigation.buttons ||
        !settings.showNavigationOnScroll) {
      return;
    }
    // 常驻显示 mode never reaches here (guarded above), so the timer below
    // only ever hides the transient panel.
    if (widget.isScrolling.value) {
      _hideTimer?.cancel();
      if (!_visible) setState(() => _visible = true);
    } else {
      _resetHideTimer(const Duration(seconds: 1));
    }
  }

  void _show() {
    Haptics.instance.onNavigation();
    setState(() => _visible = true);
    _resetHideTimer();
  }

  void _resetHideTimer([
    Duration delay = const Duration(milliseconds: 1500),
  ]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  bool get _alwaysOn =>
      ref.read(sidebarSettingsControllerProvider).messageNavigation ==
      MessageNavigation.always;

  void _dispatch(ChatNavigationAction action) {
    Haptics.instance.onNavigation();
    if (!_alwaysOn) _resetHideTimer();
    _handler?.call(action);
  }

  void _toggleScrollNavigation() {
    Haptics.instance.onNavigation();
    if (!_alwaysOn) _resetHideTimer();
    final controller = ref.read(sidebarSettingsControllerProvider.notifier);
    final current = ref
        .read(sidebarSettingsControllerProvider)
        .showNavigationOnScroll;
    controller.setShowNavigationOnScroll(!current);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.messageNavigation),
    );
    if (mode == MessageNavigation.none) {
      _pulse.stop();
      return const SizedBox.shrink();
    }
    final alwaysOn = mode == MessageNavigation.always;
    final showPanel = alwaysOn || _visible;
    if (alwaysOn) _hideTimer?.cancel();
    final showOnScroll = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.showNavigationOnScroll),
    );

    // The pulse only needs to run while the indicator is on screen.
    if (showPanel) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.35, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: showPanel
              ? Padding(
                  key: const ValueKey('panel'),
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedScale(
                    scale: widget.keyboardVisible ? 0.85 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: _NavigationPanel(
                      onAction: _dispatch,
                      // 滚动显示开关只对呼出式（上下按钮）模式有意义，
                      // 常驻模式下隐藏该按钮。
                      showOnScroll: alwaysOn ? null : showOnScroll,
                      onToggleShowOnScroll: _toggleScrollNavigation,
                    ),
                  ),
                )
              : _PulseIndicator(
                  key: const ValueKey('indicator'),
                  opacity: _pulseOpacity,
                  compact: widget.keyboardVisible,
                  onReveal: _show,
                ),
        ),
      ),
    );
  }
}

/// The slim breathing strip on the right edge with a generous invisible hit
/// area, so the tap / left-swipe reveal is easy to trigger.
class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator({
    super.key,
    required this.opacity,
    required this.compact,
    required this.onReveal,
  });

  final Animation<double> opacity;

  /// Shorter strip while the keyboard is up (web: height 60 vs 100).
  final bool compact;

  final VoidCallback onReveal;

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator> {
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '显示对话导航',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onReveal,
        // 左滑触发对齐 web（累计滑动 ≥50px 即可，不要求甩动手速）；web 版
        // 还接受快速轻扫，所以松手时速度够快也触发。
        onHorizontalDragStart: (_) => _dragDx = 0,
        onHorizontalDragUpdate: (details) {
          _dragDx += details.delta.dx;
          if (_dragDx <= -50) {
            _dragDx = 0;
            widget.onReveal();
          }
        },
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -100) widget.onReveal();
        },
        child: SizedBox(
          width: 56,
          height: 160,
          child: Align(
            alignment: Alignment.centerRight,
            child: FadeTransition(
              opacity: widget.opacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 5,
                height: widget.compact ? 60 : 100,
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

/// The floating vertical button column: 滚动显示开关 / 回到顶部 / 上一条 /
/// 下一条 / 回到底部 (the web original's five buttons).
class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.onAction,
    required this.showOnScroll,
    required this.onToggleShowOnScroll,
  });

  final ValueChanged<ChatNavigationAction> onAction;

  /// Null hides the 滚动显示 toggle (常驻显示 mode, where it has no effect).
  final bool? showOnScroll;
  final VoidCallback onToggleShowOnScroll;

  static const List<(ChatNavigationAction, IconData, String)> _buttons = [
    (ChatNavigationAction.top, LucideIcons.arrowUp, '回到顶部'),
    (ChatNavigationAction.prevMessage, LucideIcons.chevronUp, '上一条消息'),
    (ChatNavigationAction.nextMessage, LucideIcons.chevronDown, '下一条消息'),
    (ChatNavigationAction.bottom, LucideIcons.arrowDown, '回到底部'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = 10.0;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(radius),
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
      shadowColor: theme.shadowColor.withValues(alpha: 0.3),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showOnScroll != null)
              _PanelButton(
                icon: LucideIcons.scroll,
                tooltip: showOnScroll!
                    ? '滚动时显示导航：已开启'
                    : '滚动时显示导航：已关闭',
                selected: showOnScroll,
                onTap: onToggleShowOnScroll,
              ),
            for (final (action, icon, tooltip) in _buttons)
              _PanelButton(
                icon: icon,
                tooltip: tooltip,
                onTap: () => onAction(action),
              ),
          ],
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Non-null for toggle buttons: highlights when on, dims the icon when off
  /// (web: `bgcolor: action.selected` + `opacity: 0.5`).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            color: (selected ?? false)
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(
                icon,
                size: 19,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: selected == false ? 0.5 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
