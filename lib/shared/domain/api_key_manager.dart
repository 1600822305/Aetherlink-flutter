import 'dart:math';

import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';

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

  /// Default cooldown after a key trips into `error`, matching the Web
  /// `isKeyInCooldown` constant (`5 * 60 * 1000` ms). Overridable per provider
  /// via [KeyManagementConfig.failureRecoveryTime] (minutes).
  static const Duration cooldown = Duration(minutes: 5);

  /// Cooldown after an HTTP 429: rate limits clear quickly, so the key comes
  /// back much sooner than an errored one and its failure streak is untouched.
  static const Duration rateLimitCooldown = Duration(minutes: 1);

  /// Default consecutive failures that flip a key to `error` (Web hardcodes
  /// `>= 3`). Overridable via [KeyManagementConfig.maxFailuresBeforeDisable].
  static const int maxConsecutiveFailures = 3;

  /// Whether [error] is a provider rate limit (HTTP 429).
  static bool isRateLimitError(Object error) =>
      error is NetworkFailure && error.statusCode == 429;

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
    KeyManagementConfig? config,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final available = [
      for (final key in keys)
        if (key.isEnabled &&
            key.status != 'disabled' &&
            !isKeyInCooldown(key, config: config, now: at) &&
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

  /// Whether [key] is still cooling down from its last failure. `error` keys
  /// cool down for [KeyManagementConfig.failureRecoveryTime] minutes (default
  /// [cooldown]) — or indefinitely when auto-recovery is disabled — and
  /// `rate_limited` keys for [rateLimitCooldown]; once elapsed they become
  /// selectable again (the "auto recover on next select").
  bool isKeyInCooldown(ApiKeyConfig key, {KeyManagementConfig? config, DateTime? now}) {
    final Duration window;
    switch (key.status) {
      case 'error':
        if (!(config?.enableAutoRecovery ?? true)) return true;
        final minutes = config?.failureRecoveryTime;
        window = minutes != null && minutes > 0
            ? Duration(minutes: minutes)
            : cooldown;
      case 'rate_limited':
        window = rateLimitCooldown;
      default:
        return false;
    }
    final at = now ?? DateTime.now();
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(key.updatedAt);
    return at.difference(updatedAt) < window;
  }

  /// Time left before [key] leaves cooldown, or `null` when it is not cooling
  /// down (or will not auto-recover). For the manager page's countdown.
  Duration? cooldownRemaining(
    ApiKeyConfig key, {
    KeyManagementConfig? config,
    DateTime? now,
  }) {
    if (key.status == 'error' && !(config?.enableAutoRecovery ?? true)) {
      return null;
    }
    if (!isKeyInCooldown(key, config: config, now: now)) return null;
    final at = now ?? DateTime.now();
    final minutes = config?.failureRecoveryTime;
    final window = key.status == 'rate_limited'
        ? rateLimitCooldown
        : (minutes != null && minutes > 0 ? Duration(minutes: minutes) : cooldown);
    final end = DateTime.fromMillisecondsSinceEpoch(key.updatedAt).add(window);
    return end.difference(at);
  }

  /// Returns a new [ApiKeyConfig] with usage counters and status advanced for a
  /// completed request. On success the failure streak resets and the key is
  /// re-activated; a rate-limited failure ([rateLimited]) parks the key in
  /// `rate_limited` (short [rateLimitCooldown]) without growing the streak;
  /// any other failure grows the streak and trips the key to `error` (entering
  /// cooldown) once it reaches [KeyManagementConfig.maxFailuresBeforeDisable]
  /// (default [maxConsecutiveFailures]). Mirrors the Web `updateKeyStatus`.
  ApiKeyConfig updateKeyStatus(
    ApiKeyConfig key, {
    required bool success,
    bool rateLimited = false,
    KeyManagementConfig? config,
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
    if (rateLimited) {
      return key.copyWith(
        usage: key.usage.copyWith(
          totalRequests: key.usage.totalRequests + 1,
          failedRequests: key.usage.failedRequests + 1,
          lastUsed: nowMs,
        ),
        status: 'rate_limited',
        lastError: error,
        updatedAt: nowMs,
      );
    }
    final failures = key.usage.consecutiveFailures + 1;
    final maxFailures = config?.maxFailuresBeforeDisable ?? maxConsecutiveFailures;
    return key.copyWith(
      usage: key.usage.copyWith(
        totalRequests: key.usage.totalRequests + 1,
        failedRequests: key.usage.failedRequests + 1,
        consecutiveFailures: failures,
        lastUsed: nowMs,
      ),
      status: failures >= maxFailures ? 'error' : key.status,
      lastError: error,
      updatedAt: nowMs,
    );
  }

  /// A manually recovered [key]: back to `active` with a cleared failure
  /// streak, so it is immediately selectable again (立即恢复 in the manager
  /// page).
  ApiKeyConfig recoverKey(ApiKeyConfig key, {DateTime? now}) => key.copyWith(
    status: 'active',
    lastError: null,
    usage: key.usage.copyWith(consecutiveFailures: 0),
    updatedAt: (now ?? DateTime.now()).millisecondsSinceEpoch,
  );
}
