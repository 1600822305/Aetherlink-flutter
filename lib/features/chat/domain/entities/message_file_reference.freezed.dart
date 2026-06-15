// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_file_reference.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageFileReference {

 String get id; String get name;@JsonKey(name: 'origin_name') String get originName; int get size; String get mimeType; String? get base64Data; String? get type;
/// Create a copy of MessageFileReference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageFileReferenceCopyWith<MessageFileReference> get copyWith => _$MessageFileReferenceCopyWithImpl<MessageFileReference>(this as MessageFileReference, _$identity);

  /// Serializes this MessageFileReference to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageFileReference&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.originName, originName) || other.originName == originName)&&(identical(other.size, size) || other.size == size)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.base64Data, base64Data) || other.base64Data == base64Data)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,originName,size,mimeType,base64Data,type);

@override
String toString() {
  return 'MessageFileReference(id: $id, name: $name, originName: $originName, size: $size, mimeType: $mimeType, base64Data: $base64Data, type: $type)';
}


}

/// @nodoc
abstract mixin class $MessageFileReferenceCopyWith<$Res>  {
  factory $MessageFileReferenceCopyWith(MessageFileReference value, $Res Function(MessageFileReference) _then) = _$MessageFileReferenceCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'origin_name') String originName, int size, String mimeType, String? base64Data, String? type
});




}
/// @nodoc
class _$MessageFileReferenceCopyWithImpl<$Res>
    implements $MessageFileReferenceCopyWith<$Res> {
  _$MessageFileReferenceCopyWithImpl(this._self, this._then);

  final MessageFileReference _self;
  final $Res Function(MessageFileReference) _then;

/// Create a copy of MessageFileReference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? originName = null,Object? size = null,Object? mimeType = null,Object? base64Data = freezed,Object? type = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,originName: null == originName ? _self.originName : originName // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,base64Data: freezed == base64Data ? _self.base64Data : base64Data // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageFileReference].
extension MessageFileReferencePatterns on MessageFileReference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageFileReference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageFileReference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageFileReference value)  $default,){
final _that = this;
switch (_that) {
case _MessageFileReference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageFileReference value)?  $default,){
final _that = this;
switch (_that) {
case _MessageFileReference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'origin_name')  String originName,  int size,  String mimeType,  String? base64Data,  String? type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageFileReference() when $default != null:
return $default(_that.id,_that.name,_that.originName,_that.size,_that.mimeType,_that.base64Data,_that.type);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'origin_name')  String originName,  int size,  String mimeType,  String? base64Data,  String? type)  $default,) {final _that = this;
switch (_that) {
case _MessageFileReference():
return $default(_that.id,_that.name,_that.originName,_that.size,_that.mimeType,_that.base64Data,_that.type);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'origin_name')  String originName,  int size,  String mimeType,  String? base64Data,  String? type)?  $default,) {final _that = this;
switch (_that) {
case _MessageFileReference() when $default != null:
return $default(_that.id,_that.name,_that.originName,_that.size,_that.mimeType,_that.base64Data,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageFileReference implements MessageFileReference {
  const _MessageFileReference({required this.id, required this.name, @JsonKey(name: 'origin_name') required this.originName, required this.size, required this.mimeType, this.base64Data, this.type});
  factory _MessageFileReference.fromJson(Map<String, dynamic> json) => _$MessageFileReferenceFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey(name: 'origin_name') final  String originName;
@override final  int size;
@override final  String mimeType;
@override final  String? base64Data;
@override final  String? type;

/// Create a copy of MessageFileReference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageFileReferenceCopyWith<_MessageFileReference> get copyWith => __$MessageFileReferenceCopyWithImpl<_MessageFileReference>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageFileReferenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageFileReference&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.originName, originName) || other.originName == originName)&&(identical(other.size, size) || other.size == size)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.base64Data, base64Data) || other.base64Data == base64Data)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,originName,size,mimeType,base64Data,type);

@override
String toString() {
  return 'MessageFileReference(id: $id, name: $name, originName: $originName, size: $size, mimeType: $mimeType, base64Data: $base64Data, type: $type)';
}


}

/// @nodoc
abstract mixin class _$MessageFileReferenceCopyWith<$Res> implements $MessageFileReferenceCopyWith<$Res> {
  factory _$MessageFileReferenceCopyWith(_MessageFileReference value, $Res Function(_MessageFileReference) _then) = __$MessageFileReferenceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'origin_name') String originName, int size, String mimeType, String? base64Data, String? type
});




}
/// @nodoc
class __$MessageFileReferenceCopyWithImpl<$Res>
    implements _$MessageFileReferenceCopyWith<$Res> {
  __$MessageFileReferenceCopyWithImpl(this._self, this._then);

  final _MessageFileReference _self;
  final $Res Function(_MessageFileReference) _then;

/// Create a copy of MessageFileReference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? originName = null,Object? size = null,Object? mimeType = null,Object? base64Data = freezed,Object? type = freezed,}) {
  return _then(_MessageFileReference(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,originName: null == originName ? _self.originName : originName // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,base64Data: freezed == base64Data ? _self.base64Data : base64Data // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
