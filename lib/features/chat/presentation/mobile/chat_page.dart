import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';

/// Static UI strings. The original ran these through i18n; they are ported
/// verbatim as constants per the M4.1 approach — wiring up i18n is a separate
/// effort and out of scope for the skeleton.
const String _emptyConversationLabel = '对话开始了，请输入您的问题';
const String _inputHint = '和ai助手说点什么...';
const String _drawerPlaceholderLabel = '侧边栏';

/// The chat home page (mobile) — the third validation page after About (M4.0)
/// and Welcome (M4.1), and the ChatPage's "About-page moment": it stands up the
/// real layout shell and proves the presentation → application → repository →
/// Drift pipeline is connected, even with nothing to show yet.
///
/// It is a pure view: the message list and title come from application-layer
/// providers ([chatMessagesProvider] / [currentTopicProvider], backed by the M1
/// [ChatRepository]); an empty database yields an empty list rendered as the
/// empty state — no mock messages anywhere. It never imports `data` (Rule 1).
///
/// Sending, streaming, message-block rendering, the drawer's topic/assistant
/// lists and the peripheral actions (model selector, search, settings …) are
/// later slices (M4.2.1+). The widget tree is laid out in its final shape now
/// so those slices fill it in without rearranging it.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicAsync = ref.watch(currentTopicProvider);
    final messagesAsync = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.view_sidebar_outlined),
            tooltip: '打开侧边栏',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        // Dynamic title from the application layer; empty until a topic exists.
        title: topicAsync.maybeWhen(
          data: (topic) => topic == null
              ? const SizedBox.shrink()
              : Text(topic.name, overflow: TextOverflow.ellipsis),
          orElse: () => const SizedBox.shrink(),
        ),
        actions: const [
          // Right-side action placeholder. The model selector / search /
          // settings actions arrive in later slices; shown disabled here so
          // the bar's shape is final (no fake buttons).
          IconButton(icon: Icon(Icons.more_vert), onPressed: null),
        ],
      ),
      drawer: const _ChatDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _MessageList(messagesAsync: messagesAsync)),
            const _ChatInputBar(),
          ],
        ),
      ),
    );
  }
}

/// The scrollable message region. Reflects the real read provider: loading →
/// spinner, failure → error notice, empty → empty state, and (later) a list of
/// messages. Block rendering is M4.2.1.
class _MessageList extends StatelessWidget {
  const _MessageList({required this.messagesAsync});

  final AsyncValue<List<Message>> messagesAsync;

  @override
  Widget build(BuildContext context) {
    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const _ErrorNotice(),
      data: (messages) =>
          messages.isEmpty ? const _EmptyState() : _MessageListView(messages),
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

/// One row per message, keyed by author role. Message-block rendering (bubbles,
/// markdown, code, thinking …) is M4.2.1 — it replaces the row body without
/// changing this scrollable-list shape. With a fresh database this list is
/// empty, so the empty state shows instead.
class _MessageListView extends StatelessWidget {
  const _MessageListView(this.messages);

  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          ListTile(dense: true, title: Text(messages[index].role.name)),
    );
  }
}

/// Side drawer placeholder. Its content (topic / assistant lists) is a later
/// slice (M4.2.x); the skeleton only stands up the drawer shell.
class _ChatDrawer extends StatelessWidget {
  const _ChatDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Center(
          child: Text(
            _drawerPlaceholderLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom composer. The field accepts text (local UI state), but sending is
/// disabled — message sending is M4.2.2. Colors come from theme tokens.
class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar();

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppThemeExtension>()?.borderRadius ?? 8.0;

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: _inputHint,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sending is M4.2.2: present but disabled.
            const IconButton(
              icon: Icon(Icons.send),
              tooltip: '发送',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}
