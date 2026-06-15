/// Contract for chat data access, owned by the `domain` layer and implemented
/// in `data` (dependency inversion; see `docs/ARCHITECTURE.md`).
///
/// Pure Dart: this file must not import Flutter / dio / drift / riverpod. The
/// real signatures (streaming reply, history persistence) land in milestones
/// M1–M2; [warmUp] is a structural placeholder proving the slice compiles.
abstract interface class ChatRepository {
  /// Placeholder lifecycle hook. Replaced by the real chat contract later.
  Future<void> warmUp();
}
