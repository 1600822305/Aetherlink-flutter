/// A non-Material drawer host for the chat page that can render the sidebar in
/// two display styles, selected by the persisted 侧边栏显示方式
/// ([SidebarDisplayMode]):
///
///   * `overlay` (default): the sidebar slides over a static chat page behind a
///     scrim — the same behavior as the native `Scaffold.drawer` it replaces.
///   * `push`: the chat page is translated to the right by the drawer's width as
///     the sidebar slides in (the kelivo-style reveal). Content is identical;
///     only the transform differs.
///
/// Replacing `Scaffold.drawer` means re-implementing the affordances Scaffold
/// gave us for free: a left-edge open-drag (kept to a narrow strip so it does
/// not steal the chat's own horizontal gestures), tap-/drag-to-close on the
/// scrim, a back-button close ([PopScope]), and the open haptic. The open/close
/// entry points are exposed through [SidebarScope] so the top bar's menu button
/// and the sidebar's close button drive the same controller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';

/// The open/close surface a [SidebarHost] exposes to its descendants via
/// [SidebarScope]; method calls do not require the caller to rebuild.
abstract class SidebarController {
  /// Animates the sidebar open.
  void openSidebar();

  /// Animates the sidebar closed.
  void closeSidebar();

  /// Opens when closed, closes when open.
  void toggleSidebar();

  /// Whether the sidebar is currently past the half-open point.
  bool get isSidebarOpen;
}

/// Exposes the host's [SidebarController] to the chat subtree (top bar + the
/// sidebar itself) so both ends drive the same drawer.
class SidebarScope extends InheritedWidget {
  const SidebarScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final SidebarController controller;

  static SidebarController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SidebarScope>();
    assert(scope != null, 'SidebarScope.of() called without a SidebarHost.');
    return scope!.controller;
  }

  static SidebarController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SidebarScope>()?.controller;

  @override
  bool updateShouldNotify(SidebarScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Hosts [child] (the chat [Scaffold]) and [drawer] (the [ChatSidebar]),
/// animating the drawer in/out in the style chosen by 侧边栏显示方式.
class SidebarHost extends ConsumerStatefulWidget {
  const SidebarHost({
    required this.child,
    required this.drawer,
    this.onOpened,
    super.key,
  });

  /// The page behind the drawer (the chat [Scaffold]).
  final Widget child;

  /// The drawer content (the [ChatSidebar]).
  final Widget drawer;

  /// Fired once each time the drawer crosses into the open state, mirroring the
  /// old `Scaffold.onDrawerChanged(true)` haptic.
  final VoidCallback? onOpened;

  @override
  ConsumerState<SidebarHost> createState() => _SidebarHostState();
}

class _SidebarHostState extends ConsumerState<SidebarHost>
    with SingleTickerProviderStateMixin
    implements SidebarController {
  /// Width (px) of the left-edge strip that accepts an open-drag while closed.
  /// Kept narrow so the chat's own horizontal gestures (code-block scroll, row
  /// swipes) are untouched.
  static const double _edgeDragWidth = 24;

  /// Drag-release speed (px/s) past which we fling to the nearer end instead of
  /// snapping by position.
  static const double _minFlingVelocity = 365;

  /// Spring velocity used for programmatic + settle animations.
  static const double _flingVelocity = 1.5;

  /// Native `Scaffold` drawer scrim (`Colors.black54`), ramped by progress so
  /// overlay mode looks identical to the drawer this replaces.
  static const double _maxScrimOpacity = 0.54;

  late final AnimationController _ac;

  /// Current drawer width, recomputed every build from 侧边栏宽度 + screen size;
  /// the drag math needs it without going through the widget tree.
  double _drawerWidth = kSidebarWidthMin;

  /// Tracks the open/closed edge so [SidebarHost.onOpened] fires once per open.
  bool _wasOpen = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _ac.addListener(_onProgress);
  }

  void _onProgress() {
    final open = _ac.value > 0.5;
    if (open && !_wasOpen) widget.onOpened?.call();
    _wasOpen = open;
  }

  @override
  void dispose() {
    _ac.removeListener(_onProgress);
    _ac.dispose();
    super.dispose();
  }

  // ── SidebarController ──────────────────────────────────────────────────────
  @override
  void openSidebar() => _ac.fling(velocity: _flingVelocity);

  @override
  void closeSidebar() => _ac.fling(velocity: -_flingVelocity);

  @override
  void toggleSidebar() => isSidebarOpen ? closeSidebar() : openSidebar();

  @override
  bool get isSidebarOpen => _ac.value > 0.5;

  // ── Drag handling ───────────────────────────────────────────────────────────
  void _onDragUpdate(DragUpdateDetails details) {
    if (_drawerWidth <= 0) return;
    _ac.value = (_ac.value + details.primaryDelta! / _drawerWidth).clamp(
      0.0,
      1.0,
    );
  }

  void _onDragStart(DragStartDetails details) => _ac.stop();

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    final bool open;
    if (velocity.abs() >= _minFlingVelocity) {
      open = velocity > 0;
    } else {
      open = _ac.value >= 0.5;
    }
    _ac.fling(velocity: open ? _flingVelocity : -_flingVelocity);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.sidebarDisplayMode),
    );
    final rawWidth = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.sidebarWidth),
    );
    final maxWidth = safeMaxSidebarWidth(MediaQuery.sizeOf(context).width);
    _drawerWidth = rawWidth.clamp(kSidebarWidthMin, maxWidth);

    return SidebarScope(
      controller: this,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, _) {
          final t = _ac.value;
          final w = _drawerWidth;
          final pushed = mode == SidebarDisplayMode.push;

          return PopScope(
            canPop: t <= 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) closeSidebar();
            },
            // Fixed child set (no conditional children): the gesture layers
            // stay mounted across the whole animation, so an open-drag started
            // at t==0 is never torn down the instant t becomes > 0 (that
            // teardown was what made opening need two swipes). Each layer is
            // toggled via IgnorePointer / z-order instead of being added or
            // removed.
            child: Stack(
              children: [
                // 1. Chat page — shifted right by the drawer width in push mode.
                Transform.translate(
                  offset: Offset(pushed ? w * t : 0, 0),
                  child: widget.child,
                ),

                // 2. Scrim over the chat page; tap or drag to close. Mounted
                //    always but ignored (pass-through to the chat) while closed.
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: t <= 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: closeSidebar,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: _maxScrimOpacity * t,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Left-edge open-drag strip — always mounted. Narrow +
                //    translucent so it never steals the chat's own horizontal
                //    gestures; while open it sits under the drawer (next layer)
                //    and is effectively shadowed.
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: _edgeDragWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: const SizedBox.expand(),
                  ),
                ),

                // 4. The drawer, sliding in from the left edge. Topmost so it
                //    stays fully opaque and owns gestures over its own area.
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: w,
                  child: Transform.translate(
                    offset: Offset(-w * (1 - t), 0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: widget.drawer,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
