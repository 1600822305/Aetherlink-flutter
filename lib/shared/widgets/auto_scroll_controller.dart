import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A [ScrollController] whose position pins to the bottom *during layout*
/// (inside [ScrollPosition.applyContentDimensions], before paint) whenever
/// [shouldAutoFollow] returns true and the user is not actively scrolling.
///
/// Following at layout time — rather than via a post-frame `jumpTo` — lets
/// streaming content grow with zero visible lag and without the one-frame
/// flicker a post-frame jump leaves behind. Ported from kelivo's
/// `AutoFollowScrollController`.
class AutoFollowScrollController extends ScrollController {
  /// Checked during layout to decide whether to pin to the bottom.
  bool Function() shouldAutoFollow = () => false;

  /// Pending scroll compensation (px), applied during the next layout pass —
  /// used to pan the content in the same frame the keyboard reserve changes
  /// (WeChat-style: the viewport keeps showing the same content, shifted by
  /// exactly the keyboard height). Positive pans the content up.
  double pendingAdjust = 0;

  /// Adds a measured extent delta to [pendingAdjust] on the controller owning
  /// [position] (no-op for other position types). Used when content above the
  /// viewport changes height (e.g. a deferred bubble materializing) so the
  /// same layout pass shifts the offset by exactly that delta and the visible
  /// rows stay anchored.
  static bool addPendingAdjustFor(ScrollPosition position, double delta) {
    if (position is! _AutoFollowScrollPosition) return false;
    position.controller.pendingAdjust += delta;
    return true;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _AutoFollowScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      controller: this,
    );
  }
}

class _AutoFollowScrollPosition extends ScrollPositionWithSingleContext {
  _AutoFollowScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  final AutoFollowScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    // Layout-time compensation (keyboard reserve delta / above-viewport
    // materialization deltas): shift the content by the pending delta in the
    // same layout pass, so the visible content stays anchored. Returning
    // false re-runs layout and re-seeds any in-flight ballistic simulation
    // from the corrected offset.
    if (controller.pendingAdjust != 0) {
      final target = (pixels + controller.pendingAdjust).clamp(
        this.minScrollExtent,
        this.maxScrollExtent,
      );
      controller.pendingAdjust = 0;
      if ((target - pixels).abs() > 0.5) {
        correctPixels(target);
        return false; // Re-run layout with the corrected position.
      }
    }
    // Guard on userScrollDirection (updated by the scroll activity, earlier than
    // any controller listener): correcting pixels mid-drag would override the
    // user's scroll for one frame and feel "stuck / can't scroll up".
    if (controller.shouldAutoFollow() &&
        userScrollDirection == ScrollDirection.idle) {
      // Correct in *both* directions: content growth leaves pixels above the
      // bottom (gap > 0), while a shrinking estimated extent (ListView.builder
      // extrapolates unbuilt children) leaves pixels beyond it (gap < 0) — the
      // latter would otherwise settle through a visible ballistic clamp
      // animation instead of staying pinned.
      final gap = this.maxScrollExtent - pixels;
      if (gap.abs() > 0.5) {
        correctPixels(this.maxScrollExtent);
        return false; // Re-run layout with the corrected position.
      }
    }
    return result;
  }
}

/// Stick-to-bottom state machine over a [AutoFollowScrollController] — the
/// Flutter analogue of the web `ChatScrollController`
/// (`src/shared/services/chat/ChatScrollController.ts`), following kelivo's
/// design.
///
/// [isSticking] (web `stick`) is the single source of truth for "follow the
/// bottom"; the scroll listener flips it from position alone: within [threshold]
/// of the bottom → follow, an active scroll away from the bottom → stop. The
/// actual following is done by the controller's custom [ScrollPosition] during
/// layout; this class only decides *whether* to follow through
/// [AutoFollowScrollController.shouldAutoFollow] — it never reacts to scroll
/// notifications, so plain scrolling can no longer drag the list back down.
///
/// Explicit intents — initial entry, switching topics, the user sending — call
/// [pinToBottom], which re-sticks and opens a short [pinWindow] so the list
/// follows even while the setting is off, covering the renders right after.
///
/// The controller never owns the [ScrollController]; the host widget creates and
/// disposes it. [dispose] only detaches this controller's own listener.
class AutoScrollController {
  AutoScrollController({
    required AutoFollowScrollController scrollController,
    required this.isEnabled,
    this.threshold = _kDefaultThreshold,
    this.pinWindow = _kDefaultPinWindow,
  }) : _scrollController = scrollController {
    _scrollController.addListener(_onScroll);
    _scrollController.shouldAutoFollow = () =>
        _stick && (isEnabled() || _isPinned);
  }

  /// Distance from the bottom (px) within which the list is "stuck"
  /// (web `DEFAULT_THRESHOLD`).
  static const double _kDefaultThreshold = 80;

  /// How long after an explicit pin the list keeps following the bottom even
  /// when the setting is off (web `DEFAULT_PIN_WINDOW_MS`).
  static const Duration _kDefaultPinWindow = Duration(milliseconds: 500);

  final AutoFollowScrollController _scrollController;

  /// Reads the live 自动下滑 setting (`SidebarSettings.autoScrollToBottom`); the
  /// web equivalent is `options.isEnabled`.
  final bool Function() isEnabled;

  final double threshold;
  final Duration pinWindow;

  bool _stick = true;
  DateTime _pinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// Whether the list is currently following the bottom (web `stick`).
  bool get isSticking => _stick;

  /// Programmatically detach from the bottom so an explicit scroll-to-index
  /// (e.g. mini-map jump) is not immediately overridden by the auto-follow.
  void unstick() {
    _stick = false;
    _pinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool get _isPinned => DateTime.now().isBefore(_pinnedUntil);

  /// User scroll is the only input that flips [_stick] (web `handleScroll`):
  /// within [threshold] → follow; an active scroll away from the bottom → stop.
  ///
  /// Re-sticking requires an active *user* scroll (non-idle direction, which a
  /// drag or its fling keeps until the scroll ends). Programmatic animations
  /// (导航的上一条/下一条) leave the direction idle, so passing through the
  /// bottom threshold never re-engages the follow — otherwise the layout-time
  /// pin would fight the animation and yank the list back to the bottom.
  void _onScroll() {
    if (_disposed || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels <= threshold;
    final direction = position.userScrollDirection;
    // Any user scroll away from the bottom detaches, even inside the bottom
    // threshold — otherwise a wheel tick smaller than the threshold is undone
    // by the layout pin before the next tick and the list is locked to the
    // bottom. Re-stick only on a user scroll *toward* the bottom that lands
    // within the threshold: a scroll-offset correction during an upward
    // fling (history rows inserted above) can momentarily place pixels near
    // maxScrollExtent while the direction is still forward — re-sticking
    // then would pin the list against the user's scroll.
    if (direction == ScrollDirection.forward) {
      _stick = false;
      _pinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
    } else if (direction == ScrollDirection.reverse && atBottom) {
      _stick = true;
    }
  }

  /// Explicit pin-to-bottom intent (web `pinToBottom`): re-stick, jump after
  /// layout and keep following for [pinWindow] even while the setting is off.
  void pinToBottom() {
    if (_disposed) return;
    _stick = true;
    _pinnedUntil = DateTime.now().add(pinWindow);
    // Jump synchronously when called outside a frame (e.g. a tap handler) so
    // the very next frame already renders at the bottom — web
    // `pinToBottom('auto')` is an instant `scrollTop = scrollHeight`. When
    // called mid-build (didUpdateWidget on append) only the post-frame jump
    // runs; the layout-time auto-follow pins that frame anyway.
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _jumpToBottom();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (_disposed || !_scrollController.hasClients) return;
    // Guard against the controller being briefly attached to two lists during a
    // route/topic transition.
    if (_scrollController.positions.length != 1) return;
    final position = _scrollController.position;
    if (position.pixels != position.maxScrollExtent) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  void dispose() {
    _disposed = true;
    _scrollController.removeListener(_onScroll);
  }
}
