import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';

/// One entry's timed effect (ST `chat_metadata.timedWorldInfo`)：
/// - [activatedAt]：激活时的消息序号（ST `start`）；
/// - [cooldownFrom]：持续结束、冷却开始时的消息序号（ST 在持续到期时以当时的
///   `chat.length` 重新起算冷却）；没有持续的条目冷却从 [activatedAt] 算，为 null；
/// - [signature]：条目指纹，编辑过的条目重新开始。
class WorldBookEffect {
  const WorldBookEffect({
    required this.activatedAt,
    this.signature = '',
    this.cooldownFrom,
  });

  final int activatedAt;
  final String signature;
  final int? cooldownFrom;

  WorldBookEffect withCooldownFrom(int from) => WorldBookEffect(
    activatedAt: activatedAt,
    signature: signature,
    cooldownFrom: from,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'activatedAt': activatedAt,
    'signature': signature,
    'cooldownFrom': ?cooldownFrom,
  };

  static WorldBookEffect? tryParse(Object? raw) {
    if (raw is! Map<dynamic, dynamic>) return null;
    final at = raw['activatedAt'];
    if (at is! num) return null;
    final signature = raw['signature'];
    final from = raw['cooldownFrom'];
    return WorldBookEffect(
      activatedAt: at.toInt(),
      signature: signature is String ? signature : '',
      cooldownFrom: from is num ? from.toInt() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorldBookEffect &&
      other.activatedAt == activatedAt &&
      other.signature == signature &&
      other.cooldownFrom == cooldownFrom;

  @override
  int get hashCode => Object.hash(activatedAt, signature, cooldownFrom);
}

/// The 世界书 timer state persisted on a user message's metadata under
/// [kWorldBookActivationMetadataKey] (P3).
///
/// [turn] is the **message number** of the owning user message on the active
/// path — ST `chat.length` at generation time: user and assistant messages up
/// to and including it (see [resolveWorldBookClock]). [effects] are keyed by
/// `jsonEncode([bookId, entryId])`.
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

  static const int kVersion = 3;

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
