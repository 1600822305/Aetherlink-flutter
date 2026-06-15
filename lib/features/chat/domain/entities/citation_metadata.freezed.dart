// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'citation_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CitationMetadata {

 String? get searchQuery; List<String>? get knowledgeBaseIds; List<String>? get knowledgeBaseNames; String? get webSearchProvider;
/// Create a copy of CitationMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CitationMetadataCopyWith<CitationMetadata> get copyWith => _$CitationMetadataCopyWithImpl<CitationMetadata>(this as CitationMetadata, _$identity);

  /// Serializes this CitationMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CitationMetadata&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other.knowledgeBaseIds, knowledgeBaseIds)&&const DeepCollectionEquality().equals(other.knowledgeBaseNames, knowledgeBaseNames)&&(identical(other.webSearchProvider, webSearchProvider) || other.webSearchProvider == webSearchProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,searchQuery,const DeepCollectionEquality().hash(knowledgeBaseIds),const DeepCollectionEquality().hash(knowledgeBaseNames),webSearchProvider);

@override
String toString() {
  return 'CitationMetadata(searchQuery: $searchQuery, knowledgeBaseIds: $knowledgeBaseIds, knowledgeBaseNames: $knowledgeBaseNames, webSearchProvider: $webSearchProvider)';
}


}

/// @nodoc
abstract mixin class $CitationMetadataCopyWith<$Res>  {
  factory $CitationMetadataCopyWith(CitationMetadata value, $Res Function(CitationMetadata) _then) = _$CitationMetadataCopyWithImpl;
@useResult
$Res call({
 String? searchQuery, List<String>? knowledgeBaseIds, List<String>? knowledgeBaseNames, String? webSearchProvider
});




}
/// @nodoc
class _$CitationMetadataCopyWithImpl<$Res>
    implements $CitationMetadataCopyWith<$Res> {
  _$CitationMetadataCopyWithImpl(this._self, this._then);

  final CitationMetadata _self;
  final $Res Function(CitationMetadata) _then;

/// Create a copy of CitationMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? searchQuery = freezed,Object? knowledgeBaseIds = freezed,Object? knowledgeBaseNames = freezed,Object? webSearchProvider = freezed,}) {
  return _then(_self.copyWith(
searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,knowledgeBaseIds: freezed == knowledgeBaseIds ? _self.knowledgeBaseIds : knowledgeBaseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,knowledgeBaseNames: freezed == knowledgeBaseNames ? _self.knowledgeBaseNames : knowledgeBaseNames // ignore: cast_nullable_to_non_nullable
as List<String>?,webSearchProvider: freezed == webSearchProvider ? _self.webSearchProvider : webSearchProvider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CitationMetadata].
extension CitationMetadataPatterns on CitationMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CitationMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CitationMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CitationMetadata value)  $default,){
final _that = this;
switch (_that) {
case _CitationMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CitationMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _CitationMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? searchQuery,  List<String>? knowledgeBaseIds,  List<String>? knowledgeBaseNames,  String? webSearchProvider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CitationMetadata() when $default != null:
return $default(_that.searchQuery,_that.knowledgeBaseIds,_that.knowledgeBaseNames,_that.webSearchProvider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? searchQuery,  List<String>? knowledgeBaseIds,  List<String>? knowledgeBaseNames,  String? webSearchProvider)  $default,) {final _that = this;
switch (_that) {
case _CitationMetadata():
return $default(_that.searchQuery,_that.knowledgeBaseIds,_that.knowledgeBaseNames,_that.webSearchProvider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? searchQuery,  List<String>? knowledgeBaseIds,  List<String>? knowledgeBaseNames,  String? webSearchProvider)?  $default,) {final _that = this;
switch (_that) {
case _CitationMetadata() when $default != null:
return $default(_that.searchQuery,_that.knowledgeBaseIds,_that.knowledgeBaseNames,_that.webSearchProvider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CitationMetadata implements CitationMetadata {
  const _CitationMetadata({this.searchQuery, final  List<String>? knowledgeBaseIds, final  List<String>? knowledgeBaseNames, this.webSearchProvider}): _knowledgeBaseIds = knowledgeBaseIds,_knowledgeBaseNames = knowledgeBaseNames;
  factory _CitationMetadata.fromJson(Map<String, dynamic> json) => _$CitationMetadataFromJson(json);

@override final  String? searchQuery;
 final  List<String>? _knowledgeBaseIds;
@override List<String>? get knowledgeBaseIds {
  final value = _knowledgeBaseIds;
  if (value == null) return null;
  if (_knowledgeBaseIds is EqualUnmodifiableListView) return _knowledgeBaseIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _knowledgeBaseNames;
@override List<String>? get knowledgeBaseNames {
  final value = _knowledgeBaseNames;
  if (value == null) return null;
  if (_knowledgeBaseNames is EqualUnmodifiableListView) return _knowledgeBaseNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? webSearchProvider;

/// Create a copy of CitationMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CitationMetadataCopyWith<_CitationMetadata> get copyWith => __$CitationMetadataCopyWithImpl<_CitationMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CitationMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CitationMetadata&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other._knowledgeBaseIds, _knowledgeBaseIds)&&const DeepCollectionEquality().equals(other._knowledgeBaseNames, _knowledgeBaseNames)&&(identical(other.webSearchProvider, webSearchProvider) || other.webSearchProvider == webSearchProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,searchQuery,const DeepCollectionEquality().hash(_knowledgeBaseIds),const DeepCollectionEquality().hash(_knowledgeBaseNames),webSearchProvider);

@override
String toString() {
  return 'CitationMetadata(searchQuery: $searchQuery, knowledgeBaseIds: $knowledgeBaseIds, knowledgeBaseNames: $knowledgeBaseNames, webSearchProvider: $webSearchProvider)';
}


}

/// @nodoc
abstract mixin class _$CitationMetadataCopyWith<$Res> implements $CitationMetadataCopyWith<$Res> {
  factory _$CitationMetadataCopyWith(_CitationMetadata value, $Res Function(_CitationMetadata) _then) = __$CitationMetadataCopyWithImpl;
@override @useResult
$Res call({
 String? searchQuery, List<String>? knowledgeBaseIds, List<String>? knowledgeBaseNames, String? webSearchProvider
});




}
/// @nodoc
class __$CitationMetadataCopyWithImpl<$Res>
    implements _$CitationMetadataCopyWith<$Res> {
  __$CitationMetadataCopyWithImpl(this._self, this._then);

  final _CitationMetadata _self;
  final $Res Function(_CitationMetadata) _then;

/// Create a copy of CitationMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? searchQuery = freezed,Object? knowledgeBaseIds = freezed,Object? knowledgeBaseNames = freezed,Object? webSearchProvider = freezed,}) {
  return _then(_CitationMetadata(
searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,knowledgeBaseIds: freezed == knowledgeBaseIds ? _self._knowledgeBaseIds : knowledgeBaseIds // ignore: cast_nullable_to_non_nullable
as List<String>?,knowledgeBaseNames: freezed == knowledgeBaseNames ? _self._knowledgeBaseNames : knowledgeBaseNames // ignore: cast_nullable_to_non_nullable
as List<String>?,webSearchProvider: freezed == webSearchProvider ? _self.webSearchProvider : webSearchProvider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
