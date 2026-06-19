import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/controllers/chat_auto_scroll_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_sidebar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_top_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/system_prompt_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

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

    // Freeze the chat behind any pushed dialog / bottom sheet. When this page is
    // no longer the top-most route, ignore the keyboard inset so focusing a text
    // field inside an overlay (创建分组 prompt, 编辑消息 sheet, …) doesn't shove the
    // composer + message list upward — that keyboard belongs to the overlay, not
    // the chat. Reading the inset here is what makes the Scaffold re-evaluate the
    // instant an overlay opens/closes the keyboard (a pushed route alone wouldn't
    // rebuild this page).
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;

    // The sidebar is hosted by [SidebarHost] (not `Scaffold.drawer`) so its
    // display style can switch between overlay and push (侧边栏显示方式); the
    // chat page itself stays a plain Scaffold behind it. Buzz when the sidebar
    // opens (gated by the 触觉反馈 master + 侧边栏 toggle), matching the original
    // drawer-open haptic.
    return SidebarHost(
      drawer: const ChatSidebar(),
      onOpened: Haptics.instance.onSidebar,
      child: Scaffold(
        resizeToAvoidBottomInset: isTopRoute || keyboardInset == 0,
        appBar: const ChatTopBar(),
        body: _ChatBackground(
          background: background,
          child: _ChatBody(
            showSystemPromptBubble: showSystemPromptBubble,
            stateAsync: stateAsync,
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
  });

  final bool showSystemPromptBubble;
  final AsyncValue<ChatState> stateAsync;

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  final GlobalKey _inputKey = GlobalKey();
  double _inputHeight = 0;

  /// Guards against queuing more than one pending measure: the composer's
  /// [SizeChangedLayoutNotifier] fires on several consecutive frames while the
  /// keyboard animates the bottom safe-area inset to zero, and scheduling a
  /// fresh post-frame callback for each one would rebuild [_ChatBody] repeatedly
  /// mid-animation. Collapsing them to a single pending measure cuts that churn.
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
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
                // the body and reserves `inputHeight + 16` at the bottom so its
                // tail clears the floating input, while a bottom gradient fades
                // the messages out into the background behind the transparent
                // input — no hard seam between the scroll area and the composer.
                Positioned.fill(
                  child: _FadeToBottom(
                    fadeHeight: _inputHeight + _kBottomFadeBand,
                    child: _MessageList(
                      stateAsync: widget.stateAsync,
                      bottomReserve: _inputHeight + 16,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizeChangedLayoutNotifier(
                    child: KeyedSubtree(
                      key: _inputKey,
                      // Only the composer carries the bottom safe-area inset, so
                      // the wallpaper behind it still reaches the screen edge.
                      child: const SafeArea(top: false, child: ChatInputBar()),
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
  const _MessageList({required this.stateAsync, this.bottomReserve = 0});

  final AsyncValue<ChatState> stateAsync;

  /// Extra bottom padding so the list's tail clears the composer floating over
  /// it (the composer's measured height; see [_ChatBodyState]).
  final double bottomReserve;

  @override
  Widget build(BuildContext context) {
    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const _ErrorNotice(),
      data: (state) => state.messages.isEmpty
          ? const _EmptyState()
          : _MessageListView(state.messages, bottomReserve: bottomReserve),
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
  const _MessageListView(this.messages, {this.bottomReserve = 0});

  final List<ChatMessageView> messages;

  /// Reserves room under the last bubble for the composer floating over the
  /// list (mirrors the original `messageContainer` `paddingBottom`).
  final double bottomReserve;

  @override
  ConsumerState<_MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends ConsumerState<_MessageListView> {
  final ChatAutoFollowScrollController _scrollController =
      ChatAutoFollowScrollController();
  late final ChatAutoScrollController _autoScroll;

  /// Identifies the loaded conversation so a topic switch (first-message change)
  /// can be told apart from appends / in-place content growth.
  String? _firstId;
  int _count = 0;

  @override
  void initState() {
    super.initState();
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
    // 消息分割线 (设置 tab 常规设置)：开启时在相邻消息之间画一条分割线。
    final showDivider = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.showMessageDivider),
    );
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + widget.bottomReserve),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final bubble = ChatMessageBubble(view: messages[index]);
        if (!showDivider || index == messages.length - 1) return bubble;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bubble,
            const Divider(height: 17, thickness: 1, indent: 12, endIndent: 12),
          ],
        );
      },
    );
  }
}
