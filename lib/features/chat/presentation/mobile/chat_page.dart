import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_sidebar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_top_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/system_prompt_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

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
    final stateAsync = ref.watch(chatControllerProvider);
    // 系统提示词气泡显隐响应 聊天界面设置 的开关（PR #71 的「系统提示词气泡」）。
    final showSystemPromptBubble = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.showSystemPromptBubble),
    );
    // 聊天背景（图片/透明度/渐变遮罩/尺寸·位置·重复）接 聊天界面设置（PR #71）。
    final background = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.background),
    );

    return Scaffold(
      appBar: const ChatTopBar(),
      drawer: const ChatSidebar(),
      body: SafeArea(
        top: false,
        // Background layer. The original (`ChatPageUI.tsx`) layers a
        // chat-background image (opacity applied directly) and an optional
        // white readability gradient behind the message area; [_ChatBackground]
        // ports that 1:1 and falls back to a solid themed surface when disabled.
        child: _ChatBackground(
          background: background,
          child: Column(
            children: [
              if (showSystemPromptBubble) ...const [
                SizedBox(height: 8),
                SystemPromptBubble(),
              ],
              Expanded(child: _MessageList(stateAsync: stateAsync)),
              const ChatInputBar(),
            ],
          ),
        ),
      ),
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
  const _MessageList({required this.stateAsync});

  final AsyncValue<ChatState> stateAsync;

  @override
  Widget build(BuildContext context) {
    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const _ErrorNotice(),
      data: (state) => state.messages.isEmpty
          ? const _EmptyState()
          : _MessageListView(state.messages),
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
/// `main_text` blocks through the real provider and aligns by role. Markdown,
/// the other 14 block variants, sending and streaming are later slices that
/// extend the bubble without changing this scrollable-list shape. With a fresh
/// database this list is empty, so the empty state shows instead.
class _MessageListView extends StatelessWidget {
  const _MessageListView(this.messages);

  final List<ChatMessageView> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => ChatMessageBubble(view: messages[index]),
    );
  }
}
