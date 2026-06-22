import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pending confirmation request shown in the chat UI.
class ToolConfirmationRequest {
  const ToolConfirmationRequest({
    required this.id,
    required this.toolName,
    required this.summary,
    required this.args,
  });

  /// Matches the tool block's `toolId` so the UI can associate them.
  final String id;
  final String toolName;
  final String summary;
  final Map<String, Object?> args;
}

/// Manages pending tool-confirmation requests.
///
/// Flow:
///  1. Chat controller calls [request] before executing a `confirm`-level tool.
///  2. A [ToolConfirmationRequest] is added to [pending] and a [Completer] is
///     returned so the controller can `await` the user's decision.
///  3. The UI observes [pending] and renders confirm / reject buttons.
///  4. The user taps a button → [respond] completes the future.
///  5. 60 s timeout auto-rejects.
class ToolConfirmationNotifier
    extends Notifier<Map<String, ToolConfirmationRequest>> {
  final _completers = <String, Completer<bool>>{};
  final _timers = <String, Timer>{};

  @override
  Map<String, ToolConfirmationRequest> build() => const {};

  /// Register a new confirmation request and return a future that completes
  /// with `true` (approved) or `false` (rejected / timed-out).
  Future<bool> request(ToolConfirmationRequest req) {
    final completer = Completer<bool>();
    _completers[req.id] = completer;

    // Auto-reject after 60 seconds.
    _timers[req.id] = Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        completer.complete(false);
        _cleanup(req.id);
      }
    });

    state = {...state, req.id: req};
    return completer.future;
  }

  /// Called by the UI when the user taps confirm or reject.
  void respond(String requestId, {required bool approved}) {
    final completer = _completers[requestId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
    _cleanup(requestId);
  }

  /// Cancel all pending requests (e.g. when the streaming is aborted).
  void rejectAll() {
    for (final entry in _completers.entries) {
      if (!entry.value.isCompleted) entry.value.complete(false);
    }
    for (final t in _timers.values) {
      t.cancel();
    }
    _completers.clear();
    _timers.clear();
    state = const {};
  }

  void _cleanup(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    _completers.remove(id);
    state = Map.of(state)..remove(id);
  }
}

final toolConfirmationProvider =
    NotifierProvider<
      ToolConfirmationNotifier,
      Map<String, ToolConfirmationRequest>
    >(ToolConfirmationNotifier.new);
