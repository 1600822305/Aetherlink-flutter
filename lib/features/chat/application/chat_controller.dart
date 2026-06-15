import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';

part 'chat_controller.g.dart';

/// Placeholder Riverpod controller for the chat feature.
///
/// Proves the `application` layer wiring (codegen + DI) end to end. The real
/// orchestration — calling use cases, subscribing to the streaming reply,
/// throttling tokens — lands in milestone M2 (see `docs/ARCHITECTURE.md` §4).
@riverpod
class ChatController extends _$ChatController {
  @override
  ChatState build() => const ChatState.initial();
}
