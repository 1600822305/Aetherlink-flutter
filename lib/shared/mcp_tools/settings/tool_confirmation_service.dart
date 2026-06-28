import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a "免确认" (skip-confirmation) window granted from the confirm
/// bar lasts, scoped to the current conversation.
///
///  * [none] — approve only this single operation (the default).
///  * [fiveMinutes] — auto-approve confirm-level tools for the next 5 minutes.
///  * [forever] — auto-approve for the rest of this conversation (no expiry).
enum ConfirmationGrace { none, fiveMinutes, forever }

/// A pending confirmation request shown in the chat UI.
class ToolConfirmationRequest {
  const ToolConfirmationRequest({
    required this.id,
    required this.conversationId,
    required this.toolName,
    required this.summary,
    required this.args,
  });

  /// Matches the tool block's `toolId` so the UI can associate them.
  final String id;

  /// The conversation (topic) this request belongs to. A granted 免确认
  /// window is keyed by this so it never leaks into other conversations.
  final String conversationId;
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

  /// Per-conversation 免确认 windows. A present key means a window is active
  /// for that conversation; a `null` value never expires ([ConfirmationGrace.
  /// forever]), a non-null value is the expiry instant ([ConfirmationGrace.
  /// fiveMinutes]). Scoped per conversation so it never leaks across topics.
  final _grace = <String, DateTime?>{};

  @override
  Map<String, ToolConfirmationRequest> build() => const {};

  /// Whether [conversationId] currently has an active 免确认 window, letting a
  /// confirm-level tool run without prompting. Prunes expired windows lazily.
  bool isGraceActive(String conversationId) {
    if (!_grace.containsKey(conversationId)) return false;
    final until = _grace[conversationId];
    if (until == null) return true; // 永久（本对话内）
    if (DateTime.now().isBefore(until)) return true;
    _grace.remove(conversationId); // 已过期
    return false;
  }

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

  /// Called by the UI when the user taps confirm or reject. When [approved] is
  /// true and [grace] isn't [ConfirmationGrace.none], opens a 免确认 window for
  /// this request's conversation so subsequent confirm-level tools auto-run.
  void respond(
    String requestId, {
    required bool approved,
    ConfirmationGrace grace = ConfirmationGrace.none,
  }) {
    final req = state[requestId];
    if (approved && grace != ConfirmationGrace.none && req != null) {
      _grace[req.conversationId] = switch (grace) {
        ConfirmationGrace.fiveMinutes =>
          DateTime.now().add(const Duration(minutes: 5)),
        ConfirmationGrace.forever => null,
        ConfirmationGrace.none => DateTime.now(),
      };
    }
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
