import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_sidebar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_top_bar.dart';

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
    final theme = Theme.of(context);
    final stateAsync = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: const ChatTopBar(),
      drawer: const ChatSidebar(),
      body: SafeArea(
        top: false,
        // Background surface layer. The original layered a chat-background image
        // and a gradient overlay here; this round restores a solid themed
        // surface only (background-image loading is a later slice).
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Expanded(child: _MessageList(stateAsync: stateAsync)),
              const ChatInputBar(),
            ],
          ),
        ),
      ),
    );
  }
}

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
