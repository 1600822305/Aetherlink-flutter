import 'package:flutter/widgets.dart';

/// Stick-to-bottom state machine for the chat message list — a 1:1 port of the
/// web `ChatScrollController` (`src/shared/services/chat/ChatScrollController.ts`).
///
/// It drives an externally-owned [ScrollController]: [isSticking] (mirroring the
/// web `stick`) is the single source of truth for "follow the bottom". Only a
/// user scroll flips it ([_handleUserScroll]): scrolling up past [threshold]
/// stops following, scrolling back within it resumes. Content growth (streaming
/// text, async-loaded blocks) is followed passively via [onContentResized] (the
/// web's `ResizeObserver` → `handleContentResize`), gated by [isSticking] and
/// [isEnabled]. Explicit intents — initial entry, switching topics, the user
/// sending — call [pinToBottom] to override both the stick flag and the setting,
/// backed by a short [pinWindow] so content rendered just after the pin still
/// lands at the bottom.
///
/// The controller never owns the [ScrollController]; the host widget creates and
/// disposes it. [dispose] only detaches this controller's own listener.
class ChatAutoScrollController {
  ChatAutoScrollController({
    required ScrollController scrollController,
    required this.isEnabled,
    this.threshold = _kDefaultThreshold,
    this.pinWindow = _kDefaultPinWindow,
  }) : _scrollController = scrollController {
    _scrollController.addListener(_handleUserScroll);
  }

  /// Distance from the bottom (px) within which the list is "stuck"
  /// (web `DEFAULT_THRESHOLD`).
  static const double _kDefaultThreshold = 80;

  /// How long after an explicit pin content growth keeps following the bottom
  /// unconditionally (web `DEFAULT_PIN_WINDOW_MS`).
  static const Duration _kDefaultPinWindow = Duration(milliseconds: 500);

  final ScrollController _scrollController;

  /// Reads the live 自动下滑 setting (`SidebarSettings.autoScrollToBottom`); the
  /// web equivalent is `options.isEnabled`.
  final bool Function() isEnabled;

  final double threshold;
  final Duration pinWindow;

  bool _stick = true;
  DateTime _pinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastPixels = 0;
  bool _followScheduled = false;
  bool _disposed = false;

  /// Whether the list is currently following the bottom (web `stick`).
  bool get isSticking => _stick;

  /// User scroll is the only input that flips [_stick] (web `handleScroll`):
  /// back within [threshold] → follow; an explicit upward scroll → stop.
  void _handleUserScroll() {
    if (_disposed || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final pixels = position.pixels;
    final scrolledUp = pixels < _lastPixels - 0.5;
    _lastPixels = pixels;
    final distanceFromBottom = position.maxScrollExtent - pixels;
    if (distanceFromBottom <= threshold) {
      _stick = true;
    } else if (scrolledUp) {
      _stick = false;
      _pinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Explicit pin-to-bottom intent (web `pinToBottom`): override [_stick] and the
  /// setting, open the pin window, then jump after layout.
  void pinToBottom() {
    if (_disposed) return;
    _stick = true;
    _pinnedUntil = DateTime.now().add(pinWindow);
    _scheduleFollow();
  }

  /// Content grew (streaming / async render) — web `handleContentResize`. Follows
  /// the bottom only while stuck and either inside the pin window or enabled.
  void onContentResized() {
    if (_disposed) return;
    _scheduleFollow();
  }

  void _scheduleFollow() {
    if (_followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      _maybeJumpToBottom();
    });
  }

  void _maybeJumpToBottom() {
    if (_disposed || !_scrollController.hasClients) return;
    final pinned = DateTime.now().isBefore(_pinnedUntil);
    if (!_stick || !(pinned || isEnabled())) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent) {
      _scrollController.jumpTo(position.maxScrollExtent);
    }
    // Pre-set so the jump's own scroll callback is not misread as a user scroll.
    _lastPixels = _scrollController.position.pixels;
  }

  void dispose() {
    _disposed = true;
    _scrollController.removeListener(_handleUserScroll);
  }
}
