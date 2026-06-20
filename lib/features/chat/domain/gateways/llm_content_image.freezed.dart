// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_content_image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LlmContentImage {

 String get mimeType; String get base64Data;
/// Create a copy of LlmContentImage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmContentImageCopyWith<LlmContentImage> get copyWith => _$LlmContentImageCopyWithImpl<LlmContentImage>(this as LlmContentImage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmContentImage&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.base64Data, base64Data) || other.base64Data == base64Data));
}


@override
int get hashCode => Object.hash(runtimeType,mimeType,base64Data);

@override
String toString() {
  return 'LlmContentImage(mimeType: $mimeType, base64Data: $base64Data)';
}


}

/// @nodoc
abstract mixin class $LlmContentImageCopyWith<$Res>  {
  factory $LlmContentImageCopyWith(LlmContentImage value, $Res Function(LlmContentImage) _then) = _$LlmContentImageCopyWithImpl;
@useResult
$Res call({
 String mimeType, String base64Data
});




}
/// @nodoc
class _$LlmContentImageCopyWithImpl<$Res>
    implements $LlmContentImageCopyWith<$Res> {
  _$LlmContentImageCopyWithImpl(this._self, this._then);

  final LlmContentImage _self;
  final $Res Function(LlmContentImage) _then;

/// Create a copy of LlmContentImage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mimeType = null,Object? base64Data = null,}) {
  return _then(_self.copyWith(
mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,base64Data: null == base64Data ? _self.base64Data : base64Data // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LlmContentImage].
extension LlmContentImagePatterns on LlmContentImage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmContentImage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmContentImage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmContentImage value)  $default,){
final _that = this;
switch (_that) {
case _LlmContentImage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmContentImage value)?  $default,){
final _that = this;
switch (_that) {
case _LlmContentImage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mimeType,  String base64Data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmContentImage() when $default != null:
return $default(_that.mimeType,_that.base64Data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mimeType,  String base64Data)  $default,) {final _that = this;
switch (_that) {
case _LlmContentImage():
return $default(_that.mimeType,_that.base64Data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mimeType,  String base64Data)?  $default,) {final _that = this;
switch (_that) {
case _LlmContentImage() when $default != null:
return $default(_that.mimeType,_that.base64Data);case _:
  return null;

}
}

}

/// @nodoc


class _LlmContentImage implements LlmContentImage {
  const _LlmContentImage({required this.mimeType, required this.base64Data});
  

@override final  String mimeType;
@override final  String base64Data;

/// Create a copy of LlmContentImage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmContentImageCopyWith<_LlmContentImage> get copyWith => __$LlmContentImageCopyWithImpl<_LlmContentImage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmContentImage&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.base64Data, base64Data) || other.base64Data == base64Data));
}


@override
int get hashCode => Object.hash(runtimeType,mimeType,base64Data);

@override
String toString() {
  return 'LlmContentImage(mimeType: $mimeType, base64Data: $base64Data)';
}


}

/// @nodoc
abstract mixin class _$LlmContentImageCopyWith<$Res> implements $LlmContentImageCopyWith<$Res> {
  factory _$LlmContentImageCopyWith(_LlmContentImage value, $Res Function(_LlmContentImage) _then) = __$LlmContentImageCopyWithImpl;
@override @useResult
$Res call({
 String mimeType, String base64Data
});




}
/// @nodoc
class __$LlmContentImageCopyWithImpl<$Res>
    implements _$LlmContentImageCopyWith<$Res> {
  __$LlmContentImageCopyWithImpl(this._self, this._then);

  final _LlmContentImage _self;
  final $Res Function(_LlmContentImage) _then;

/// Create a copy of LlmContentImage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mimeType = null,Object? base64Data = null,}) {
  return _then(_LlmContentImage(
mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,base64Data: null == base64Data ? _self.base64Data : base64Data // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
