import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

/// Placeholder [ChatRepository] implementation.
///
/// Wiring to Drift (persistence) and dio (LLM client) lands in later
/// milestones; until then every method throws [UnimplementedError]. Its job in
/// this scaffold is only to prove the `data` → `domain` dependency-inversion
/// wiring compiles.
class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl();

  @override
  Future<void> warmUp() => throw UnimplementedError();
}
