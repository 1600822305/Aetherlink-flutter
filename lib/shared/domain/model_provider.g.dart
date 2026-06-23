// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelProvider _$ModelProviderFromJson(Map<String, dynamic> json) =>
    _ModelProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String,
      color: json['color'] as String,
      isEnabled: json['isEnabled'] as bool? ?? false,
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => Model.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Model>[],
      apiKey: json['apiKey'] as String?,
      baseUrl: json['baseUrl'] as String?,
      providerType: json['providerType'] as String?,
      isSystem: json['isSystem'] as bool?,
      extraHeaders: (json['extraHeaders'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      extraBody: json['extraBody'] as Map<String, dynamic>?,
      useResponsesAPI: json['useResponsesAPI'] as bool?,
      apiKeys: (json['apiKeys'] as List<dynamic>?)
          ?.map((e) => ApiKeyConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      keyManagement: json['keyManagement'] == null
          ? null
          : KeyManagementConfig.fromJson(
              json['keyManagement'] as Map<String, dynamic>,
            ),
      parameterScope: json['parameterScope'] as String?,
    );

Map<String, dynamic> _$ModelProviderToJson(_ModelProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
      'color': instance.color,
      'isEnabled': instance.isEnabled,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'apiKey': ?instance.apiKey,
      'baseUrl': ?instance.baseUrl,
      'providerType': ?instance.providerType,
      'isSystem': ?instance.isSystem,
      'extraHeaders': ?instance.extraHeaders,
      'extraBody': ?instance.extraBody,
      'useResponsesAPI': ?instance.useResponsesAPI,
      'apiKeys': ?instance.apiKeys?.map((e) => e.toJson()).toList(),
      'keyManagement': ?instance.keyManagement?.toJson(),
      'parameterScope': ?instance.parameterScope,
    };
