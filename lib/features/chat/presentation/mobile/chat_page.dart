import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/shared/widgets/auto_scroll_controller.dart';
import 'package:aetherlink_flutter/shared/widgets/no_implicit_scroll_physics.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/deferred_content.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_selection_area.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_selection_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/multi_model_message_group.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/plain_style_message.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/chat_sidebar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_navigation.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_top_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/system_prompt_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';
import 'package:aetherlink_flutter/features/voice/presentation/widgets/tts_floating_player.dart';
import 'package:native_keyboard_height/native_keyboard_height.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

/// Notifier to request the message list to scroll to a specific message ID.
class ScrollToMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void scrollTo(String id) => state = id;
  void clear() => state = null;
}

final scrollToMessageIdProvider =
    NotifierProvider<ScrollToMessageNotifier, String?>(
      ScrollToMessageNotifier.new,
    );

/// Briefly highlights the message a 对话导航 jump landed on, mirroring the
/// web's `scrollToMessage` flash (1.6s), so the user can tell which message
/// the jump targeted.
class NavHighlightNotifier extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void flash(String id) {
    _timer?.cancel();
    state = id;
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (state == id) state = null;
    });
  }
}

final navHighlightMessageIdProvider =
    NotifierProvider<NavHighlightNotifier, String?>(NavHighlightNotifier.new);

/// Static UI strings. The original ran these through i18n; they are ported
/// verbatim as constants per the M4.1 approach — wiring up i18n is a separate
/// effort and out of scope.
const String _emptyConversationLabel = '对话开始了，请输入您的问题';

/// The chat home page (mobile). After M4.2.0 stood up the real layout shell and
/// proved the presentation → application → repository → Drift pipeline, M4.2.0b
/// restores the visual chrome 1:1 to the original Aetherlink: a full top bar
/// (menu / topic name / model selector / settings), the integrated input with
/// its button toolbar, the sidebar shell, and a themed background surface.
///
/// It remains a pure view: the message list and title come from
/// application-layer providers ([chatMessagesProvider] / [currentTopicProvider],
/// backed by the M1 [ChatRepository]); an empty database yields an empty list
/// rendered as the empty state — no mock data anywhere. It never imports `data`
/// (Rule 1).
///
/// Nothing is wired this round: sending, streaming, message-block rendering, the
/// model selector, the sidebar's real lists, search and the rest are disabled
/// placeholders (later slices), so the tree keeps its final shape.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSystemPromptBubble = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.showSystemPromptBubble),
    );
    final background = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.background),
    );
    // Per-assistant wallpaper overrides the global background (web:
    // 助手壁纸优先级高于全局设置).
    final assistantBackground = ref.watch(
      currentAssistantProvider.select((a) => a?.chatBackground),
    );
    final effectiveBackground = _resolveBackground(
      assistantBackground,
      background,
    );
    final isSelecting = ref.watch(
      messageSelectionProvider.select((s) => s.isSelecting),
    );

    // Tag the performance monitor with the streaming state so jank during a
    // streaming response is attributed correctly. No-op while the monitor is off.
    ref.listen(
      chatControllerProvider.select((s) => s.value?.isStreaming ?? false),
      (_, streaming) => PerfMonitor.instance.setStreaming(streaming),
    );

    // The sidebar is hosted by [SidebarHost] (not `Scaffold.drawer`) so its
    // display style can switch between overlay and push (侧边栏显示方式); the
    // chat page itself stays a plain Scaffold behind it. Buzz when the sidebar
    // opens (gated by the 触觉反馈 master + 侧边栏 toggle), matching the original
    // drawer-open haptic.
    //
    // resizeToAvoidBottomInset is always false: the keyboard offset is handled
    // manually inside [_ChatBody] — matching the original's `position: fixed`
    // input — so the Scaffold body never animates its height during the
    // keyboard transition, eliminating the per-frame ShaderMask re-rasterize
    // that caused visible jank.
    return PopScope(
      canPop: !isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSelecting) {
          ref.read(messageSelectionProvider.notifier).exitSelectionMode();
        }
      },
      child: SidebarHost(
        drawer: const ChatSidebar(),
        onOpened: Haptics.instance.onSidebar,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: isSelecting
              ? const MessageSelectionTopBar()
              : const ChatTopBar(),
          body: _ChatBackground(
            background: effectiveBackground,
            child: _ChatBody(
              showSystemPromptBubble: showSystemPromptBubble,
              isSelecting: isSelecting,
            ),
          ),
        ),
      ),
    );
  }
}

/// The chat content over the background: the optional system-prompt bubble, the
/// scrollable message list and the composer floating over its bottom — a 1:1
/// port of the original `ChatPageUI` content area, where the input container is
/// `position: fixed` and transparent above the message list (which reserves
/// bottom room so its tail clears the composer) and only the input carries the
/// bottom safe-area inset.
class _ChatBody extends StatefulWidget {
  const _ChatBody({
    required this.showSystemPromptBubble,
    this.isSelecting = false,
  });

  final bool showSystemPromptBubble;
  final bool isSelecting;

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> with WidgetsBindingObserver {
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
        // it scrolls as the first item of the message list (see _MessageList),
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
                      child: _MessageList(
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

/// The chat-message-area background, ported 1:1 from the original
/// `ChatPageUI.tsx` (lines 805-846). When [ChatBackgroundSettings.enabled] and
/// an image is set it stacks, bottom to top:
///   1. the background image — `opacity` is applied directly to the image layer
///      (`BoxFit`/`Alignment`/`ImageRepeat` mapped from CSS size/position/repeat),
///      blending toward the themed surface painted behind it;
///   2. an optional white readability gradient
///      (`linear-gradient(to bottom, rgba(255,255,255,.3), rgba(255,255,255,.5))`),
///      shown when [ChatBackgroundSettings.showOverlay];
///   3. the chat content ([child]).
/// When disabled (or no image) it collapses to the original solid themed
/// surface. The image is a base64 data URL; it is decoded once and cached as a
/// [MemoryImage] so rebuilds (typing, streaming) never re-decode it.

/// Resolves the wallpaper to render: the current assistant's [chatBackground]
/// wins when it is enabled with an image (web: 助手壁纸优先级高于全局设置),
/// otherwise the [global] chat-interface background is used. The assistant's
/// optional fields fall back to the same defaults as the global block.
ChatBackgroundSettings _resolveBackground(
  AssistantChatBackground? assistant,
  ChatBackgroundSettings global,
) {
  if (assistant != null && assistant.enabled && assistant.imageUrl.isNotEmpty) {
    return ChatBackgroundSettings(
      enabled: true,
      imageUrl: assistant.imageUrl,
      opacity: assistant.opacity ?? 0.7,
      size: ChatBackgroundSize.fromId(assistant.size),
      position: ChatBackgroundPosition.fromId(assistant.position),
      repeat: ChatBackgroundRepeat.fromId(assistant.repeat),
      showOverlay: assistant.showOverlay ?? true,
    );
  }
  return global;
}

class _ChatBackground extends StatefulWidget {
  const _ChatBackground({required this.background, required this.child});

  final ChatBackgroundSettings background;
  final Widget child;

  @override
  State<_ChatBackground> createState() => _ChatBackgroundState();
}

class _ChatBackgroundState extends State<_ChatBackground> {
  MemoryImage? _image;
  String _decodedUrl = '';

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(_ChatBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.background.imageUrl != _decodedUrl) {
      _decodeImage();
    }
  }

  /// Decodes the `data:<mime>;base64,<...>` URL into cached bytes. Mirrors the
  /// settings page's `_ImageArea._decode`.
  void _decodeImage() {
    final url = widget.background.imageUrl;
    _decodedUrl = url;
    final marker = url.indexOf('base64,');
    if (marker < 0) {
      _image = null;
      return;
    }
    try {
      _image = MemoryImage(base64Decode(url.substring(marker + 7)));
    } on FormatException {
      _image = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = widget.background;
    final image = _image;

    if (!background.enabled || image == null) {
      return ColoredBox(color: theme.colorScheme.surface, child: widget.child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              image: DecorationImage(
                image: image,
                fit: _fitFor(background.size),
                alignment: _alignmentFor(background.position),
                repeat: _repeatFor(background.repeat),
                opacity: background.opacity.clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
        if (background.showOverlay)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x4DFFFFFF), Color(0x80FFFFFF)],
                  ),
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

/// CSS `background-size` → [BoxFit] (`auto` keeps the natural size, like CSS).
BoxFit _fitFor(ChatBackgroundSize size) => switch (size) {
  ChatBackgroundSize.cover => BoxFit.cover,
  ChatBackgroundSize.contain => BoxFit.contain,
  ChatBackgroundSize.auto => BoxFit.none,
};

/// CSS `background-position` → [Alignment].
Alignment _alignmentFor(ChatBackgroundPosition position) => switch (position) {
  ChatBackgroundPosition.center => Alignment.center,
  ChatBackgroundPosition.top => Alignment.topCenter,
  ChatBackgroundPosition.bottom => Alignment.bottomCenter,
  ChatBackgroundPosition.left => Alignment.centerLeft,
  ChatBackgroundPosition.right => Alignment.centerRight,
};

/// CSS `background-repeat` → [ImageRepeat].
ImageRepeat _repeatFor(ChatBackgroundRepeat repeat) => switch (repeat) {
  ChatBackgroundRepeat.noRepeat => ImageRepeat.noRepeat,
  ChatBackgroundRepeat.repeat => ImageRepeat.repeat,
  ChatBackgroundRepeat.repeatX => ImageRepeat.repeatX,
  ChatBackgroundRepeat.repeatY => ImageRepeat.repeatY,
};

/// The scrollable message region. Reflects the real read provider: loading →
/// spinner, failure → error notice, empty → empty state, and a list of message
/// bubbles otherwise.
class _MessageList extends ConsumerWidget {
  const _MessageList({
    this.showSystemPromptBubble = false,
    this.bottomReserve = 0,
    this.isSelecting = false,
  });

  /// Whether the system-prompt bubble shows at the top of the list (it scrolls
  /// with the messages, like the web original — never selectable).
  final bool showSystemPromptBubble;

  /// Extra bottom padding so the list's tail clears the composer floating over
  /// it (the composer's measured height; see [_ChatBodyState]).
  final double bottomReserve;

  final bool isSelecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initial load / failure depend only on the async phase, never on content,
    // so the spinner/error states never rebuild while a reply streams in.
    final hasValue = ref.watch(
      chatControllerProvider.select((a) => a.hasValue),
    );
    if (!hasValue) {
      final error = ref.watch(
        chatControllerProvider.select((a) => a.error),
      );
      return error != null
          ? _ErrorNotice(error: error)
          : const Center(child: CircularProgressIndicator());
    }

    // Subscribe to message *order* only (ids joined into one key string) so this
    // list rebuilds when a message is added/removed/reordered — but NOT when an
    // existing message's content streams in. Each bubble watches its own view by
    // id, so a streaming token rebuilds only the affected bubble, not the list.
    final orderKey = ref.watch(
      chatControllerProvider.select(_messageOrderKey),
    );
    if (orderKey.isEmpty) {
      return _EmptyState(
        showSystemPromptBubble: showSystemPromptBubble && !isSelecting,
      );
    }
    final rows = <List<String>>[
      for (final row in orderKey.split('\u0000')) row.split(','),
    ];
    return _MessageListView(
      rows,
      showSystemPromptBubble: showSystemPromptBubble && !isSelecting,
      bottomReserve: bottomReserve,
      isSelecting: isSelecting,
    );
  }
}

/// Encodes the conversation's render *rows* into a single string so Riverpod's
/// `select` dedup short-circuits in-place content updates (streaming) — the key
/// changes only when the set/order/grouping of messages changes.
///
/// Rows are separated by `\u0000`; a row's member ids by `,`. Consecutive
/// assistant siblings sharing one `siblingsGroupId (>0)` and `askId` collapse
/// into a single multi-member row (the 对比 group); every other message is its
/// own single-member row.
String _messageOrderKey(AsyncValue<ChatState> async) {
  final messages = async.value?.messages;
  if (messages == null || messages.isEmpty) return '';
  final rows = <String>[];
  var i = 0;
  while (i < messages.length) {
    final m = messages[i];
    if (m.role == MessageRole.assistant &&
        m.siblingsGroupId > 0 &&
        m.askId != null) {
      final members = <String>[];
      while (i < messages.length) {
        final n = messages[i];
        if (n.role == MessageRole.assistant &&
            n.siblingsGroupId == m.siblingsGroupId &&
            n.askId == m.askId) {
          members.add(n.id);
          i++;
        } else {
          break;
        }
      }
      rows.add(members.join(','));
    } else {
      rows.add(m.id);
      i++;
    }
  }
  return rows.join('\u0000');
}

/// Empty-state placeholder shown when the current topic has no messages (the
/// fresh-install case). Text color is a theme token.
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.showSystemPromptBubble = false});

  /// When set, the system-prompt bubble sits at the very top (above the empty
  /// placeholder), mirroring the web original where the bubble renders before
  /// the "新的对话开始了" notice.
  final bool showSystemPromptBubble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        _emptyConversationLabel,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
    if (!showSystemPromptBubble) return Center(child: placeholder);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: SystemPromptBubble(),
        ),
        Expanded(child: Center(child: placeholder)),
      ],
    );
  }
}

/// Shown when the read provider fails (e.g. the database cannot be opened).
/// Displays the underlying exception so the cause is diagnosable in release
/// builds where the console stack trace is unavailable.
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载消息失败',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bubble per message (M4.2.1). Each [ChatMessageBubble] reads its own
/// `main_text` blocks through the real provider and aligns by role. With a
/// fresh database this list is empty, so the empty state shows instead.
///
/// 自动下滑 (设置 tab 常规设置 → [SidebarSettings.autoScrollToBottom]) lives in
/// [AutoScrollController] (the port of the web `ChatScrollController`); this
/// widget only owns the [AutoFollowScrollController] and tells the state
/// machine which message change is an explicit pin:
/// * initial entry / switching topics (first-message id changes) / the user
///   sending (message count grows) → [AutoScrollController.pinToBottom].
/// In-place growth such as streaming needs nothing here — the custom
/// [AutoFollowScrollController] follows it during layout when sticking.
class _MessageListView extends ConsumerStatefulWidget {
  const _MessageListView(
    this.rows, {
    this.showSystemPromptBubble = false,
    this.bottomReserve = 0,
    this.isSelecting = false,
  });

  /// Render rows of the current conversation: a single-element row is one
  /// message, a multi-element row is a multi-model 对比 group. Each bubble watches
  /// its own [ChatMessageView] by id, so streaming content rebuilds only that
  /// bubble — never this whole list.
  final List<List<String>> rows;

  /// Renders the system-prompt bubble as the first (scrolling) list item, like
  /// the web original, instead of pinning it above the list.
  final bool showSystemPromptBubble;

  /// Reserves room under the last bubble for the composer floating over the
  /// list (mirrors the original `messageContainer` `paddingBottom`).
  final double bottomReserve;

  final bool isSelecting;

  @override
  ConsumerState<_MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends ConsumerState<_MessageListView> {
  /// Rows rendered when entering a topic (kelivo's initial history window).
  /// Entering pins to the bottom, which lays the list out from the top — so
  /// the very first frame pays for every row it can reach. Windowing caps
  /// that first-frame build to the most recent rows; older history is
  /// revealed page-by-page as the user scrolls near the top.
  static const int _kInitialWindowRows = 30;

  /// Rows in the very first frame of a topic entry/switch — roughly one
  /// screenful. The rest of the initial window is ramped in over the next
  /// frames ([_rampStep]), so even a heavy conversation never pays for 30
  /// rows on the single frame that runs the page transition (WeChat-style
  /// instant entry; older rows stream in with no artificial delay).
  static const int _kFirstFrameRows = 8;

  /// Rows added per frame while ramping up to [_kInitialWindowRows].
  static const int _kRampRowsPerFrame = 8;

  /// Rows revealed per load when scrolling near the hidden history.
  static const int _kRevealPageRows = 30;

  /// Distance (px) from the top that triggers revealing another page.
  static const double _kRevealThreshold = 200;

  final AutoFollowScrollController _scrollController =
      AutoFollowScrollController();
  late final ListObserverController _observerController;
  late final AutoScrollController _autoScroll;

  /// Identifies the loaded conversation so a topic switch (first-message change)
  /// can be told apart from appends / in-place content growth. Tracked over the
  /// flattened message ids so multi-model groups don't confuse the heuristic.
  String? _firstId;
  int _count = 0;

  /// Chained anchor for 上一条/下一条 (kelivo's `_lastJumpUserMessageId`
  /// pattern): the row index the last jump landed on. Consecutive taps step
  /// from here directly — no per-tap viewport observation (cheaper, no jank
  /// from a forced observe pass) and immune to the landing position being
  /// clamped near the list's ends. Cleared as soon as the user scrolls.
  int? _navAnchorIndex;

  /// QQ's `getExtraLayoutSpace` pattern: the enlarged cache extent is only
  /// engaged while a navigation jump is in flight (so the glide path is
  /// pre-built), and released back to the framework default afterwards —
  /// off-viewport layout work and memory stay small during normal use.
  bool _navCacheBoost = false;

  /// Leading rows of the conversation currently *not* rendered (the hidden
  /// history window). Always indexes into [widget.rows] space.
  int _hiddenRowCount = 0;
  bool _revealScheduled = false;
  DateTime? _lastRevealAt;

  /// Frame-by-frame expansion of the entry window (see [_kFirstFrameRows]).
  bool _ramping = false;
  int _rampTargetHidden = 0;

  int get _effectiveHiddenRows =>
      widget.isSelecting ? 0 : _hiddenRowCount.clamp(0, widget.rows.length);

  /// The system-prompt bubble is only the first item once the full history is
  /// revealed — it belongs at the very top of the conversation.
  int get _headerCount =>
      widget.showSystemPromptBubble && _effectiveHiddenRows == 0 ? 1 : 0;

  /// A slim spinner row sits above the window while history is still hidden
  /// (loaded on scroll), WeChat-style. Mutually exclusive with [_headerCount]
  /// (the prompt bubble only shows once everything is revealed).
  int get _loaderCount => _effectiveHiddenRows > 0 ? 1 : 0;

  /// Every message id in display order (groups flattened) — for the autoscroll
  /// heuristic and mini-map scroll-to-message lookups.
  List<String> get _flatIds => [for (final row in widget.rows) ...row];

  @override
  void initState() {
    super.initState();
    _observerController = ListObserverController(controller: _scrollController)
      ..cacheJumpIndexOffset = false;
    _autoScroll = AutoScrollController(
      scrollController: _scrollController,
      isEnabled: () =>
          ref.read(sidebarSettingsControllerProvider).autoScrollToBottom,
    );
    final ids = _flatIds;
    _firstId = ids.isEmpty ? null : ids.first;
    _count = ids.length;
    _beginWindowRamp();
    _scrollController.addListener(_onUserScrollResetNavAnchor);
    registerChatNavigationHandler(_handleNavigation);
    // Initial entry pins to the bottom (latest message), like the web's mount.
    _autoScroll.pinToBottom();
  }

  @override
  void didUpdateWidget(covariant _MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keyboard show/hide (or the composer growing) changes the bottom reserve;
    // pan the content by the same delta so what was visible above the composer
    // stays visible — WeChat-style whole-content shift.
    final reserveDelta = widget.bottomReserve - oldWidget.bottomReserve;
    if (reserveDelta.abs() > 0.5) {
      _scrollController.pendingAdjust += reserveDelta;
    }
    final ids = _flatIds;
    final firstId = ids.isEmpty ? null : ids.first;
    final count = ids.length;
    final topicSwitched = firstId != _firstId;
    final appended = !topicSwitched && count > _count;
    _firstId = firstId;
    _count = count;

    if (topicSwitched) {
      _beginWindowRamp();
    } else {
      _hiddenRowCount = _hiddenRowCount.clamp(0, widget.rows.length);
      _rampTargetHidden = _rampTargetHidden.clamp(0, widget.rows.length);
    }

    if (topicSwitched || appended) {
      _navAnchorIndex = null;
      _autoScroll.pinToBottom();
    }
  }

  /// Sets the entry window to [_kFirstFrameRows] and schedules the frame-by-
  /// frame ramp up to [_kInitialWindowRows] — pure post-frame callbacks, no
  /// timers, so short topics still mount whole in one frame.
  void _beginWindowRamp() {
    final total = widget.rows.length;
    _rampTargetHidden = (total - _kInitialWindowRows).clamp(0, total);
    _hiddenRowCount = (total - _kFirstFrameRows).clamp(0, total);
    if (_hiddenRowCount <= _rampTargetHidden) {
      _hiddenRowCount = _rampTargetHidden;
      _ramping = false;
      return;
    }
    if (!_ramping) {
      _ramping = true;
      WidgetsBinding.instance.addPostFrameCallback(_rampStep);
    }
  }

  /// One ramp increment per frame. Rows are prepended with stable keys
  /// (`findChildIndexCallback`), so the sliver keeps the existing elements and
  /// issues its own scroll-offset correction for the extent inserted above —
  /// the viewport stays still without any manual compensation.
  void _rampStep(Duration _) {
    if (!mounted || !_ramping) return;
    if (_hiddenRowCount <= _rampTargetHidden) {
      _ramping = false;
      return;
    }
    setState(() {
      _hiddenRowCount = (_hiddenRowCount - _kRampRowsPerFrame).clamp(
        _rampTargetHidden,
        widget.rows.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _ramping = false;
        return;
      }
      _rampStep(Duration.zero);
    });
  }

  /// Reveals another page of hidden history when the user scrolls near the
  /// top. The per-row keys + `findChildIndexCallback` let the sliver keep the
  /// existing elements and self-correct the scroll offset by the *actual*
  /// extent laid out above, so no manual estimate-based compensation is
  /// needed (an extra `extentAnchor` shift here would double-correct and
  /// throw the viewport toward the bottom on fast flings).
  void _maybeRevealMore(ScrollMetrics metrics) {
    if (_revealScheduled || _ramping || _effectiveHiddenRows == 0) return;
    if (metrics.pixels > _kRevealThreshold) return;
    final last = _lastRevealAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 120)) {
      return;
    }
    _revealScheduled = true;
    _lastRevealAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _revealScheduled = false;
        return;
      }
      setState(() {
        _hiddenRowCount = (_hiddenRowCount - _kRevealPageRows).clamp(
          0,
          widget.rows.length,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealScheduled = false;
        // At the very top no further scroll notifications arrive (pixels
        // can't go below zero), so continue revealing from here until the
        // viewport is off the threshold or history is exhausted. Delayed past
        // the throttle window so each page still lands on its own frame.
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!mounted || !_scrollController.hasClients) return;
          if (_scrollController.positions.length != 1) return;
          _maybeRevealMore(_scrollController.position);
        });
      });
    });
  }

  /// Reveals hidden history down to (at most) [targetRow]; the sliver's own
  /// offset correction keeps the viewport on the same content.
  Future<void> _revealDownTo(int targetRow) async {
    if (targetRow >= _effectiveHiddenRows) return;
    _ramping = false;
    setState(() {
      _hiddenRowCount = targetRow.clamp(0, widget.rows.length);
    });
    await WidgetsBinding.instance.endOfFrame;
  }

  /// A user scroll invalidates the chained jump anchor — the next 上一条/
  /// 下一条 re-observes the viewport instead (kelivo resets its anchor the
  /// same way).
  void _onUserScrollResetNavAnchor() {
    if (_navAnchorIndex == null || !_scrollController.hasClients) return;
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _navAnchorIndex = null;
    }
  }

  @override
  void dispose() {
    unregisterChatNavigationHandler(_handleNavigation);
    _scrollController.removeListener(_onUserScrollResetNavAnchor);
    _autoScroll.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Executes a 对话导航 action (invoked directly by [ChatNavigationOverlay]
  /// through the handler registry). 上一条/下一条 step from the chained
  /// [_navAnchorIndex] when present, otherwise from the first row currently
  /// visible (observed via [ListObserverController]), falling back to
  /// 回顶/回底 at the ends — mirroring the web `ChatNavigation`.
  Future<void> _handleNavigation(ChatNavigationAction action) async {
    if (!_navCacheBoost && mounted) {
      setState(() => _navCacheBoost = true);
      // Let the boosted cache build before measuring/jumping.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    try {
      await _runNavigation(action);
    } finally {
      if (mounted && _navCacheBoost) {
        setState(() => _navCacheBoost = false);
      }
    }
  }

  /// 距离自适应滑行时长（千问 FlyOutSmoothScroller 的思路）：时长随剩余距离
  /// 占视口的比例缩放并 clamp 在 80–350ms —— 目标就在附近时近似瞬时到位，
  /// 长滑保持现有速度感。
  static Duration _glideDuration(double distancePx, double viewportPx) {
    if (viewportPx <= 0) return const Duration(milliseconds: 300);
    final ms = (distancePx.abs() / viewportPx * 350).clamp(80.0, 350.0);
    return Duration(milliseconds: ms.round());
  }

  Future<void> _runNavigation(ChatNavigationAction action) async {
    switch (action) {
      case ChatNavigationAction.top:
        _navAnchorIndex = null;
        _autoScroll.unstick();
        if (!_scrollController.hasClients) return;
        // Long-distance smooth scrolls would lazily build every message on
        // the way (the web keeps the whole DOM alive, Flutter doesn't), which
        // is what dropped frames. Teleport close to the target first, then
        // finish with a short glide. The glide distance must stay *within*
        // the scrollCacheExtent (1 viewport): everything the glide passes is
        // then already built by the teleport frame, so the animation itself
        // runs completely build-free.
        final topPosition = _scrollController.position;
        final topFar = topPosition.viewportDimension * 0.8;
        if (_effectiveHiddenRows > 0) {
          // Reveal the whole history and land near the top *in the same
          // frame*: the relayout then only builds the top screen, never the
          // hidden rows in between.
          _ramping = false;
          setState(() => _hiddenRowCount = 0);
          _scrollController.jumpTo(topFar);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !_scrollController.hasClients) return;
        } else if (topPosition.pixels > topFar) {
          _scrollController.jumpTo(topFar);
          // Let the teleport frame's build storm (target screen + cache)
          // finish before starting the glide, so the animation's first
          // frames aren't the ones paying for it.
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !_scrollController.hasClients) return;
        }
        await _scrollController.animateTo(
          0,
          duration: _glideDuration(
            _scrollController.position.pixels,
            _scrollController.position.viewportDimension,
          ),
          curve: Curves.easeOutCubic,
        );
      case ChatNavigationAction.bottom:
        _navAnchorIndex = null;
        if (_scrollController.hasClients) {
          // Same near-jump + cache-covered short glide as 回顶.
          final position = _scrollController.position;
          final far = position.viewportDimension * 0.8;
          if (position.maxScrollExtent - position.pixels > far) {
            _scrollController.jumpTo(position.maxScrollExtent - far);
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted) return;
          }
          if (!_scrollController.hasClients) return;
          await _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: _glideDuration(
              _scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels,
              _scrollController.position.viewportDimension,
            ),
            curve: Curves.easeOutCubic,
          );
        }
        // Re-stick and settle any residual gap (estimated extents can shift
        // while the destination screen builds).
        _autoScroll.pinToBottom();
      case ChatNavigationAction.prevMessage:
      case ChatNavigationAction.nextMessage:
        // The anchor lives in full-row space ([widget.rows] index) so it
        // survives history reveals shifting the list indices.
        var anchorRow = _navAnchorIndex;
        if (anchorRow == null) {
          // isForce: without it the observer skips re-dispatch when the scroll
          // offset hasn't changed since the last observation (e.g. resting at
          // the bottom after the entry pin), returning a null result.
          final result = await _observerController.dispatchOnceObserve(
            isForce: true,
            isDependObserveCallback: false,
          );
          final first = result.observeResult?.firstChild?.index;
          if (first == null || !mounted) return;
          anchorRow =
              first - _headerCount - _loaderCount + _effectiveHiddenRows;
        }
        final delta = action == ChatNavigationAction.prevMessage ? -1 : 1;
        final targetRow = anchorRow + delta;
        if (targetRow < 0) {
          return _handleNavigation(ChatNavigationAction.top);
        }
        if (targetRow >= widget.rows.length) {
          return _handleNavigation(ChatNavigationAction.bottom);
        }
        if (targetRow < _effectiveHiddenRows) {
          // Stepping into hidden history: reveal a page above it first.
          await _revealDownTo(
            (targetRow - _kRevealPageRows + 1).clamp(0, targetRow),
          );
          if (!mounted) return;
        }
        _navAnchorIndex = targetRow;
        _autoScroll.unstick();
        // Smooth scroll like the web's `scrollIntoView({behavior: 'smooth'})`.
        // The enlarged scrollCacheExtent keeps the neighbouring bubbles built
        // ahead of time, so the animation runs without mid-flight builds.
        // 上/下一条只跨一行，短时长快速到位（FlyOutSmoothScroller 的
        // 短距离快档），消除拖拽感。
        await _observerController.animateTo(
          index: targetRow - _effectiveHiddenRows + _headerCount + _loaderCount,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        if (mounted && targetRow < widget.rows.length) {
          ref
              .read(navHighlightMessageIdProvider.notifier)
              .flash(widget.rows[targetRow].first);
        }
    }
  }

  /// Handles a mini-map scroll-to-message request, revealing hidden history
  /// first when the target is above the current window.
  Future<void> _scrollToMessageFromMiniMap(String messageId) async {
    final rowIndex = widget.rows.indexWhere((row) => row.contains(messageId));
    if (rowIndex < 0) return;
    if (rowIndex < _effectiveHiddenRows) {
      await _revealDownTo(rowIndex);
      if (!mounted) return;
    }
    _navAnchorIndex = rowIndex;
    _autoScroll.unstick();
    ref.read(navHighlightMessageIdProvider.notifier).flash(messageId);
    var listIndex =
        rowIndex - _effectiveHiddenRows + _headerCount + _loaderCount;
    if (widget.isSelecting) {
      // Multi-select expands 对比 groups into one list item per message.
      var expanded = 0;
      for (var i = 0; i < rowIndex; i++) {
        expanded += widget.rows[i].length;
      }
      listIndex = expanded + widget.rows[rowIndex].indexOf(messageId);
    }
    await _observerController.animateTo(
      index: listIndex,
      alignment: 0.1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = widget.isSelecting;
    // Multi-select shows every message individually so each can be ticked; the
    // 对比 grouping only applies to the normal (read) view.
    final hiddenRows = _effectiveHiddenRows;
    final allRows = isSelecting
        ? <List<String>>[
            for (final row in widget.rows)
              for (final id in row) <String>[id],
          ]
        : widget.rows;
    // Kelivo-style history window: only the most recent rows are rendered on
    // entry; older history is revealed page-by-page near the top.
    final rows = hiddenRows > 0 ? allRows.sublist(hiddenRows) : allRows;
    final headerCount = _headerCount;
    final loaderCount = _loaderCount;
    // Stable row-key → index map for `findChildIndexCallback`: when a history
    // reveal prepends rows, the sliver re-maps the existing elements to their
    // shifted indices instead of rebuilding every visible row as a different
    // message (which flashed skeletons and lost the scroll anchor).
    final rowIndexByKey = <String, int>{
      for (var i = 0; i < rows.length; i++) rows[i].first: i,
    };
    final selectedIds = isSelecting
        ? ref.watch(messageSelectionProvider.select((s) => s.selectedIds))
        : const <String>{};

    // Listen for scroll-to-message requests from the mini map.
    ref.listen<String?>(scrollToMessageIdProvider, (prev, messageId) {
      if (messageId == null) return;
      ref.read(scrollToMessageIdProvider.notifier).clear();
      _scrollToMessageFromMiniMap(messageId);
    });

    // 消息分割线 (设置 tab 常规设置)：开启时在相邻消息之间画一条分割线。
    final showDivider = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.showMessageDivider),
    );
    final isPlain = ref.watch(
      sidebarSettingsControllerProvider.select(
        (s) => s.messageStyle == MessageStyle.plain,
      ),
    );
    // Report the visible message count and live scroll state to the performance
    // monitor, so scroll jank can be attributed to "/chat scrolling". Both are
    // no-ops while the monitor is stopped.
    PerfMonitor.instance.setMessages(allRows.length);
    // 消息可选中复制: a tap anywhere in the list clears a lingering text
    // selection held by a message's [MessageSelectionArea] (each message wraps
    // its own small SelectionArea, so a tap on another bubble / blank space
    // never reaches the area holding the selection).
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) =>
          MessageSelectionArea.clearOutside(event.position),
      child: NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) {
          PerfMonitor.instance.setScrolling(true);
          DeferredContentScheduler.instance.setScrolling(true);
        } else if (n is ScrollEndNotification) {
          PerfMonitor.instance.setScrolling(false);
          DeferredContentScheduler.instance.setScrolling(false);
        } else if (n is ScrollUpdateNotification && n.depth == 0) {
          _maybeRevealMore(n.metrics);
        }
        return false;
      },
      child: ListViewObserver(
        controller: _observerController,
        child: ListView.builder(
          controller: _scrollController,
        // 千问式拦截：禁用焦点 / showOnScreen 驱动的隐式滚动，气泡内
        // 文本选择、可聚焦控件获焦都不再拉动列表。
        physics: const NoImplicitScrollPhysics(),
        // QQ getExtraLayoutSpace pattern: enlarged only while a navigation
        // jump is in flight (so the glide path is pre-built); the framework
        // default otherwise, keeping off-viewport layout and memory small.
        scrollCacheExtent: _navCacheBoost
            ? const ScrollCacheExtent.viewport(1)
            : null,
        padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + widget.bottomReserve),
        itemCount: rows.length + headerCount + loaderCount,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final rowIndex = rowIndexByKey[key.value];
          if (rowIndex == null) return null;
          return rowIndex + headerCount + loaderCount;
        },
        itemBuilder: (context, index) {
          // A slim spinner tops the list while older history is hidden — it
          // loads in as the user scrolls up (WeChat-style), never eagerly.
          if (loaderCount == 1 && index == 0) {
            return const _HistoryLoadingRow();
          }
          // The system-prompt bubble is the first item when enabled; it scrolls
          // with the list and is never part of multi-select.
          if (headerCount == 1 && index == 0) {
            return const SystemPromptBubble();
          }
          final rowIndex = index - headerCount - loaderCount;
          final row = rows[rowIndex];
          // A multi-member row is a multi-model 对比 group; a single-member row is
          // an ordinary message.
          Widget item;
          if (row.length > 1) {
            item = MultiModelMessageGroup(
              key: ValueKey('group:${row.join(',')}'),
              memberIds: row,
            );
          } else {
            final id = row.first;
            // Stable per-message key so Flutter's element diff reuses the
            // existing bubble across appends/reorders.
            final Widget bubble = isPlain
                ? PlainStyleMessage(key: ValueKey(id), messageId: id)
                : ChatMessageBubble(key: ValueKey(id), messageId: id);
            // Wrap with selection checkbox when in multi-select mode.
            item = isSelecting
                ? _SelectableMessageRow(
                    messageId: id,
                    selected: selectedIds.contains(id),
                    child: bubble,
                  )
                : bubble;
          }

          // Heavy terminal bubbles first mount as a skeleton and materialize
          // over the following frames — the frame that runs the page
          // transition never pays for a giant bubble's build.
          if (!isSelecting) {
            item = _DeferredBubble(rowIds: row, child: item);
          }

          // Navigation landing flash (web scrollToMessage's 1.6s highlight).
          item = _NavFlashHighlight(messageId: row.first, child: item);

          // Plain style uses its own bottom border; bubble style uses a Divider
          // when the setting is on.
          final needsDivider =
              isPlain || (showDivider && rowIndex < rows.length - 1);
          // The stable per-row key on the sliver's direct child is what
          // `findChildIndexCallback` resolves, keeping elements (and their
          // keep-alive / deferred state) across history reveals.
          final rowKey = ValueKey<String>(row.first);
          if (!needsDivider) return _KeepAliveItem(key: rowKey, child: item);
          final dividerColor = Theme.of(context).brightness == Brightness.dark
              ? const Color(0x1AFFFFFF)
              : const Color(0x14000000);
          return _KeepAliveItem(
            key: rowKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item,
                Divider(height: 1, thickness: 1, color: dividerColor),
              ],
            ),
          );
        },
          ),
        ),
      ),
    );
  }
}

/// Defers a whole message row's first build behind a skeleton bubble.
///
/// Row-count windowing and in-bubble [DeferredContent] still leave one cost
/// on the entry frame: assembling the bubble chrome + parsing its (possibly
/// many) blocks — a single multi-round tool-call message can blow the frame
/// budget alone. Heavy *terminal* rows therefore mount as a fixed-height
/// skeleton and are swapped in by [DeferredContentScheduler] over the next
/// frames (LIFO — rows near the viewport first). Streaming / cheap rows
/// build inline so live output and short chats never flash a skeleton.
/// [_KeepAliveItem] keeps materialized rows alive, so this only ever happens
/// on the row's first mount (topic entry / history reveal).
class _DeferredBubble extends ConsumerStatefulWidget {
  const _DeferredBubble({required this.rowIds, required this.child});

  final List<String> rowIds;
  final Widget child;

  /// Rows costing at most this (≈ source characters) build inline.
  static const int _inlineCostThreshold = 2000;

  @override
  ConsumerState<_DeferredBubble> createState() => _DeferredBubbleState();
}

class _DeferredBubbleState extends ConsumerState<_DeferredBubble> {
  bool _materialized = false;
  DeferredContentEntry? _entry;
  double? _compensateFrom;
  double _estimatedHeight = 120;

  @override
  void initState() {
    super.initState();
    final state = ref.read(chatControllerProvider);
    var cost = 0;
    var terminal = true;
    for (final id in widget.rowIds) {
      final view = state.messageById(id);
      if (view == null) continue;
      if (view.status != MessageStatus.success &&
          view.status != MessageStatus.error) {
        terminal = false;
        break;
      }
      cost += view.text.length + view.thinking.length + view.blocks.length * 300;
    }
    if (!terminal || cost <= _DeferredBubble._inlineCostThreshold) {
      _materialized = true;
      return;
    }
    _estimatedHeight = (cost * 0.5).clamp(120.0, 2000.0);
    // The bubble's own build is cheap once its heavy content re-defers
    // internally (chunked markdown / code placeholders) — enqueue at a capped
    // cost so a giant bubble doesn't starve the scheduler for many frames.
    _entry = DeferredContentScheduler.instance.enqueue(
      math.min(cost, 3000),
      _materialize,
    );
  }

  void _materialize() {
    _entry = null;
    if (!mounted) return;
    _compensateFrom = materializationBaseline(context);
    setState(() => _materialized = true);
  }

  @override
  void dispose() {
    _entry?.cancel();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_materialized) {
      final baseline = _compensateFrom;
      if (baseline == null) return widget.child;
      return MaterializationShift(previousExtent: baseline, child: widget.child);
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        width: double.infinity,
        height: _estimatedHeight,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// The slim spinner row shown above the rendered window while older history
/// is still hidden (revealed page-by-page as the user scrolls up).
class _HistoryLoadingRow extends StatelessWidget {
  const _HistoryLoadingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Flashes a translucent primary tint over the message a navigation jump
/// landed on (web scrollToMessage's highlight), fading back out when
/// [navHighlightMessageIdProvider] clears after 1.6s. Watches with a select
/// on its own id, so only the affected row rebuilds.
class _NavFlashHighlight extends ConsumerWidget {
  const _NavFlashHighlight({required this.messageId, required this.child});

  final String messageId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      navHighlightMessageIdProvider.select((id) => id == messageId),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      color: active
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: child,
    );
  }
}

/// Keeps a message row's element tree alive when it scrolls out of the
/// viewport cache, mirroring the web's resident DOM. Rebuilding a long
/// markdown bubble from scratch takes 100ms+ on a single frame (the dominant
/// jank source measured on-device); keeping it alive makes re-entry free.
class _KeepAliveItem extends StatefulWidget {
  const _KeepAliveItem({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAliveItem> createState() => _KeepAliveItemState();
}

class _KeepAliveItemState extends State<_KeepAliveItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A message row with a leading checkbox, shown during multi-select mode.
class _SelectableMessageRow extends ConsumerWidget {
  const _SelectableMessageRow({
    required this.messageId,
    required this.selected,
    required this.child,
  });

  final String messageId;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          ref.read(messageSelectionProvider.notifier).toggleMessage(messageId),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                key: ValueKey(selected),
                size: 22,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          Expanded(child: IgnorePointer(child: child)),
        ],
      ),
    );
  }
}
