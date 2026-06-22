import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [ScrollController] whose position pins to the bottom *during layout*
/// (inside [ScrollPosition.applyContentDimensions], before paint) whenever
/// [shouldAutoFollow] returns true and the user is not actively scrolling.
///
/// Following at layout time — rather than via a post-frame `jumpTo` — lets
/// streaming content grow with zero visible lag and without the one-frame
/// flicker a post-frame jump leaves behind. Ported from kelivo's
/// `ChatAutoFollowScrollController`.
class ChatAutoFollowScrollController extends ScrollController {
  /// Checked during layout to decide whether to pin to the bottom.
  bool Function() shouldAutoFollow = () => false;

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

  final ChatAutoFollowScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    // Guard on userScrollDirection (updated by the scroll activity, earlier than
    // any controller listener): correcting pixels mid-drag would override the
    // user's scroll for one frame and feel "stuck / can't scroll up".
    if (controller.shouldAutoFollow() &&
        userScrollDirection == ScrollDirection.idle) {
      final gap = this.maxScrollExtent - pixels;
      if (gap > 0.5) {
        correctPixels(this.maxScrollExtent);
        return false; // Re-run layout with the corrected position.
      }
    }
    return result;
  }
}

/// Stick-to-bottom state machine over a [ChatAutoFollowScrollController] — the
/// Flutter analogue of the web `ChatScrollController`
/// (`src/shared/services/chat/ChatScrollController.ts`), following kelivo's
/// design.
///
/// [isSticking] (web `stick`) is the single source of truth for "follow the
/// bottom"; the scroll listener flips it from position alone: within [threshold]
/// of the bottom → follow, an active scroll away from the bottom → stop. The
/// actual following is done by the controller's custom [ScrollPosition] during
/// layout; this class only decides *whether* to follow through
/// [ChatAutoFollowScrollController.shouldAutoFollow] — it never reacts to scroll
/// notifications, so plain scrolling can no longer drag the list back down.
///
/// Explicit intents — initial entry, switching topics, the user sending — call
/// [pinToBottom], which re-sticks and opens a short [pinWindow] so the list
/// follows even while the setting is off, covering the renders right after.
///
/// The controller never owns the [ScrollController]; the host widget creates and
/// disposes it. [dispose] only detaches this controller's own listener.
class ChatAutoScrollController {
  ChatAutoScrollController({
    required ChatAutoFollowScrollController scrollController,
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

  final ChatAutoFollowScrollController _scrollController;

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
  void _onScroll() {
    if (_disposed || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels <= threshold;
    if (atBottom) {
      _stick = true;
    } else if (position.userScrollDirection != ScrollDirection.idle) {
      _stick = false;
      _pinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Explicit pin-to-bottom intent (web `pinToBottom`): re-stick, jump after
  /// layout and keep following for [pinWindow] even while the setting is off.
  void pinToBottom() {
    if (_disposed) return;
    _stick = true;
    _pinnedUntil = DateTime.now().add(pinWindow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (_disposed || !_scrollController.hasClients) return;
    // Guard against the controller being briefly attached to two lists during a
    // route/topic transition.
    if (_scrollController.positions.length != 1) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent) {
      position.jumpTo(position.maxScrollExtent);
    }
  }

  void dispose() {
    _disposed = true;
    _scrollController.removeListener(_onScroll);
  }
}
