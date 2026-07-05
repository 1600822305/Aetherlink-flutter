import 'dart:math';

import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';

/// Multi-key load balancing + failover for a provider's [ApiKeyConfig] pool.
///
/// One-to-one port of the Web `ApiKeyManager` (`src/shared/services/ai/
/// ApiKeyManager.ts`): given the enabled keys it picks one per request using the
/// configured [LoadBalanceStrategy], tracks per-key usage so the multi-key UI's
/// stats stop reading zero, and pushes a key into a cooldown after repeated
/// failures so the request layer fails over to the next key.
///
/// Selection (round-robin index) state is held in this process-wide singleton so
/// it survives the controller being rebuilt between sends, exactly like the Web
/// `getInstance()` singleton. The per-key counters/status live on the persisted
/// [ApiKeyConfig]s — [updateKeyStatus] returns a new immutable config the caller
/// saves through the model store — so they round-trip across app restarts.
class ApiKeyManager {
  ApiKeyManager._();

  static final ApiKeyManager instance = ApiKeyManager._();

  /// Five-minute cooldown applied to a key after it trips into `error`, matching
  /// the Web `isKeyInCooldown` constant (`5 * 60 * 1000` ms).
  static const Duration cooldown = Duration(minutes: 5);

  /// Consecutive failures that flip a key to `error` (Web hardcodes `>= 3`).
  static const int maxConsecutiveFailures = 3;

  /// Per key-group round-robin cursor, keyed by the sorted key ids joined with
  /// `|` (so changing the pool restarts the cycle), mirroring the Web
  /// `roundRobinIndexMap`.
  final Map<String, int> _roundRobinIndex = <String, int>{};

  /// Selects the next usable key from [keys] under [strategy], or `null` when
  /// none is currently usable (all disabled / errored / in cooldown). A key is
  /// usable when it is enabled, has `active` status, is past any cooldown and
  /// carries a non-empty secret. Keys whose id is in [excludeIds] are skipped —
  /// failover passes the keys already tried this send so a bad key is never
  /// re-picked before the pool is exhausted.
  ApiKeyConfig? selectApiKey(
    List<ApiKeyConfig> keys,
    String strategy, {
    Set<String> excludeIds = const <String>{},
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final available = [
      for (final key in keys)
        if (key.isEnabled &&
            key.status == 'active' &&
            !isKeyInCooldown(key, now: at) &&
            !excludeIds.contains(key.id) &&
            key.key.trim().isNotEmpty)
          key,
    ];
    if (available.isEmpty) return null;

    switch (strategy) {
      case 'priority':
        return _selectByPriority(available);
      case 'least_used':
        return _selectByLeastUsed(available);
      case 'random':
        return _selectByRandom(available);
      case 'round_robin':
      default:
        return _selectByRoundRobin(available);
    }
  }

  /// Lowest [ApiKeyConfig.priority] wins (1 = highest priority).
  ApiKeyConfig _selectByPriority(List<ApiKeyConfig> keys) {
    final sorted = [...keys]..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted.first;
  }

  /// Fewest total requests wins, spreading load evenly.
  ApiKeyConfig _selectByLeastUsed(List<ApiKeyConfig> keys) {
    final sorted = [...keys]
      ..sort((a, b) => a.usage.totalRequests.compareTo(b.usage.totalRequests));
    return sorted.first;
  }

  ApiKeyConfig _selectByRandom(List<ApiKeyConfig> keys) =>
      keys[Random().nextInt(keys.length)];

  /// Cycles through the keys in a stable id order, advancing a per-group cursor
  /// so successive calls hand out each key in turn.
  ApiKeyConfig _selectByRoundRobin(List<ApiKeyConfig> keys) {
    final sorted = [...keys]..sort((a, b) => a.id.compareTo(b.id));
    final groupId = sorted.map((k) => k.id).join('|');
    final current = _roundRobinIndex[groupId] ?? 0;
    final index = current % sorted.length;
    _roundRobinIndex[groupId] = (index + 1) % sorted.length;
    return sorted[index];
  }

  /// Whether [key] is still cooling down from its last error. Only `error` keys
  /// cool down; once [cooldown] has elapsed they become selectable again (the
  /// "auto recover on next select").
  bool isKeyInCooldown(ApiKeyConfig key, {DateTime? now}) {
    if (key.status != 'error') return false;
    final at = now ?? DateTime.now();
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(key.updatedAt);
    return at.difference(updatedAt) < cooldown;
  }

  /// Returns a new [ApiKeyConfig] with usage counters and status advanced for a
  /// completed request. On success the failure streak resets and the key is
  /// re-activated; on failure the streak grows and the key trips to `error`
  /// (entering cooldown) once it reaches [maxConsecutiveFailures]. Mirrors the
  /// Web `updateKeyStatus`.
  ApiKeyConfig updateKeyStatus(
    ApiKeyConfig key, {
    required bool success,
    String? error,
    DateTime? now,
  }) {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (success) {
      return key.copyWith(
        usage: key.usage.copyWith(
          totalRequests: key.usage.totalRequests + 1,
          successfulRequests: key.usage.successfulRequests + 1,
          consecutiveFailures: 0,
          lastUsed: nowMs,
        ),
        status: 'active',
        lastError: null,
        updatedAt: nowMs,
      );
    }
    final failures = key.usage.consecutiveFailures + 1;
    return key.copyWith(
      usage: key.usage.copyWith(
        totalRequests: key.usage.totalRequests + 1,
        failedRequests: key.usage.failedRequests + 1,
        consecutiveFailures: failures,
        lastUsed: nowMs,
      ),
      status: failures >= maxConsecutiveFailures ? 'error' : key.status,
      lastError: error,
      updatedAt: nowMs,
    );
  }
}
