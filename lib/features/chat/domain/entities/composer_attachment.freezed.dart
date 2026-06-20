// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'composer_attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ComposerAttachment {

 String get id; String get name; String get mimeType; int get size; String get text;
/// Create a copy of ComposerAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComposerAttachmentCopyWith<ComposerAttachment> get copyWith => _$ComposerAttachmentCopyWithImpl<ComposerAttachment>(this as ComposerAttachment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComposerAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.size, size) || other.size == size)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,mimeType,size,text);

@override
String toString() {
  return 'ComposerAttachment(id: $id, name: $name, mimeType: $mimeType, size: $size, text: $text)';
}


}

/// @nodoc
abstract mixin class $ComposerAttachmentCopyWith<$Res>  {
  factory $ComposerAttachmentCopyWith(ComposerAttachment value, $Res Function(ComposerAttachment) _then) = _$ComposerAttachmentCopyWithImpl;
@useResult
$Res call({
 String id, String name, String mimeType, int size, String text
});




}
/// @nodoc
class _$ComposerAttachmentCopyWithImpl<$Res>
    implements $ComposerAttachmentCopyWith<$Res> {
  _$ComposerAttachmentCopyWithImpl(this._self, this._then);

  final ComposerAttachment _self;
  final $Res Function(ComposerAttachment) _then;

/// Create a copy of ComposerAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? mimeType = null,Object? size = null,Object? text = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ComposerAttachment].
extension ComposerAttachmentPatterns on ComposerAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComposerAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComposerAttachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComposerAttachment value)  $default,){
final _that = this;
switch (_that) {
case _ComposerAttachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComposerAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _ComposerAttachment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String mimeType,  int size,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComposerAttachment() when $default != null:
return $default(_that.id,_that.name,_that.mimeType,_that.size,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String mimeType,  int size,  String text)  $default,) {final _that = this;
switch (_that) {
case _ComposerAttachment():
return $default(_that.id,_that.name,_that.mimeType,_that.size,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String mimeType,  int size,  String text)?  $default,) {final _that = this;
switch (_that) {
case _ComposerAttachment() when $default != null:
return $default(_that.id,_that.name,_that.mimeType,_that.size,_that.text);case _:
  return null;

}
}

}

/// @nodoc


class _ComposerAttachment implements ComposerAttachment {
  const _ComposerAttachment({required this.id, required this.name, required this.mimeType, required this.size, required this.text});
  

@override final  String id;
@override final  String name;
@override final  String mimeType;
@override final  int size;
@override final  String text;

/// Create a copy of ComposerAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComposerAttachmentCopyWith<_ComposerAttachment> get copyWith => __$ComposerAttachmentCopyWithImpl<_ComposerAttachment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComposerAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.size, size) || other.size == size)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,mimeType,size,text);

@override
String toString() {
  return 'ComposerAttachment(id: $id, name: $name, mimeType: $mimeType, size: $size, text: $text)';
}


}

/// @nodoc
abstract mixin class _$ComposerAttachmentCopyWith<$Res> implements $ComposerAttachmentCopyWith<$Res> {
  factory _$ComposerAttachmentCopyWith(_ComposerAttachment value, $Res Function(_ComposerAttachment) _then) = __$ComposerAttachmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String mimeType, int size, String text
});




}
/// @nodoc
class __$ComposerAttachmentCopyWithImpl<$Res>
    implements _$ComposerAttachmentCopyWith<$Res> {
  __$ComposerAttachmentCopyWithImpl(this._self, this._then);

  final _ComposerAttachment _self;
  final $Res Function(_ComposerAttachment) _then;

/// Create a copy of ComposerAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? mimeType = null,Object? size = null,Object? text = null,}) {
  return _then(_ComposerAttachment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
