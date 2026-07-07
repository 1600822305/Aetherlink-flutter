import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_key_config.freezed.dart';
part 'api_key_config.g.dart';

/// Per-key usage counters. Translation of `ApiKeyConfig['usage']`
/// (`src/shared/config/defaultModels.ts`). Updated by `ApiKeyManager` after
/// every request through the pool and persisted, so the multi-key UI's
/// request/success/failure stats reflect real traffic.
@freezed
abstract class ApiKeyUsage with _$ApiKeyUsage {
  const factory ApiKeyUsage({
    @Default(0) int totalRequests,
    @Default(0) int successfulRequests,
    @Default(0) int failedRequests,
    int? lastUsed,
    @Default(0) int consecutiveFailures,
  }) = _ApiKeyUsage;

  factory ApiKeyUsage.fromJson(Map<String, dynamic> json) =>
      _$ApiKeyUsageFromJson(json);
}

/// A single API key in a provider's multi-key pool. One-to-one translation of
/// `ApiKeyConfig` (`src/shared/config/defaultModels.ts`); the multi-key manager
/// page lists / edits these.
///
/// [status] mirrors the original union (`active` | `disabled` | `error` |
/// `rate_limited`) and [priority] is `1..10` (lower = higher priority).
/// Consumed at request time by `ApiKeyManager`, which strategy-selects a
/// usable key per request and advances these fields — see
/// [KeyManagementConfig].
@freezed
abstract class ApiKeyConfig with _$ApiKeyConfig {
  const factory ApiKeyConfig({
    required String id,
    required String key,
    String? name,
    @Default(true) bool isEnabled,
    @Default(5) int priority,
    int? maxRequestsPerMinute,
    @Default(ApiKeyUsage()) ApiKeyUsage usage,
    @Default('active') String status,
    String? lastError,
    required int createdAt,
    required int updatedAt,
  }) = _ApiKeyConfig;

  factory ApiKeyConfig.fromJson(Map<String, dynamic> json) =>
      _$ApiKeyConfigFromJson(json);
}

/// Multi-key load-balancing configuration. Translation of `ModelProvider`'s
/// `keyManagement` (`src/shared/config/defaultModels.ts`).
///
/// [strategy] is the original `LoadBalanceStrategy` union (`round_robin` |
/// `priority` | `least_used` | `random`), applied by `ApiKeyManager` when the
/// request layer picks a key from the pool.
@freezed
abstract class KeyManagementConfig with _$KeyManagementConfig {
  const factory KeyManagementConfig({
    /// Whether the multi-key pool is active. When `false` (单 Key 模式) the
    /// request layer uses only the provider's single `apiKey`; the pool data
    /// stays stored untouched so flipping back restores it.
    @Default(true) bool enabled,
    @Default('round_robin') String strategy,
    @Default(3) int maxFailuresBeforeDisable,
    @Default(5) int failureRecoveryTime,
    @Default(true) bool enableAutoRecovery,
  }) = _KeyManagementConfig;

  factory KeyManagementConfig.fromJson(Map<String, dynamic> json) =>
      _$KeyManagementConfigFromJson(json);
}
