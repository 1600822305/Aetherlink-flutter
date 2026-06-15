// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quick_phrase.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QuickPhrase {

 String get id; String get title; String get content; int get createdAt; int get updatedAt; int? get order;
/// Create a copy of QuickPhrase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuickPhraseCopyWith<QuickPhrase> get copyWith => _$QuickPhraseCopyWithImpl<QuickPhrase>(this as QuickPhrase, _$identity);

  /// Serializes this QuickPhrase to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuickPhrase&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.order, order) || other.order == order));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,content,createdAt,updatedAt,order);

@override
String toString() {
  return 'QuickPhrase(id: $id, title: $title, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, order: $order)';
}


}

/// @nodoc
abstract mixin class $QuickPhraseCopyWith<$Res>  {
  factory $QuickPhraseCopyWith(QuickPhrase value, $Res Function(QuickPhrase) _then) = _$QuickPhraseCopyWithImpl;
@useResult
$Res call({
 String id, String title, String content, int createdAt, int updatedAt, int? order
});




}
/// @nodoc
class _$QuickPhraseCopyWithImpl<$Res>
    implements $QuickPhraseCopyWith<$Res> {
  _$QuickPhraseCopyWithImpl(this._self, this._then);

  final QuickPhrase _self;
  final $Res Function(QuickPhrase) _then;

/// Create a copy of QuickPhrase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? content = null,Object? createdAt = null,Object? updatedAt = null,Object? order = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,order: freezed == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuickPhrase].
extension QuickPhrasePatterns on QuickPhrase {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuickPhrase value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuickPhrase() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuickPhrase value)  $default,){
final _that = this;
switch (_that) {
case _QuickPhrase():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuickPhrase value)?  $default,){
final _that = this;
switch (_that) {
case _QuickPhrase() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String content,  int createdAt,  int updatedAt,  int? order)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuickPhrase() when $default != null:
return $default(_that.id,_that.title,_that.content,_that.createdAt,_that.updatedAt,_that.order);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String content,  int createdAt,  int updatedAt,  int? order)  $default,) {final _that = this;
switch (_that) {
case _QuickPhrase():
return $default(_that.id,_that.title,_that.content,_that.createdAt,_that.updatedAt,_that.order);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String content,  int createdAt,  int updatedAt,  int? order)?  $default,) {final _that = this;
switch (_that) {
case _QuickPhrase() when $default != null:
return $default(_that.id,_that.title,_that.content,_that.createdAt,_that.updatedAt,_that.order);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QuickPhrase implements QuickPhrase {
  const _QuickPhrase({required this.id, required this.title, required this.content, required this.createdAt, required this.updatedAt, this.order});
  factory _QuickPhrase.fromJson(Map<String, dynamic> json) => _$QuickPhraseFromJson(json);

@override final  String id;
@override final  String title;
@override final  String content;
@override final  int createdAt;
@override final  int updatedAt;
@override final  int? order;

/// Create a copy of QuickPhrase
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuickPhraseCopyWith<_QuickPhrase> get copyWith => __$QuickPhraseCopyWithImpl<_QuickPhrase>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuickPhraseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuickPhrase&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.order, order) || other.order == order));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,content,createdAt,updatedAt,order);

@override
String toString() {
  return 'QuickPhrase(id: $id, title: $title, content: $content, createdAt: $createdAt, updatedAt: $updatedAt, order: $order)';
}


}

/// @nodoc
abstract mixin class _$QuickPhraseCopyWith<$Res> implements $QuickPhraseCopyWith<$Res> {
  factory _$QuickPhraseCopyWith(_QuickPhrase value, $Res Function(_QuickPhrase) _then) = __$QuickPhraseCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String content, int createdAt, int updatedAt, int? order
});




}
/// @nodoc
class __$QuickPhraseCopyWithImpl<$Res>
    implements _$QuickPhraseCopyWith<$Res> {
  __$QuickPhraseCopyWithImpl(this._self, this._then);

  final _QuickPhrase _self;
  final $Res Function(_QuickPhrase) _then;

/// Create a copy of QuickPhrase
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? content = null,Object? createdAt = null,Object? updatedAt = null,Object? order = freezed,}) {
  return _then(_QuickPhrase(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,order: freezed == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
