import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/controllers/chat_auto_scroll_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by the native plugin. The "will" events snap the layout to the
  /// final height in a single frame — WeChat/QQ-style instant reposition, with
  /// the OS keyboard sliding up over the (opaque) area below the composer.
  /// The "did" events settle any residual mismatch once the animation ends;
  /// per-frame progress events are ignored (frame-synced panning reads as a
  /// slow transition rather than an instant snap).
  void _onKeyboardEvent(KeyboardEvent event) {
    if (!mounted) return;
    // Cancel any pending fallback — the plugin is authoritative.
    _fallbackTimer?.cancel();
    switch (event.type) {
      case KeyboardEventType.progress:
        break;
      case KeyboardEventType.willShow:
      case KeyboardEventType.didShow:
        if ((event.height - _keyboardHeight).abs() > 0.5) {
          setState(() => _keyboardHeight = event.height);
        }
      case KeyboardEventType.willHide:
      case KeyboardEventType.didHide:
        if (_keyboardHeight != 0) {
          setState(() => _keyboardHeight = 0);
        }
    }
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
      final rawBottom = view.viewInsets.bottom / view.devicePixelRatio;

      if (rawBottom < 1 && _keyboardHeight > 0) {
        // Keyboard is gone but we still think it's open — missed hide event.
        setState(() => _keyboardHeight = 0);
      } else if (rawBottom > 0 && _keyboardHeight < 1) {
        // Keyboard appeared but we missed the show event — use raw value.
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
    // math.max keeps the composer at the safe-area line while a low
    // (mid-animation) keyboard height is still below it.
    final bottomOffset = isTopRoute
        ? (keyboardActive
              ? math.max(_keyboardHeight - 8, viewPadding)
              : math.max(_keyboardHeight, viewPadding))
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
                // 对话导航：右侧呼吸灯 + 上下跳转面板（设置 tab → 对话导航）。
                if (!widget.isSelecting)
                  const Positioned.fill(child: ChatNavigationOverlay()),
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
      final hasError = ref.watch(
        chatControllerProvider.select((a) => a.hasError),
      );
      return hasError
          ? const _ErrorNotice()
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
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '加载消息失败',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
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
/// [ChatAutoScrollController] (the port of the web `ChatScrollController`); this
/// widget only owns the [ChatAutoFollowScrollController] and tells the state
/// machine which message change is an explicit pin:
/// * initial entry / switching topics (first-message id changes) / the user
///   sending (message count grows) → [ChatAutoScrollController.pinToBottom].
/// In-place growth such as streaming needs nothing here — the custom
/// [ChatAutoFollowScrollController] follows it during layout when sticking.
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
  final ChatAutoFollowScrollController _scrollController =
      ChatAutoFollowScrollController();
  late final ListObserverController _observerController;
  late final ChatAutoScrollController _autoScroll;

  /// Identifies the loaded conversation so a topic switch (first-message change)
  /// can be told apart from appends / in-place content growth. Tracked over the
  /// flattened message ids so multi-model groups don't confuse the heuristic.
  String? _firstId;
  int _count = 0;

  /// Every message id in display order (groups flattened) — for the autoscroll
  /// heuristic and mini-map scroll-to-message lookups.
  List<String> get _flatIds => [for (final row in widget.rows) ...row];

  @override
  void initState() {
    super.initState();
    _observerController = ListObserverController(controller: _scrollController)
      ..cacheJumpIndexOffset = false;
    _autoScroll = ChatAutoScrollController(
      scrollController: _scrollController,
      isEnabled: () =>
          ref.read(sidebarSettingsControllerProvider).autoScrollToBottom,
    );
    final ids = _flatIds;
    _firstId = ids.isEmpty ? null : ids.first;
    _count = ids.length;
    // Initial entry pins to the bottom (latest message), like the web's mount.
    _autoScroll.pinToBottom();
  }

  @override
  void didUpdateWidget(covariant _MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _flatIds;
    final firstId = ids.isEmpty ? null : ids.first;
    final count = ids.length;
    final topicSwitched = firstId != _firstId;
    final appended = !topicSwitched && count > _count;
    _firstId = firstId;
    _count = count;

    if (topicSwitched || appended) {
      _autoScroll.pinToBottom();
    }
  }

  @override
  void dispose() {
    _autoScroll.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Executes a 对话导航 action. 上一条/下一条 move relative to the first
  /// row currently visible (observed via [ListObserverController]), falling
  /// back to 回顶/回底 at the ends — mirroring the web `ChatNavigation`.
  Future<void> _handleNavigation(
    ChatNavigationAction action,
    int headerCount,
    int rowCount,
  ) async {
    switch (action) {
      case ChatNavigationAction.top:
        _autoScroll.unstick();
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      case ChatNavigationAction.bottom:
        _autoScroll.pinToBottom();
      case ChatNavigationAction.prevMessage:
      case ChatNavigationAction.nextMessage:
        final result = await _observerController.dispatchOnceObserve(
          isForce: true,
          isDependObserveCallback: false,
        );
        final firstIndex = result.observeResult?.firstChild?.index;
        if (firstIndex == null || !mounted) return;
        final delta = action == ChatNavigationAction.prevMessage ? -1 : 1;
        final target = firstIndex + delta;
        if (target < headerCount) {
          return _handleNavigation(
            ChatNavigationAction.top,
            headerCount,
            rowCount,
          );
        }
        if (target >= headerCount + rowCount) {
          return _handleNavigation(
            ChatNavigationAction.bottom,
            headerCount,
            rowCount,
          );
        }
        _autoScroll.unstick();
        await _observerController.animateTo(
          index: target,
          alignment: 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = widget.isSelecting;
    // Multi-select shows every message individually so each can be ticked; the
    // 对比 grouping only applies to the normal (read) view.
    final rows = isSelecting
        ? <List<String>>[
            for (final row in widget.rows)
              for (final id in row) <String>[id],
          ]
        : widget.rows;
    final headerCount = widget.showSystemPromptBubble ? 1 : 0;
    final selectedIds = isSelecting
        ? ref.watch(messageSelectionProvider.select((s) => s.selectedIds))
        : const <String>{};

    // Listen for scroll-to-message requests from the mini map.
    ref.listen<String?>(scrollToMessageIdProvider, (prev, messageId) {
      if (messageId == null) return;
      ref.read(scrollToMessageIdProvider.notifier).clear();
      final index = rows.indexWhere((row) => row.contains(messageId));
      if (index < 0) return;
      _autoScroll.unstick();
      _observerController.animateTo(
        index: index + headerCount,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });

    // 对话导航面板的回顶/上一条/下一条/回底请求。
    ref.listen<ChatNavigationAction?>(chatNavigationRequestProvider, (
      prev,
      action,
    ) {
      if (action == null) return;
      ref.read(chatNavigationRequestProvider.notifier).clear();
      _handleNavigation(action, headerCount, rows.length);
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
    PerfMonitor.instance.setMessages(rows.length);
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
        } else if (n is ScrollEndNotification) {
          PerfMonitor.instance.setScrolling(false);
        }
        return false;
      },
      child: ListViewObserver(
        controller: _observerController,
        child: ListView.builder(
          controller: _scrollController,
        padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + widget.bottomReserve),
        itemCount: rows.length + headerCount,
        itemBuilder: (context, index) {
          // The system-prompt bubble is the first item when enabled; it scrolls
          // with the list and is never part of multi-select.
          if (headerCount == 1 && index == 0) {
            return const SystemPromptBubble();
          }
          final rowIndex = index - headerCount;
          final row = rows[rowIndex];
          // A multi-member row is a multi-model 对比 group; a single-member row is
          // an ordinary message.
          final Widget item;
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

          // Plain style uses its own bottom border; bubble style uses a Divider
          // when the setting is on.
          final needsDivider =
              isPlain || (showDivider && rowIndex < rows.length - 1);
          if (!needsDivider) return item;
          final dividerColor = Theme.of(context).brightness == Brightness.dark
              ? const Color(0x1AFFFFFF)
              : const Color(0x14000000);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              item,
              Divider(height: 1, thickness: 1, color: dividerColor),
            ],
          );
        },
          ),
        ),
      ),
    );
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
