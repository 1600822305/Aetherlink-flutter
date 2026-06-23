// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_avatar.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserAvatarImpl _$$UserAvatarImplFromJson(Map<String, dynamic> json) =>
    _$UserAvatarImpl(
      type: $enumDecodeNullable(_$UserAvatarTypeEnumMap, json['type']) ??
          UserAvatarType.none,
      value: json['value'] as String? ?? '',
    );

Map<String, dynamic> _$$UserAvatarImplToJson(_$UserAvatarImpl instance) =>
    <String, dynamic>{
      'type': _$UserAvatarTypeEnumMap[instance.type]!,
      'value': instance.value,
    };

const _$UserAvatarTypeEnumMap = {
  UserAvatarType.none: 'none',
  UserAvatarType.emoji: 'emoji',
  UserAvatarType.url: 'url',
  UserAvatarType.file: 'file',
};
