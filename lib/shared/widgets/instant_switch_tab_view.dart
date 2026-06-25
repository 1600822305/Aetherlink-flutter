import 'package:flutter/material.dart';

/// The project's standard "instant-switch" alternative to [TabBarView],
/// originally introduced on the MCP 服务器 settings page and now shared
/// across every multi-tab screen.
///
/// Behaviour:
///   * Uses an [IndexedStack] instead of a [PageView] — every tab subtree is
///     built once on mount and stays attached, so subsequent switches don't
///     trigger a fresh lazy build (which is the source of the first-switch
///     jank on heavy tabs like the 内置工具 list).
///   * Tap-to-switch is **instantaneous**: when [TabController.index] jumps
///     to the destination on tap, the listener swaps the [IndexedStack]'s
///     index in the same frame.
///   * Horizontal swipe stays available, but as a discrete "threshold jump"
///     rather than finger-following paging — when the accumulated drag
///     crosses [swipeThreshold] pixels the controller `animateTo`s the
///     adjacent tab. This avoids the half-paged jitter that a PageView has
///     when its child contains another horizontal scrollable.
///   * The TabBar's own indicator slide is preserved because it's driven by
///     [TabController.animation], independent of which view widget is below.
///
/// The [TabController] is owned by the parent (it's also wired to the
/// [TabBar] above) — this widget does not create or dispose it.
///
/// Usage:
/// ```dart
/// body: Column(
///   children: [
///     YourTabStrip(controller: _tabController),
///     Expanded(
///       child: InstantSwitchTabView(
///         controller: _tabController,
///         children: const [Tab1(), Tab2(), Tab3()],
///       ),
///     ),
///   ],
/// );
/// ```
class InstantSwitchTabView extends StatefulWidget {
  const InstantSwitchTabView({
    super.key,
    required this.controller,
    required this.children,
    this.swipeThreshold = 60.0,
    this.enableSwipe = true,
  });

  /// The same controller wired into the [TabBar] above. Drives both the
  /// current page and the tab strip's indicator animation.
  final TabController controller;

  /// One widget per tab — length must equal [TabController.length].
  final List<Widget> children;

  /// Horizontal drag distance (px) that needs to be exceeded for a swipe to
  /// jump to the adjacent tab. Defaults to 60.
  final double swipeThreshold;

  /// Disable when the parent already eats horizontal drags (e.g. a sidebar
  /// drawer whose swipe-to-close gesture conflicts, or a dialog whose
  /// dismissal already handles them).
  final bool enableSwipe;

  @override
  State<InstantSwitchTabView> createState() => _InstantSwitchTabViewState();
}

class _InstantSwitchTabViewState extends State<InstantSwitchTabView> {
  late int _index = widget.controller.index;
  double _swipeDx = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(InstantSwitchTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
      _index = widget.controller.index;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    // [TabController.index] jumps to the destination as soon as a tab is
    // tapped (the controller's animation still slides the indicator), so
    // swap the IndexedStack in the same frame for an instant page swap.
    if (widget.controller.index != _index) {
      setState(() => _index = widget.controller.index);
    }
  }

  void _onSwipeEnd() {
    if (_swipeDx > widget.swipeThreshold && _index > 0) {
      widget.controller.animateTo(_index - 1);
    } else if (_swipeDx < -widget.swipeThreshold &&
        _index < widget.controller.length - 1) {
      widget.controller.animateTo(_index + 1);
    }
    _swipeDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = IndexedStack(
      index: _index,
      sizing: StackFit.expand,
      children: widget.children,
    );
    if (widget.enableSwipe) {
      content = GestureDetector(
        onHorizontalDragStart: (_) => _swipeDx = 0,
        onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
        onHorizontalDragEnd: (_) => _onSwipeEnd(),
        child: content,
      );
    }
    return content;
  }
}
