// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_avatar.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserAvatar _$UserAvatarFromJson(Map<String, dynamic> json) {
  return _UserAvatar.fromJson(json);
}

/// @nodoc
mixin _$UserAvatar {
  UserAvatarType get type => throw _privateConstructorUsedError;
  String get value => throw _privateConstructorUsedError;

  /// Create a copy of UserAvatar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserAvatarCopyWith<UserAvatar> get copyWith =>
      throw _privateConstructorUsedError;

  /// Serializes this UserAvatar to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserAvatarCopyWith<$Res> {
  factory $UserAvatarCopyWith(
          UserAvatar value, $Res Function(UserAvatar) then) =
      _$UserAvatarCopyWithImpl<$Res, UserAvatar>;
  @useResult
  $Res call({UserAvatarType type, String value});
}

/// @nodoc
class _$UserAvatarCopyWithImpl<$Res, $Val extends UserAvatar>
    implements $UserAvatarCopyWith<$Res> {
  _$UserAvatarCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserAvatar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? value = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as UserAvatarType,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserAvatarImplCopyWith<$Res>
    implements $UserAvatarCopyWith<$Res> {
  factory _$$UserAvatarImplCopyWith(
          _$UserAvatarImpl value, $Res Function(_$UserAvatarImpl) then) =
      __$$UserAvatarImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({UserAvatarType type, String value});
}

/// @nodoc
class __$$UserAvatarImplCopyWithImpl<$Res>
    extends _$UserAvatarCopyWithImpl<$Res, _$UserAvatarImpl>
    implements _$$UserAvatarImplCopyWith<$Res> {
  __$$UserAvatarImplCopyWithImpl(
      _$UserAvatarImpl _value, $Res Function(_$UserAvatarImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserAvatar
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? value = null,
  }) {
    return _then(_$UserAvatarImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as UserAvatarType,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserAvatarImpl implements _UserAvatar {
  const _$UserAvatarImpl(
      {this.type = UserAvatarType.none, this.value = ''});

  factory _$UserAvatarImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserAvatarImplFromJson(json);

  @override
  @JsonKey()
  final UserAvatarType type;
  @override
  @JsonKey()
  final String value;

  @override
  String toString() {
    return 'UserAvatar(type: $type, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserAvatarImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, value);

  /// Create a copy of UserAvatar
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserAvatarImplCopyWith<_$UserAvatarImpl> get copyWith =>
      __$$UserAvatarImplCopyWithImpl<_$UserAvatarImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserAvatarImplToJson(
      this,
    );
  }
}

abstract class _UserAvatar implements UserAvatar {
  const factory _UserAvatar(
      {final UserAvatarType type, final String value}) = _$UserAvatarImpl;

  factory _UserAvatar.fromJson(Map<String, dynamic> json) =
      _$UserAvatarImpl.fromJson;

  @override
  UserAvatarType get type;
  @override
  String get value;

  /// Create a copy of UserAvatar
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserAvatarImplCopyWith<_$UserAvatarImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
