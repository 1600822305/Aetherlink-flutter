// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiKeyUsage _$ApiKeyUsageFromJson(Map<String, dynamic> json) => _ApiKeyUsage(
  totalRequests: (json['totalRequests'] as num?)?.toInt() ?? 0,
  successfulRequests: (json['successfulRequests'] as num?)?.toInt() ?? 0,
  failedRequests: (json['failedRequests'] as num?)?.toInt() ?? 0,
  lastUsed: (json['lastUsed'] as num?)?.toInt(),
  consecutiveFailures: (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ApiKeyUsageToJson(_ApiKeyUsage instance) =>
    <String, dynamic>{
      'totalRequests': instance.totalRequests,
      'successfulRequests': instance.successfulRequests,
      'failedRequests': instance.failedRequests,
      'lastUsed': ?instance.lastUsed,
      'consecutiveFailures': instance.consecutiveFailures,
    };

_ApiKeyConfig _$ApiKeyConfigFromJson(Map<String, dynamic> json) =>
    _ApiKeyConfig(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 5,
      maxRequestsPerMinute: (json['maxRequestsPerMinute'] as num?)?.toInt(),
      usage: json['usage'] == null
          ? const ApiKeyUsage()
          : ApiKeyUsage.fromJson(json['usage'] as Map<String, dynamic>),
      status: json['status'] as String? ?? 'active',
      lastError: json['lastError'] as String?,
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$ApiKeyConfigToJson(_ApiKeyConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'name': ?instance.name,
      'isEnabled': instance.isEnabled,
      'priority': instance.priority,
      'maxRequestsPerMinute': ?instance.maxRequestsPerMinute,
      'usage': instance.usage.toJson(),
      'status': instance.status,
      'lastError': ?instance.lastError,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

_KeyManagementConfig _$KeyManagementConfigFromJson(Map<String, dynamic> json) =>
    _KeyManagementConfig(
      strategy: json['strategy'] as String? ?? 'round_robin',
      maxFailuresBeforeDisable:
          (json['maxFailuresBeforeDisable'] as num?)?.toInt() ?? 3,
      failureRecoveryTime: (json['failureRecoveryTime'] as num?)?.toInt() ?? 5,
      enableAutoRecovery: json['enableAutoRecovery'] as bool? ?? true,
    );

Map<String, dynamic> _$KeyManagementConfigToJson(
  _KeyManagementConfig instance,
) => <String, dynamic>{
  'strategy': instance.strategy,
  'maxFailuresBeforeDisable': instance.maxFailuresBeforeDisable,
  'failureRecoveryTime': instance.failureRecoveryTime,
  'enableAutoRecovery': instance.enableAutoRecovery,
};
