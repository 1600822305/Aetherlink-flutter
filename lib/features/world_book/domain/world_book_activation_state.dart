import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';

/// One entry's timed effect: the user turn it last activated on, plus the
/// [signature] of its timer settings so an edited entry starts fresh.
class WorldBookEffect {
  const WorldBookEffect({required this.activatedAt, this.signature = ''});

  final int activatedAt;
  final String signature;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'activatedAt': activatedAt,
    'signature': signature,
  };

  static WorldBookEffect? tryParse(Object? raw) {
    if (raw is! Map<dynamic, dynamic>) return null;
    final at = raw['activatedAt'];
    if (at is! num) return null;
    final signature = raw['signature'];
    return WorldBookEffect(
      activatedAt: at.toInt(),
      signature: signature is String ? signature : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorldBookEffect &&
      other.activatedAt == activatedAt &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(activatedAt, signature);
}

/// The 世界书 timer state persisted on a user message's metadata under
/// [kWorldBookActivationMetadataKey] (P3).
///
/// [turn] is the 1-based count of real user turns on the active path up to and
/// including the owning message; [effects] are keyed by
/// `jsonEncode([bookId, entryId])` (the kelivo key, kept for compatibility).
///
/// [fromJson] never throws: it also reads the legacy kelivo / P0 shape
/// (`messageCount` + `historyHash` + `effects`), mapping `messageCount` onto
/// [turn], and degrades malformed input to [empty].
class WorldBookActivationState {
  const WorldBookActivationState({
    required this.turn,
    this.effects = const <String, WorldBookEffect>{},
  });

  static const WorldBookActivationState empty = WorldBookActivationState(
    turn: 0,
  );

  static const int kVersion = 2;

  final int turn;
  final Map<String, WorldBookEffect> effects;

  bool get isEmpty => turn == 0 && effects.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': kVersion,
    'turn': turn,
    'effects': {
      for (final entry in effects.entries) entry.key: entry.value.toJson(),
    },
  };

  static WorldBookActivationState fromJson(Object? raw) {
    if (raw is! Map<dynamic, dynamic>) return empty;
    final rawTurn = raw['turn'] ?? raw['messageCount'];
    final turn = rawTurn is num && rawTurn >= 0 ? rawTurn.toInt() : 0;
    final rawEffects = raw['effects'];
    final effects = <String, WorldBookEffect>{};
    if (rawEffects is Map<dynamic, dynamic>) {
      for (final entry in rawEffects.entries) {
        final key = entry.key;
        final effect = WorldBookEffect.tryParse(entry.value);
        if (key is String && effect != null && effect.activatedAt <= turn) {
          effects[key] = effect;
        }
      }
    }
    return WorldBookActivationState(turn: turn, effects: effects);
  }

  /// Reads the state stored in a message's [metadata], or null when absent.
  static WorldBookActivationState? fromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    final raw = metadata?[kWorldBookActivationMetadataKey];
    return raw == null ? null : fromJson(raw);
  }

  /// [metadata] with this state written under the activation key.
  Map<String, dynamic> writeTo(Map<String, dynamic>? metadata) =>
      <String, dynamic>{
        ...?metadata,
        kWorldBookActivationMetadataKey: toJson(),
      };
}
