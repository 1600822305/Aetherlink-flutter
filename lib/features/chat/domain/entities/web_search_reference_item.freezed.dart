// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'web_search_reference_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WebSearchReferenceItem {

 int get index; String get title; String get url; String? get snippet; String? get content; String? get provider;
/// Create a copy of WebSearchReferenceItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebSearchReferenceItemCopyWith<WebSearchReferenceItem> get copyWith => _$WebSearchReferenceItemCopyWithImpl<WebSearchReferenceItem>(this as WebSearchReferenceItem, _$identity);

  /// Serializes this WebSearchReferenceItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WebSearchReferenceItem&&(identical(other.index, index) || other.index == index)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.snippet, snippet) || other.snippet == snippet)&&(identical(other.content, content) || other.content == content)&&(identical(other.provider, provider) || other.provider == provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,title,url,snippet,content,provider);

@override
String toString() {
  return 'WebSearchReferenceItem(index: $index, title: $title, url: $url, snippet: $snippet, content: $content, provider: $provider)';
}


}

/// @nodoc
abstract mixin class $WebSearchReferenceItemCopyWith<$Res>  {
  factory $WebSearchReferenceItemCopyWith(WebSearchReferenceItem value, $Res Function(WebSearchReferenceItem) _then) = _$WebSearchReferenceItemCopyWithImpl;
@useResult
$Res call({
 int index, String title, String url, String? snippet, String? content, String? provider
});




}
/// @nodoc
class _$WebSearchReferenceItemCopyWithImpl<$Res>
    implements $WebSearchReferenceItemCopyWith<$Res> {
  _$WebSearchReferenceItemCopyWithImpl(this._self, this._then);

  final WebSearchReferenceItem _self;
  final $Res Function(WebSearchReferenceItem) _then;

/// Create a copy of WebSearchReferenceItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? title = null,Object? url = null,Object? snippet = freezed,Object? content = freezed,Object? provider = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,snippet: freezed == snippet ? _self.snippet : snippet // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WebSearchReferenceItem].
extension WebSearchReferenceItemPatterns on WebSearchReferenceItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WebSearchReferenceItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WebSearchReferenceItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WebSearchReferenceItem value)  $default,){
final _that = this;
switch (_that) {
case _WebSearchReferenceItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WebSearchReferenceItem value)?  $default,){
final _that = this;
switch (_that) {
case _WebSearchReferenceItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String title,  String url,  String? snippet,  String? content,  String? provider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WebSearchReferenceItem() when $default != null:
return $default(_that.index,_that.title,_that.url,_that.snippet,_that.content,_that.provider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String title,  String url,  String? snippet,  String? content,  String? provider)  $default,) {final _that = this;
switch (_that) {
case _WebSearchReferenceItem():
return $default(_that.index,_that.title,_that.url,_that.snippet,_that.content,_that.provider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String title,  String url,  String? snippet,  String? content,  String? provider)?  $default,) {final _that = this;
switch (_that) {
case _WebSearchReferenceItem() when $default != null:
return $default(_that.index,_that.title,_that.url,_that.snippet,_that.content,_that.provider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WebSearchReferenceItem implements WebSearchReferenceItem {
  const _WebSearchReferenceItem({required this.index, required this.title, required this.url, this.snippet, this.content, this.provider});
  factory _WebSearchReferenceItem.fromJson(Map<String, dynamic> json) => _$WebSearchReferenceItemFromJson(json);

@override final  int index;
@override final  String title;
@override final  String url;
@override final  String? snippet;
@override final  String? content;
@override final  String? provider;

/// Create a copy of WebSearchReferenceItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebSearchReferenceItemCopyWith<_WebSearchReferenceItem> get copyWith => __$WebSearchReferenceItemCopyWithImpl<_WebSearchReferenceItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WebSearchReferenceItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WebSearchReferenceItem&&(identical(other.index, index) || other.index == index)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.snippet, snippet) || other.snippet == snippet)&&(identical(other.content, content) || other.content == content)&&(identical(other.provider, provider) || other.provider == provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,title,url,snippet,content,provider);

@override
String toString() {
  return 'WebSearchReferenceItem(index: $index, title: $title, url: $url, snippet: $snippet, content: $content, provider: $provider)';
}


}

/// @nodoc
abstract mixin class _$WebSearchReferenceItemCopyWith<$Res> implements $WebSearchReferenceItemCopyWith<$Res> {
  factory _$WebSearchReferenceItemCopyWith(_WebSearchReferenceItem value, $Res Function(_WebSearchReferenceItem) _then) = __$WebSearchReferenceItemCopyWithImpl;
@override @useResult
$Res call({
 int index, String title, String url, String? snippet, String? content, String? provider
});




}
/// @nodoc
class __$WebSearchReferenceItemCopyWithImpl<$Res>
    implements _$WebSearchReferenceItemCopyWith<$Res> {
  __$WebSearchReferenceItemCopyWithImpl(this._self, this._then);

  final _WebSearchReferenceItem _self;
  final $Res Function(_WebSearchReferenceItem) _then;

/// Create a copy of WebSearchReferenceItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? title = null,Object? url = null,Object? snippet = freezed,Object? content = freezed,Object? provider = freezed,}) {
  return _then(_WebSearchReferenceItem(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,snippet: freezed == snippet ? _self.snippet : snippet // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
