// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_toolbar_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TopToolbarComponentPosition _$TopToolbarComponentPositionFromJson(
  Map<String, dynamic> json,
) => _TopToolbarComponentPosition(
  component: $enumDecode(_$TopToolbarComponentEnumMap, json['component']),
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
);

Map<String, dynamic> _$TopToolbarComponentPositionToJson(
  _TopToolbarComponentPosition instance,
) => <String, dynamic>{
  'component': _$TopToolbarComponentEnumMap[instance.component]!,
  'x': instance.x,
  'y': instance.y,
};

const _$TopToolbarComponentEnumMap = {
  TopToolbarComponent.menuButton: 'menuButton',
  TopToolbarComponent.topicName: 'topicName',
  TopToolbarComponent.newTopicButton: 'newTopicButton',
  TopToolbarComponent.clearButton: 'clearButton',
  TopToolbarComponent.searchButton: 'searchButton',
  TopToolbarComponent.modelSelector: 'modelSelector',
  TopToolbarComponent.settingsButton: 'settingsButton',
  TopToolbarComponent.condenseButton: 'condenseButton',
};

_TopToolbarSettings _$TopToolbarSettingsFromJson(Map<String, dynamic> json) =>
    _TopToolbarSettings(
      positions:
          (json['positions'] as List<dynamic>?)
              ?.map(
                (e) => TopToolbarComponentPosition.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      modelSelectorDisplayStyle:
          $enumDecodeNullable(
            _$ModelSelectorDisplayStyleEnumMap,
            json['modelSelectorDisplayStyle'],
          ) ??
          ModelSelectorDisplayStyle.icon,
    );

Map<String, dynamic> _$TopToolbarSettingsToJson(
  _TopToolbarSettings instance,
) => <String, dynamic>{
  'positions': instance.positions.map((e) => e.toJson()).toList(),
  'modelSelectorDisplayStyle':
      _$ModelSelectorDisplayStyleEnumMap[instance.modelSelectorDisplayStyle]!,
};

const _$ModelSelectorDisplayStyleEnumMap = {
  ModelSelectorDisplayStyle.icon: 'icon',
  ModelSelectorDisplayStyle.text: 'text',
};
