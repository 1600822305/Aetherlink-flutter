import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';

/// A node on the active path, oldest first, as seen by the timer clock.
/// [isUserTurn] / [isAssistantTurn] mark real chat messages (both counted, like
/// ST `chat.length`); [isSummary] marks a context compression summary, which is
/// not counted itself but carries the state of the messages it replaced.
typedef WorldBookPathNode = ({
  bool isUserTurn,
  bool isAssistantTurn,
  bool isSummary,
  Map<String, dynamic>? metadata,
});

/// The clock inputs for the user message that follows [ancestors]: the
/// inherited timer state and that message's number (ST `chat.length` when the
/// world info is evaluated, the new user message included).
typedef WorldBookClock = ({WorldBookActivationState previous, int turn});

bool _counts(WorldBookPathNode n) =>
    !n.isSummary && (n.isUserTurn || n.isAssistantTurn);

/// Resolves the clock for a new user message whose ancestors (root excluded,
/// oldest first, **without** the new message itself) are [ancestors].
///
/// Single backward pass (O(n)): the nearest node carrying a state — a user
/// message, or a summary that inherited one — supplies `previous`; the message
/// number continues from that state's number plus the chat messages after it,
/// plus one for the new message. With no stored state anywhere it is the chat
/// message count + 1.
WorldBookClock resolveWorldBookClock(List<WorldBookPathNode> ancestors) {
  var after = 0;
  for (var i = ancestors.length - 1; i >= 0; i--) {
    final node = ancestors[i];
    if (node.isUserTurn || node.isSummary) {
      final state = WorldBookActivationState.fromMetadata(node.metadata);
      if (state != null) {
        return (previous: state, turn: state.turn + after + 1);
      }
    }
    if (_counts(node)) after++;
  }
  return (previous: WorldBookActivationState.empty, turn: after + 1);
}

/// The newest state among [metadataOldestFirst] — used to carry the state of
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
