import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// [selectTimedWorldBookEntries]'s result: the priority-sorted triggered
/// entries and the state to persist on this turn's user message.
typedef WorldBookTimedResult = ({
  List<WorldBookEntry> entries,
  WorldBookActivationState state,
});

/// Timer-aware activation (P3). [turn] is this request's 1-based user-turn
/// number on the active path; [previous] is the nearest ancestor's state.
///
/// Per entry, with `elapsed = turn - activatedAt` for a carried effect:
/// - `delay`: no fresh activation while `turn <= delay` (the first `delay`
///   user turns never trigger it; delay 0 = no restriction);
/// - `sticky`: after activating on turn A it stays injected through turn
///   `A + sticky` without re-matching;
/// - `cooldown`: for the `cooldown` turns after the sticky window it cannot
///   trigger, even on a keyword hit; afterwards it matches normally again.
/// Effects survive only while the entry's timer [signature] is unchanged.
/// Evaluating the same [turn] with the same [previous] is idempotent.
WorldBookTimedResult selectTimedWorldBookEntries({
  required List<WorldBook> books,
  required List<String> scanTexts,
  required int turn,
  WorldBookActivationState previous = WorldBookActivationState.empty,
}) {
  final texts = [
    for (final text in scanTexts)
      if (text.trim().isNotEmpty) text.trim(),
  ];
  final contextCache = <int, String>{};
  String contextFor(int depth) => contextCache.putIfAbsent(depth, () {
    final start = texts.length > depth ? texts.length - depth : 0;
    return texts.sublist(start).join('\n');
  });

  final effects = <String, WorldBookEffect>{};
  final triggered = <({WorldBookEntry entry, int seq})>[];
  var seq = 0;
  for (final book in books) {
    if (!book.enabled) continue;
    for (final entry in book.entries) {
      final order = seq++;
      if (!entry.enabled || entry.content.trim().isEmpty) continue;
      final timed = entry.sticky > 0 || entry.cooldown > 0;
      final key = jsonEncode([book.id, entry.id]);
      final signature = timed ? worldBookTimerSignature(entry) : '';
      final carried = previous.effects[key];
      final effect =
          timed && carried != null && carried.signature == signature
          ? carried
          : null;
      var active = false;
      if (effect != null && effect.activatedAt <= turn) {
        final elapsed = turn - effect.activatedAt;
        if (elapsed <= entry.sticky) {
          active = true;
          effects[key] = effect;
        } else if (elapsed <= entry.sticky + entry.cooldown) {
          effects[key] = effect;
          continue;
        }
      }
      if (!active) {
        if (turn <= entry.delay) continue;
        final depth = entry.scanDepth.clamp(1, WorldBookEntry.kMaxDepth);
        active = WorldBookActivation.matches(entry, contextFor(depth));
        if (active && timed) {
          effects[key] = WorldBookEffect(
            activatedAt: turn,
            signature: signature,
          );
        }
      }
      if (active) triggered.add((entry: entry, seq: order));
    }
  }
  triggered.sort((a, b) {
    final priority = b.entry.priority.compareTo(a.entry.priority);
    return priority != 0 ? priority : a.seq.compareTo(b.seq);
  });
  return (
    entries: [for (final item in triggered) item.entry],
    state: WorldBookActivationState(turn: turn, effects: effects),
  );
}

/// Fingerprint of the settings that govern an entry's timed effect; editing
/// any of them (or the trigger) resets the effect.
String worldBookTimerSignature(WorldBookEntry entry) =>
    sha256.convert(utf8.encode(jsonEncode(entry.toJson()))).toString();
