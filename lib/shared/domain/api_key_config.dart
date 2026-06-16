import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_key_config.freezed.dart';
part 'api_key_config.g.dart';

/// Per-key usage counters. Translation of `ApiKeyConfig['usage']`
/// (`src/shared/config/defaultModels.ts`). Persisted so the multi-key UI can
/// surface request/success/failure stats, but **not yet populated**: the
/// request layer (`LlmGateway`) still authenticates with the single
/// [ModelProvider.apiKey], so these stay at their defaults until multi-key
/// scheduling is wired (界面标注「调度即将支持」).
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
/// `rate_limited`) and [priority] is `1..10` (lower = higher priority). Carried
/// for UI + persistence; the scheduling runtime that consumes them (round-robin
/// / quota) is not yet ported — see [KeyManagementConfig].
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
/// `priority` | `least_used` | `random`). Stored so the manager page can edit
/// it; the scheduler that acts on it is 即将支持.
@freezed
abstract class KeyManagementConfig with _$KeyManagementConfig {
  const factory KeyManagementConfig({
    @Default('round_robin') String strategy,
    @Default(3) int maxFailuresBeforeDisable,
    @Default(5) int failureRecoveryTime,
    @Default(true) bool enableAutoRecovery,
  }) = _KeyManagementConfig;

  factory KeyManagementConfig.fromJson(Map<String, dynamic> json) =>
      _$KeyManagementConfigFromJson(json);
}
