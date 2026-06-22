// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_combo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ComboModelEntry _$ComboModelEntryFromJson(Map<String, dynamic> json) =>
    _ComboModelEntry(
      modelId: json['modelId'] as String,
      role: json['role'] as String,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ComboModelEntryToJson(_ComboModelEntry instance) =>
    <String, dynamic>{
      'modelId': instance.modelId,
      'role': instance.role,
      'priority': instance.priority,
    };

_ModelComboConfig _$ModelComboConfigFromJson(Map<String, dynamic> json) =>
    _ModelComboConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      strategy: $enumDecode(_$ModelComboStrategyEnumMap, json['strategy']),
      enabled: json['enabled'] as bool? ?? true,
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => ComboModelEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ComboModelEntry>[],
      showThinking: json['showThinking'] as bool? ?? true,
      handoffPrompt: json['handoffPrompt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );

Map<String, dynamic> _$ModelComboConfigToJson(_ModelComboConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'strategy': _$ModelComboStrategyEnumMap[instance.strategy]!,
      'enabled': instance.enabled,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'showThinking': instance.showThinking,
      'handoffPrompt': ?instance.handoffPrompt,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

const _$ModelComboStrategyEnumMap = {
  ModelComboStrategy.sequential: 'sequential',
  ModelComboStrategy.comparison: 'comparison',
};

_ModelComboState _$ModelComboStateFromJson(Map<String, dynamic> json) =>
    _ModelComboState(
      combos:
          (json['combos'] as List<dynamic>?)
              ?.map((e) => ModelComboConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ModelComboConfig>[],
      enableSmartRouting: json['enableSmartRouting'] as bool? ?? false,
      routingModelId: json['routingModelId'] as String?,
      selectedComboId: json['selectedComboId'] as String?,
    );

Map<String, dynamic> _$ModelComboStateToJson(_ModelComboState instance) =>
    <String, dynamic>{
      'combos': instance.combos.map((e) => e.toJson()).toList(),
      'enableSmartRouting': instance.enableSmartRouting,
      'routingModelId': ?instance.routingModelId,
      'selectedComboId': ?instance.selectedComboId,
    };
