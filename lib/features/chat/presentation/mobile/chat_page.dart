import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';

/// Placeholder chat page (mobile).
///
/// Proves the `presentation` → `application` wiring: it only watches
/// [chatControllerProvider] and renders. It must never import `data` directly
/// (enforced by `test/architecture/import_boundaries_test.dart`). The real
/// message list / composer lands in milestone M4.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(child: Text('Chat scaffold ready: ${state.isReady}')),
    );
  }
}
