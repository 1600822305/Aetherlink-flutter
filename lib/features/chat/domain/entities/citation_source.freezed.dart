// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'citation_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CitationSource {

 String? get title; String? get url; String? get content;
/// Create a copy of CitationSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CitationSourceCopyWith<CitationSource> get copyWith => _$CitationSourceCopyWithImpl<CitationSource>(this as CitationSource, _$identity);

  /// Serializes this CitationSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CitationSource&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,url,content);

@override
String toString() {
  return 'CitationSource(title: $title, url: $url, content: $content)';
}


}

/// @nodoc
abstract mixin class $CitationSourceCopyWith<$Res>  {
  factory $CitationSourceCopyWith(CitationSource value, $Res Function(CitationSource) _then) = _$CitationSourceCopyWithImpl;
@useResult
$Res call({
 String? title, String? url, String? content
});




}
/// @nodoc
class _$CitationSourceCopyWithImpl<$Res>
    implements $CitationSourceCopyWith<$Res> {
  _$CitationSourceCopyWithImpl(this._self, this._then);

  final CitationSource _self;
  final $Res Function(CitationSource) _then;

/// Create a copy of CitationSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = freezed,Object? url = freezed,Object? content = freezed,}) {
  return _then(_self.copyWith(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CitationSource].
extension CitationSourcePatterns on CitationSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CitationSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CitationSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CitationSource value)  $default,){
final _that = this;
switch (_that) {
case _CitationSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CitationSource value)?  $default,){
final _that = this;
switch (_that) {
case _CitationSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? title,  String? url,  String? content)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CitationSource() when $default != null:
return $default(_that.title,_that.url,_that.content);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? title,  String? url,  String? content)  $default,) {final _that = this;
switch (_that) {
case _CitationSource():
return $default(_that.title,_that.url,_that.content);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? title,  String? url,  String? content)?  $default,) {final _that = this;
switch (_that) {
case _CitationSource() when $default != null:
return $default(_that.title,_that.url,_that.content);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CitationSource implements CitationSource {
  const _CitationSource({this.title, this.url, this.content});
  factory _CitationSource.fromJson(Map<String, dynamic> json) => _$CitationSourceFromJson(json);

@override final  String? title;
@override final  String? url;
@override final  String? content;

/// Create a copy of CitationSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CitationSourceCopyWith<_CitationSource> get copyWith => __$CitationSourceCopyWithImpl<_CitationSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CitationSourceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CitationSource&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,url,content);

@override
String toString() {
  return 'CitationSource(title: $title, url: $url, content: $content)';
}


}

/// @nodoc
abstract mixin class _$CitationSourceCopyWith<$Res> implements $CitationSourceCopyWith<$Res> {
  factory _$CitationSourceCopyWith(_CitationSource value, $Res Function(_CitationSource) _then) = __$CitationSourceCopyWithImpl;
@override @useResult
$Res call({
 String? title, String? url, String? content
});




}
/// @nodoc
class __$CitationSourceCopyWithImpl<$Res>
    implements _$CitationSourceCopyWith<$Res> {
  __$CitationSourceCopyWithImpl(this._self, this._then);

  final _CitationSource _self;
  final $Res Function(_CitationSource) _then;

/// Create a copy of CitationSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = freezed,Object? url = freezed,Object? content = freezed,}) {
  return _then(_CitationSource(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
