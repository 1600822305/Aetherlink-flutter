import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a "免确认" (skip-confirmation) window granted from the confirm
/// bar lasts. Scoped to a single tool within the current conversation.
///
///  * [none] — approve only this single operation (the default).
///  * [fiveMinutes] — auto-approve further calls of *this same tool* for the
///    next 5 minutes (other tools still prompt).
enum ConfirmationGrace { none, fiveMinutes }

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
  /// window is keyed by this + [toolName] so it never leaks into other
  /// conversations or other tools.
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

  /// Active 免确认 windows, keyed by `conversationId::toolName` → expiry instant.
  /// Scoped per (conversation, tool) so granting it for one tool never
  /// auto-approves a different tool or another conversation.
  final _grace = <String, DateTime>{};

  @override
  Map<String, ToolConfirmationRequest> build() => const {};

  static String _graceKey(String conversationId, String toolName) =>
      '$conversationId::$toolName';

  /// Whether [toolName] in [conversationId] currently has an active 免确认
  /// window, letting that tool run without prompting. Prunes expired windows.
  bool isGraceActive(String conversationId, String toolName) {
    final key = _graceKey(conversationId, toolName);
    final until = _grace[key];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _grace.remove(key); // 已过期
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
  /// *this request's tool* so subsequent calls of that same tool auto-run.
  void respond(
    String requestId, {
    required bool approved,
    ConfirmationGrace grace = ConfirmationGrace.none,
  }) {
    final req = state[requestId];
    if (approved && grace == ConfirmationGrace.fiveMinutes && req != null) {
      _grace[_graceKey(req.conversationId, req.toolName)] =
          DateTime.now().add(const Duration(minutes: 5));
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
