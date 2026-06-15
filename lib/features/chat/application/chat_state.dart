/// Placeholder state for the chat feature's application layer.
///
/// The real state (message-block list, streaming status, etc.) is defined in
/// milestone M2 (see `docs/ARCHITECTURE.md` §4). For now it only carries an
/// [isReady] flag so the presentation layer has something to `watch`.
class ChatState {
  const ChatState({required this.isReady});

  const ChatState.initial() : isReady = false;

  final bool isReady;
}
