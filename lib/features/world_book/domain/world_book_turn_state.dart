import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';

/// A node on the active path, oldest first, as seen by the timer clock.
/// [isUserTurn] marks a real user turn (counted); [isSummary] marks a context
/// compression summary, which carries the state of the turns it replaced.
typedef WorldBookPathNode = ({
  bool isUserTurn,
  bool isSummary,
  Map<String, dynamic>? metadata,
});

/// The clock inputs for the turn that follows [ancestors]: the inherited
/// timer state and the new turn's 1-based number.
typedef WorldBookClock = ({WorldBookActivationState previous, int turn});

/// Resolves the clock for a new user turn whose ancestors (root excluded,
/// oldest first, **without** the new turn itself) are [ancestors].
///
/// Single backward pass (O(n)): the nearest node carrying a state — a user
/// turn, or a summary that inherited one — supplies `previous`, and the turn
/// number continues from that state's `turn` plus the user turns after it.
/// With no stored state anywhere, the turn number is the user-turn count + 1.
WorldBookClock resolveWorldBookClock(List<WorldBookPathNode> ancestors) {
  var userTurnsAfter = 0;
  for (var i = ancestors.length - 1; i >= 0; i--) {
    final node = ancestors[i];
    if (node.isUserTurn || node.isSummary) {
      final state = WorldBookActivationState.fromMetadata(node.metadata);
      if (state != null) {
        return (previous: state, turn: state.turn + userTurnsAfter + 1);
      }
    }
    if (node.isUserTurn) userTurnsAfter++;
  }
  return (previous: WorldBookActivationState.empty, turn: userTurnsAfter + 1);
}

/// The newest state among [nodes] (oldest first) — used to carry the state of
/// compressed messages onto their summary. Null when none carries one.
WorldBookActivationState? latestWorldBookState(
  List<Map<String, dynamic>?> metadataOldestFirst,
) {
  for (var i = metadataOldestFirst.length - 1; i >= 0; i--) {
    final state = WorldBookActivationState.fromMetadata(metadataOldestFirst[i]);
    if (state != null) return state;
  }
  return null;
}
