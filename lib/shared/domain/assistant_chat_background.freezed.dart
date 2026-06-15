// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant_chat_background.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssistantChatBackground {

 bool get enabled; String get imageUrl; double? get opacity; String? get size; String? get position; String? get repeat; bool? get showOverlay;
/// Create a copy of AssistantChatBackground
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantChatBackgroundCopyWith<AssistantChatBackground> get copyWith => _$AssistantChatBackgroundCopyWithImpl<AssistantChatBackground>(this as AssistantChatBackground, _$identity);

  /// Serializes this AssistantChatBackground to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantChatBackground&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.size, size) || other.size == size)&&(identical(other.position, position) || other.position == position)&&(identical(other.repeat, repeat) || other.repeat == repeat)&&(identical(other.showOverlay, showOverlay) || other.showOverlay == showOverlay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,imageUrl,opacity,size,position,repeat,showOverlay);

@override
String toString() {
  return 'AssistantChatBackground(enabled: $enabled, imageUrl: $imageUrl, opacity: $opacity, size: $size, position: $position, repeat: $repeat, showOverlay: $showOverlay)';
}


}

/// @nodoc
abstract mixin class $AssistantChatBackgroundCopyWith<$Res>  {
  factory $AssistantChatBackgroundCopyWith(AssistantChatBackground value, $Res Function(AssistantChatBackground) _then) = _$AssistantChatBackgroundCopyWithImpl;
@useResult
$Res call({
 bool enabled, String imageUrl, double? opacity, String? size, String? position, String? repeat, bool? showOverlay
});




}
/// @nodoc
class _$AssistantChatBackgroundCopyWithImpl<$Res>
    implements $AssistantChatBackgroundCopyWith<$Res> {
  _$AssistantChatBackgroundCopyWithImpl(this._self, this._then);

  final AssistantChatBackground _self;
  final $Res Function(AssistantChatBackground) _then;

/// Create a copy of AssistantChatBackground
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? imageUrl = null,Object? opacity = freezed,Object? size = freezed,Object? position = freezed,Object? repeat = freezed,Object? showOverlay = freezed,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,opacity: freezed == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,repeat: freezed == repeat ? _self.repeat : repeat // ignore: cast_nullable_to_non_nullable
as String?,showOverlay: freezed == showOverlay ? _self.showOverlay : showOverlay // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantChatBackground].
extension AssistantChatBackgroundPatterns on AssistantChatBackground {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantChatBackground value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantChatBackground() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantChatBackground value)  $default,){
final _that = this;
switch (_that) {
case _AssistantChatBackground():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantChatBackground value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantChatBackground() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String imageUrl,  double? opacity,  String? size,  String? position,  String? repeat,  bool? showOverlay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantChatBackground() when $default != null:
return $default(_that.enabled,_that.imageUrl,_that.opacity,_that.size,_that.position,_that.repeat,_that.showOverlay);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String imageUrl,  double? opacity,  String? size,  String? position,  String? repeat,  bool? showOverlay)  $default,) {final _that = this;
switch (_that) {
case _AssistantChatBackground():
return $default(_that.enabled,_that.imageUrl,_that.opacity,_that.size,_that.position,_that.repeat,_that.showOverlay);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String imageUrl,  double? opacity,  String? size,  String? position,  String? repeat,  bool? showOverlay)?  $default,) {final _that = this;
switch (_that) {
case _AssistantChatBackground() when $default != null:
return $default(_that.enabled,_that.imageUrl,_that.opacity,_that.size,_that.position,_that.repeat,_that.showOverlay);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssistantChatBackground implements AssistantChatBackground {
  const _AssistantChatBackground({required this.enabled, required this.imageUrl, this.opacity, this.size, this.position, this.repeat, this.showOverlay});
  factory _AssistantChatBackground.fromJson(Map<String, dynamic> json) => _$AssistantChatBackgroundFromJson(json);

@override final  bool enabled;
@override final  String imageUrl;
@override final  double? opacity;
@override final  String? size;
@override final  String? position;
@override final  String? repeat;
@override final  bool? showOverlay;

/// Create a copy of AssistantChatBackground
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantChatBackgroundCopyWith<_AssistantChatBackground> get copyWith => __$AssistantChatBackgroundCopyWithImpl<_AssistantChatBackground>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantChatBackgroundToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantChatBackground&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.opacity, opacity) || other.opacity == opacity)&&(identical(other.size, size) || other.size == size)&&(identical(other.position, position) || other.position == position)&&(identical(other.repeat, repeat) || other.repeat == repeat)&&(identical(other.showOverlay, showOverlay) || other.showOverlay == showOverlay));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,imageUrl,opacity,size,position,repeat,showOverlay);

@override
String toString() {
  return 'AssistantChatBackground(enabled: $enabled, imageUrl: $imageUrl, opacity: $opacity, size: $size, position: $position, repeat: $repeat, showOverlay: $showOverlay)';
}


}

/// @nodoc
abstract mixin class _$AssistantChatBackgroundCopyWith<$Res> implements $AssistantChatBackgroundCopyWith<$Res> {
  factory _$AssistantChatBackgroundCopyWith(_AssistantChatBackground value, $Res Function(_AssistantChatBackground) _then) = __$AssistantChatBackgroundCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String imageUrl, double? opacity, String? size, String? position, String? repeat, bool? showOverlay
});




}
/// @nodoc
class __$AssistantChatBackgroundCopyWithImpl<$Res>
    implements _$AssistantChatBackgroundCopyWith<$Res> {
  __$AssistantChatBackgroundCopyWithImpl(this._self, this._then);

  final _AssistantChatBackground _self;
  final $Res Function(_AssistantChatBackground) _then;

/// Create a copy of AssistantChatBackground
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? imageUrl = null,Object? opacity = freezed,Object? size = freezed,Object? position = freezed,Object? repeat = freezed,Object? showOverlay = freezed,}) {
  return _then(_AssistantChatBackground(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,opacity: freezed == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String?,repeat: freezed == repeat ? _self.repeat : repeat // ignore: cast_nullable_to_non_nullable
as String?,showOverlay: freezed == showOverlay ? _self.showOverlay : showOverlay // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
