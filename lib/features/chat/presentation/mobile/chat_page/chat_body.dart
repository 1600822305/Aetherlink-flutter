import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:native_keyboard_height/native_keyboard_height.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page/message_list_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_navigation.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_selection_bar.dart';
import 'package:aetherlink_flutter/features/voice/presentation/widgets/tts_floating_player.dart';

/// The chat content over the background: the optional system-prompt bubble, the
/// scrollable message list and the composer floating over its bottom — a 1:1
/// port of the original `ChatPageUI` content area, where the input container is
/// `position: fixed` and transparent above the message list (which reserves
/// bottom room so its tail clears the composer) and only the input carries the
/// bottom safe-area inset.
class ChatBody extends StatefulWidget {
  const ChatBody({
    super.key,
    required this.showSystemPromptBubble,
    this.isSelecting = false,
  });

  final bool showSystemPromptBubble;
  final bool isSelecting;

  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> with WidgetsBindingObserver {
  final GlobalKey _inputKey = GlobalKey();
  double _inputHeight = 0;

  /// Live scroll activity of the message list, fed to [ChatNavigationOverlay]
  /// for 滚动时显示导航.
  final ValueNotifier<bool> _listScrolling = ValueNotifier(false);

  /// Guards against queuing more than one pending measure.
  bool _measureScheduled = false;

  // ── Keyboard instant-snap (native plugin + didChangeMetrics fallback) ──────
  //
  // Primary: [NativeKeyboardHeight] — a local Flutter plugin that mirrors the
  // original `capacitor-edge-to-edge` architecture. Events fire BEFORE the OS
  // animation with the FINAL keyboard height → single-frame snap, zero delay.
  //
  // Fallback: [WidgetsBindingObserver.didChangeMetrics] catches edge cases
  // where the native plugin misses an event (some OEM Android devices don't
  // fire WindowInsetsAnimationCompat reliably, or events can be lost during
  // widget rebuild cycles).

  /// Current keyboard height applied to layout (logical pixels).
  double _keyboardHeight = 0;

  /// Subscription to native keyboard events.
  StreamSubscription<KeyboardEvent>? _keyboardSub;

  /// Debounce timer for the didChangeMetrics fallback — avoids acting on
  /// intermediate animation frames.
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMeasure();
    _keyboardSub = NativeKeyboardHeight.instance.events.listen(
      _onKeyboardEvent,
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _keyboardSub?.cancel();
    _listScrolling.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by the native plugin. The "will" events snap the layout to the
  /// final height in a single frame — WeChat/QQ-style instant reposition, with
  /// the OS keyboard sliding up over the (opaque) area below the composer.
  /// Once the animation ends (didShow), the height is settled against
  /// Flutter's own `viewInsets` — authoritative in logical pixels, whereas the
  /// native dp conversion can drift on some devices. Per-frame progress events
  /// are ignored (frame-synced panning reads as a slow transition rather than
  /// an instant snap).
  void _onKeyboardEvent(KeyboardEvent event) {
    if (!mounted) return;
    // Cancel any pending fallback — the plugin is authoritative.
    _fallbackTimer?.cancel();
    switch (event.type) {
      case KeyboardEventType.progress:
        break;
      case KeyboardEventType.willShow:
        if ((event.height - _keyboardHeight).abs() > 0.5) {
          setState(() => _keyboardHeight = event.height);
        }
      case KeyboardEventType.didShow:
        final settled = _flutterImeInset() ?? event.height;
        if ((settled - _keyboardHeight).abs() > 0.5) {
          setState(() => _keyboardHeight = settled);
        }
      case KeyboardEventType.willHide:
      case KeyboardEventType.didHide:
        if (_keyboardHeight != 0) {
          setState(() => _keyboardHeight = 0);
        }
    }
  }

  /// The keyboard height above the navigation bar as measured by Flutter
  /// itself (logical pixels) — `viewInsets − viewPadding`, the same
  /// nav-bar-excluded convention the native plugin reports — or null when the
  /// engine hasn't received a non-zero inset yet.
  double? _flutterImeInset() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final view = views.first;
    final bottom =
        (view.viewInsets.bottom - view.viewPadding.bottom) /
        view.devicePixelRatio;
    return bottom > 0 ? bottom : null;
  }

  /// Fallback: if the native plugin misses an event, the platform's
  /// `viewInsets` will still settle to the correct value after the animation
  /// (~300ms). We only act when the settled value disagrees with our current
  /// `_keyboardHeight`.
  @override
  void didChangeMetrics() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty) return;
      final view = views.first;
      final rawBottom =
          (view.viewInsets.bottom - view.viewPadding.bottom) /
          view.devicePixelRatio;

      if (rawBottom < 1 && _keyboardHeight > 0) {
        // Keyboard is gone but we still think it's open — missed hide event.
        setState(() => _keyboardHeight = 0);
      } else if (rawBottom > 0 && (rawBottom - _keyboardHeight).abs() > 1) {
        // Missed show event, or the native-side height disagrees with the
        // settled Flutter inset — the engine's own measure wins.
        setState(() => _keyboardHeight = rawBottom);
      }
    });
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _measureInput();
    });
  }

  /// Reads the composer's rendered height so the list reserves matching bottom
  /// room (its tail must clear the floating input). Re-run after every frame
  /// that resizes the input — e.g. the field growing to multiple lines —
  /// surfaced by the [SizeChangedLayoutNotifier] wrapping it.
  void _measureInput() {
    if (!mounted) return;
    final box = _inputKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final height = box.size.height;
    if ((height - _inputHeight).abs() > 0.5) {
      setState(() => _inputHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    // _keyboardHeight is set by the native plugin (single event before
    // animation, zero delay).  viewPadding is the home-indicator safe area;
    // it only changes on rotation, not during keyboard transitions.
    final theme = Theme.of(context);
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    // When the keyboard is showing, subtract the InputBoxComposer's internal
    // bottom padding (8px) so the card sits flush against the keyboard — no
    // visible gap — matching the original's `position: fixed; bottom:
    // var(--keyboard-height)`.
    final keyboardActive = isTopRoute && _keyboardHeight > 0;
    // _keyboardHeight excludes the nav bar (QQ convention: ime − navBars), so
    // it stacks on top of the safe-area padding — correct both edge-to-edge
    // and when the system already insets the view above the nav bar.
    final bottomOffset = isTopRoute
        ? (keyboardActive
              ? math.max(_keyboardHeight + viewPadding - 8, viewPadding)
              : viewPadding)
        : viewPadding;

    return Column(
      children: [
        // TTS floating player — sits above the message list. Collapses to zero
        // height when idle. The system-prompt bubble is no longer pinned here;
        // it scrolls as the first item of the message list (see ChatMessageList),
        // matching the web original.
        const TtsFloatingPlayer(),
        Expanded(
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _scheduleMeasure();
              return false;
            },
            child: Stack(
              children: [
                // The list fills the body and reserves bottom room so its tail
                // rests above the floating composer + keyboard. Messages that
                // scroll past the bottom slide cleanly under the opaque footer
                // below the composer (WeChat/QQ style) — no per-frame ShaderMask
                // over the whole list, so scrolling stays a cheap texture blit.
                // Isolated as one raster layer so the keyboard animation samples
                // a cached texture instead of replaying every bubble's paint.
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        _listScrolling.value = true;
                      } else if (notification is ScrollEndNotification) {
                        _listScrolling.value = false;
                      }
                      return false;
                    },
                    child: RepaintBoundary(
                      child: ChatMessageList(
                        showSystemPromptBubble: widget.showSystemPromptBubble,
                        bottomReserve: widget.isSelecting
                            ? 120 + viewPadding
                            : _inputHeight + 16 + bottomOffset,
                        isSelecting: widget.isSelecting,
                      ),
                    ),
                  ),
                ),
                // 对话导航：右侧呼吸灯 + 上下跳转面板（设置 tab → 对话导航）。
                // bottomInset 让它在可见消息区域（键盘 + 输入框之上）内垂直居中。
                if (!widget.isSelecting)
                  Positioned.fill(
                    child: ChatNavigationOverlay(
                      isScrolling: _listScrolling,
                      bottomInset: _inputHeight + 16 + bottomOffset,
                      keyboardVisible: keyboardActive,
                    ),
                  ),
                if (widget.isSelecting)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MessageSelectionBottomBar(),
                  )
                else ...[
                  // Opaque backing spanning from the screen bottom up to the
                  // composer's top, so any message scrolling past is covered
                  // with a clean hard edge instead of being faded out by a
                  // costly full-list mask. A plain rect fill — no saveLayer.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: bottomOffset + _inputHeight,
                    child: IgnorePointer(
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomOffset,
                    child: SizeChangedLayoutNotifier(
                      child: KeyedSubtree(
                        key: _inputKey,
                        child: const SafeArea(
                          top: false,
                          bottom: false,
                          child: ChatInputBar(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
