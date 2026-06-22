import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/controllers/chat_auto_scroll_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_selection_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/plain_style_message.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/chat_sidebar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_top_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/system_prompt_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';
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

/// Extra height above the reserved input gap over which the message list fades
/// into the background, so messages dissolve under the floating composer rather
/// than meeting it at a hard line (the kelivo-style fusion).
const double _kBottomFadeBand = 96;

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
    final stateAsync = ref.watch(chatControllerProvider);
    final showSystemPromptBubble = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.showSystemPromptBubble),
    );
    final background = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.background),
    );
    final isSelecting = ref.watch(
      messageSelectionProvider.select((s) => s.isSelecting),
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
            background: background,
            child: _ChatBody(
              showSystemPromptBubble: showSystemPromptBubble,
              stateAsync: stateAsync,
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
    required this.stateAsync,
    this.isSelecting = false,
  });

  final bool showSystemPromptBubble;
  final AsyncValue<ChatState> stateAsync;
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

  /// Called by the native plugin. Layout updates only on the "will" events
  /// (before the OS animation starts), matching the original KeyboardManager.
  void _onKeyboardEvent(KeyboardEvent event) {
    if (!mounted) return;
    // Cancel any pending fallback — the plugin is authoritative.
    _fallbackTimer?.cancel();
    switch (event.type) {
      case KeyboardEventType.willShow:
        if ((event.height - _keyboardHeight).abs() > 0.5) {
          setState(() => _keyboardHeight = event.height);
        }
      case KeyboardEventType.willHide:
        if (_keyboardHeight != 0) {
          setState(() => _keyboardHeight = 0);
        }
      case KeyboardEventType.didShow:
      case KeyboardEventType.didHide:
        break;
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
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    // When the keyboard is showing, subtract the InputBoxComposer's internal
    // bottom padding (8px) so the card sits flush against the keyboard — no
    // visible gap — matching the original's `position: fixed; bottom:
    // var(--keyboard-height)`.
    final keyboardActive = isTopRoute && _keyboardHeight > 0;
    final bottomOffset = isTopRoute
        ? (keyboardActive
              ? _keyboardHeight - 8
              : math.max(_keyboardHeight, viewPadding))
        : viewPadding;

    return Column(
      children: [
        if (widget.showSystemPromptBubble) ...const [
          SizedBox(height: 8),
          SystemPromptBubble(),
        ],
        Expanded(
          child: NotificationListener<SizeChangedLayoutNotification>(
            onNotification: (_) {
              _scheduleMeasure();
              return false;
            },
            child: Stack(
              children: [
                // Fuse the list into the composer (kelivo style): the list fills
                // the body and reserves room at the bottom so its tail clears
                // the floating input + keyboard, while a bottom gradient fades
                // the messages out into the background behind the transparent
                // input — no hard seam between the scroll area and the composer.
                //
                // fadeHeight intentionally excludes the keyboard offset so the
                // ShaderMask's shader rect stays constant during the keyboard
                // transition — only the cheaper ListView padding changes.
                Positioned.fill(
                  child: _FadeToBottom(
                    fadeHeight: widget.isSelecting
                        ? 0
                        : _inputHeight + _kBottomFadeBand,
                    child: _MessageList(
                      stateAsync: widget.stateAsync,
                      bottomReserve: widget.isSelecting
                          ? 120 + viewPadding
                          : _inputHeight + 16 + bottomOffset,
                      isSelecting: widget.isSelecting,
                    ),
                  ),
                ),
                if (widget.isSelecting)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MessageSelectionBottomBar(),
                  )
                else
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
            ),
          ),
        ),
      ],
    );
  }
}

/// Fades its child's bottom [fadeHeight] pixels to transparent so the message
/// list dissolves into the background ([_ChatBackground], which fills the body
/// behind this) under the floating transparent composer — the kelivo-style
/// fusion. A [BlendMode.dstIn] mask keeps the child fully opaque above the band
/// and ramps it out toward the bottom (the curve mirrors kelivo's overlay fade,
/// expressed here as the complementary keep-alpha).
class _FadeToBottom extends StatelessWidget {
  const _FadeToBottom({required this.fadeHeight, required this.child});

  final double fadeHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Isolate the list as a single cached raster layer so the keyboard
    // animation's per-frame mask recomposite samples that texture instead of
    // replaying every bubble's paint — closing part of the gap with the web's
    // GPU-composited CSS gradient mask.
    final isolated = RepaintBoundary(child: child);
    if (fadeHeight <= 0) return isolated;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final height = rect.height;
        final fraction = height <= 0
            ? 0.0
            : (fadeHeight / height).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 1.0 - fraction, 1.0 - 0.52 * fraction, 1.0],
          colors: const [
            Color(0xFFFFFFFF), // keep fully
            Color(0xFFFFFFFF), // …up to where the fade band begins
            Color(0x2EFFFFFF), // ~0.18 keep (≈ kelivo's 0.82 cover at 48%)
            Color(0x05FFFFFF), // ~0.02 keep (≈ kelivo's 0.98 cover at the foot)
          ],
        ).createShader(rect);
      },
      child: isolated,
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
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.stateAsync,
    this.bottomReserve = 0,
    this.isSelecting = false,
  });

  final AsyncValue<ChatState> stateAsync;

  /// Extra bottom padding so the list's tail clears the composer floating over
  /// it (the composer's measured height; see [_ChatBodyState]).
  final double bottomReserve;

  final bool isSelecting;

  @override
  Widget build(BuildContext context) {
    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const _ErrorNotice(),
      data: (state) => state.messages.isEmpty
          ? const _EmptyState()
          : _MessageListView(
              state.messages,
              bottomReserve: bottomReserve,
              isSelecting: isSelecting,
            ),
    );
  }
}

/// Empty-state placeholder shown when the current topic has no messages (the
/// fresh-install case). Text color is a theme token.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _emptyConversationLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
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
    this.messages, {
    this.bottomReserve = 0,
    this.isSelecting = false,
  });

  final List<ChatMessageView> messages;

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
  /// can be told apart from appends / in-place content growth.
  String? _firstId;
  int _count = 0;

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
    _firstId = widget.messages.isEmpty ? null : widget.messages.first.id;
    _count = widget.messages.length;
    // Initial entry pins to the bottom (latest message), like the web's mount.
    _autoScroll.pinToBottom();
  }

  @override
  void didUpdateWidget(covariant _MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final messages = widget.messages;
    final firstId = messages.isEmpty ? null : messages.first.id;
    final count = messages.length;
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

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    final isSelecting = widget.isSelecting;
    final selectedIds = isSelecting
        ? ref.watch(messageSelectionProvider.select((s) => s.selectedIds))
        : const <String>{};

    // Listen for scroll-to-message requests from the mini map.
    ref.listen<String?>(scrollToMessageIdProvider, (prev, messageId) {
      if (messageId == null) return;
      ref.read(scrollToMessageIdProvider.notifier).clear();
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index < 0) return;
      _autoScroll.unstick();
      _observerController.animateTo(
        index: index,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
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
    return ListViewObserver(
      controller: _observerController,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + widget.bottomReserve),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final view = messages[index];
          final Widget bubble = isPlain
              ? PlainStyleMessage(view: view)
              : ChatMessageBubble(view: view);

          // Wrap with selection checkbox when in multi-select mode.
          final Widget item = isSelecting
              ? _SelectableMessageRow(
                  messageId: view.id,
                  selected: selectedIds.contains(view.id),
                  child: bubble,
                )
              : bubble;

          // Plain style uses its own bottom border; bubble style uses a Divider
          // when the setting is on.
          final needsDivider =
              isPlain || (showDivider && index < messages.length - 1);
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
