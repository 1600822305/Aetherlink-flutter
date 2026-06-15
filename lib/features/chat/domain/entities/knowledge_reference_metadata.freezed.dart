// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'knowledge_reference_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$KnowledgeReferenceMetadata {

 String? get fileName; String? get fileId; String? get knowledgeDocumentId; String? get searchQuery; bool? get isCombined; int? get resultCount; List<KnowledgeReferenceMetadataResult>? get results;
/// Create a copy of KnowledgeReferenceMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KnowledgeReferenceMetadataCopyWith<KnowledgeReferenceMetadata> get copyWith => _$KnowledgeReferenceMetadataCopyWithImpl<KnowledgeReferenceMetadata>(this as KnowledgeReferenceMetadata, _$identity);

  /// Serializes this KnowledgeReferenceMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KnowledgeReferenceMetadata&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.knowledgeDocumentId, knowledgeDocumentId) || other.knowledgeDocumentId == knowledgeDocumentId)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.isCombined, isCombined) || other.isCombined == isCombined)&&(identical(other.resultCount, resultCount) || other.resultCount == resultCount)&&const DeepCollectionEquality().equals(other.results, results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileName,fileId,knowledgeDocumentId,searchQuery,isCombined,resultCount,const DeepCollectionEquality().hash(results));

@override
String toString() {
  return 'KnowledgeReferenceMetadata(fileName: $fileName, fileId: $fileId, knowledgeDocumentId: $knowledgeDocumentId, searchQuery: $searchQuery, isCombined: $isCombined, resultCount: $resultCount, results: $results)';
}


}

/// @nodoc
abstract mixin class $KnowledgeReferenceMetadataCopyWith<$Res>  {
  factory $KnowledgeReferenceMetadataCopyWith(KnowledgeReferenceMetadata value, $Res Function(KnowledgeReferenceMetadata) _then) = _$KnowledgeReferenceMetadataCopyWithImpl;
@useResult
$Res call({
 String? fileName, String? fileId, String? knowledgeDocumentId, String? searchQuery, bool? isCombined, int? resultCount, List<KnowledgeReferenceMetadataResult>? results
});




}
/// @nodoc
class _$KnowledgeReferenceMetadataCopyWithImpl<$Res>
    implements $KnowledgeReferenceMetadataCopyWith<$Res> {
  _$KnowledgeReferenceMetadataCopyWithImpl(this._self, this._then);

  final KnowledgeReferenceMetadata _self;
  final $Res Function(KnowledgeReferenceMetadata) _then;

/// Create a copy of KnowledgeReferenceMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileName = freezed,Object? fileId = freezed,Object? knowledgeDocumentId = freezed,Object? searchQuery = freezed,Object? isCombined = freezed,Object? resultCount = freezed,Object? results = freezed,}) {
  return _then(_self.copyWith(
fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,fileId: freezed == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String?,knowledgeDocumentId: freezed == knowledgeDocumentId ? _self.knowledgeDocumentId : knowledgeDocumentId // ignore: cast_nullable_to_non_nullable
as String?,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,isCombined: freezed == isCombined ? _self.isCombined : isCombined // ignore: cast_nullable_to_non_nullable
as bool?,resultCount: freezed == resultCount ? _self.resultCount : resultCount // ignore: cast_nullable_to_non_nullable
as int?,results: freezed == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<KnowledgeReferenceMetadataResult>?,
  ));
}

}


/// Adds pattern-matching-related methods to [KnowledgeReferenceMetadata].
extension KnowledgeReferenceMetadataPatterns on KnowledgeReferenceMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KnowledgeReferenceMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KnowledgeReferenceMetadata value)  $default,){
final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KnowledgeReferenceMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? fileName,  String? fileId,  String? knowledgeDocumentId,  String? searchQuery,  bool? isCombined,  int? resultCount,  List<KnowledgeReferenceMetadataResult>? results)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadata() when $default != null:
return $default(_that.fileName,_that.fileId,_that.knowledgeDocumentId,_that.searchQuery,_that.isCombined,_that.resultCount,_that.results);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? fileName,  String? fileId,  String? knowledgeDocumentId,  String? searchQuery,  bool? isCombined,  int? resultCount,  List<KnowledgeReferenceMetadataResult>? results)  $default,) {final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadata():
return $default(_that.fileName,_that.fileId,_that.knowledgeDocumentId,_that.searchQuery,_that.isCombined,_that.resultCount,_that.results);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? fileName,  String? fileId,  String? knowledgeDocumentId,  String? searchQuery,  bool? isCombined,  int? resultCount,  List<KnowledgeReferenceMetadataResult>? results)?  $default,) {final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadata() when $default != null:
return $default(_that.fileName,_that.fileId,_that.knowledgeDocumentId,_that.searchQuery,_that.isCombined,_that.resultCount,_that.results);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KnowledgeReferenceMetadata implements KnowledgeReferenceMetadata {
  const _KnowledgeReferenceMetadata({this.fileName, this.fileId, this.knowledgeDocumentId, this.searchQuery, this.isCombined, this.resultCount, final  List<KnowledgeReferenceMetadataResult>? results}): _results = results;
  factory _KnowledgeReferenceMetadata.fromJson(Map<String, dynamic> json) => _$KnowledgeReferenceMetadataFromJson(json);

@override final  String? fileName;
@override final  String? fileId;
@override final  String? knowledgeDocumentId;
@override final  String? searchQuery;
@override final  bool? isCombined;
@override final  int? resultCount;
 final  List<KnowledgeReferenceMetadataResult>? _results;
@override List<KnowledgeReferenceMetadataResult>? get results {
  final value = _results;
  if (value == null) return null;
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of KnowledgeReferenceMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KnowledgeReferenceMetadataCopyWith<_KnowledgeReferenceMetadata> get copyWith => __$KnowledgeReferenceMetadataCopyWithImpl<_KnowledgeReferenceMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KnowledgeReferenceMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KnowledgeReferenceMetadata&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.knowledgeDocumentId, knowledgeDocumentId) || other.knowledgeDocumentId == knowledgeDocumentId)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.isCombined, isCombined) || other.isCombined == isCombined)&&(identical(other.resultCount, resultCount) || other.resultCount == resultCount)&&const DeepCollectionEquality().equals(other._results, _results));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileName,fileId,knowledgeDocumentId,searchQuery,isCombined,resultCount,const DeepCollectionEquality().hash(_results));

@override
String toString() {
  return 'KnowledgeReferenceMetadata(fileName: $fileName, fileId: $fileId, knowledgeDocumentId: $knowledgeDocumentId, searchQuery: $searchQuery, isCombined: $isCombined, resultCount: $resultCount, results: $results)';
}


}

/// @nodoc
abstract mixin class _$KnowledgeReferenceMetadataCopyWith<$Res> implements $KnowledgeReferenceMetadataCopyWith<$Res> {
  factory _$KnowledgeReferenceMetadataCopyWith(_KnowledgeReferenceMetadata value, $Res Function(_KnowledgeReferenceMetadata) _then) = __$KnowledgeReferenceMetadataCopyWithImpl;
@override @useResult
$Res call({
 String? fileName, String? fileId, String? knowledgeDocumentId, String? searchQuery, bool? isCombined, int? resultCount, List<KnowledgeReferenceMetadataResult>? results
});




}
/// @nodoc
class __$KnowledgeReferenceMetadataCopyWithImpl<$Res>
    implements _$KnowledgeReferenceMetadataCopyWith<$Res> {
  __$KnowledgeReferenceMetadataCopyWithImpl(this._self, this._then);

  final _KnowledgeReferenceMetadata _self;
  final $Res Function(_KnowledgeReferenceMetadata) _then;

/// Create a copy of KnowledgeReferenceMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileName = freezed,Object? fileId = freezed,Object? knowledgeDocumentId = freezed,Object? searchQuery = freezed,Object? isCombined = freezed,Object? resultCount = freezed,Object? results = freezed,}) {
  return _then(_KnowledgeReferenceMetadata(
fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,fileId: freezed == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String?,knowledgeDocumentId: freezed == knowledgeDocumentId ? _self.knowledgeDocumentId : knowledgeDocumentId // ignore: cast_nullable_to_non_nullable
as String?,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,isCombined: freezed == isCombined ? _self.isCombined : isCombined // ignore: cast_nullable_to_non_nullable
as bool?,resultCount: freezed == resultCount ? _self.resultCount : resultCount // ignore: cast_nullable_to_non_nullable
as int?,results: freezed == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<KnowledgeReferenceMetadataResult>?,
  ));
}


}


/// @nodoc
mixin _$KnowledgeReferenceMetadataResult {

 int get index; String get content; double get similarity; String? get documentId;
/// Create a copy of KnowledgeReferenceMetadataResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KnowledgeReferenceMetadataResultCopyWith<KnowledgeReferenceMetadataResult> get copyWith => _$KnowledgeReferenceMetadataResultCopyWithImpl<KnowledgeReferenceMetadataResult>(this as KnowledgeReferenceMetadataResult, _$identity);

  /// Serializes this KnowledgeReferenceMetadataResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KnowledgeReferenceMetadataResult&&(identical(other.index, index) || other.index == index)&&(identical(other.content, content) || other.content == content)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.documentId, documentId) || other.documentId == documentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,content,similarity,documentId);

@override
String toString() {
  return 'KnowledgeReferenceMetadataResult(index: $index, content: $content, similarity: $similarity, documentId: $documentId)';
}


}

/// @nodoc
abstract mixin class $KnowledgeReferenceMetadataResultCopyWith<$Res>  {
  factory $KnowledgeReferenceMetadataResultCopyWith(KnowledgeReferenceMetadataResult value, $Res Function(KnowledgeReferenceMetadataResult) _then) = _$KnowledgeReferenceMetadataResultCopyWithImpl;
@useResult
$Res call({
 int index, String content, double similarity, String? documentId
});




}
/// @nodoc
class _$KnowledgeReferenceMetadataResultCopyWithImpl<$Res>
    implements $KnowledgeReferenceMetadataResultCopyWith<$Res> {
  _$KnowledgeReferenceMetadataResultCopyWithImpl(this._self, this._then);

  final KnowledgeReferenceMetadataResult _self;
  final $Res Function(KnowledgeReferenceMetadataResult) _then;

/// Create a copy of KnowledgeReferenceMetadataResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? content = null,Object? similarity = null,Object? documentId = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,similarity: null == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double,documentId: freezed == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KnowledgeReferenceMetadataResult].
extension KnowledgeReferenceMetadataResultPatterns on KnowledgeReferenceMetadataResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KnowledgeReferenceMetadataResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadataResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KnowledgeReferenceMetadataResult value)  $default,){
final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadataResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KnowledgeReferenceMetadataResult value)?  $default,){
final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadataResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String content,  double similarity,  String? documentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadataResult() when $default != null:
return $default(_that.index,_that.content,_that.similarity,_that.documentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String content,  double similarity,  String? documentId)  $default,) {final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadataResult():
return $default(_that.index,_that.content,_that.similarity,_that.documentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String content,  double similarity,  String? documentId)?  $default,) {final _that = this;
switch (_that) {
case _KnowledgeReferenceMetadataResult() when $default != null:
return $default(_that.index,_that.content,_that.similarity,_that.documentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KnowledgeReferenceMetadataResult implements KnowledgeReferenceMetadataResult {
  const _KnowledgeReferenceMetadataResult({required this.index, required this.content, required this.similarity, this.documentId});
  factory _KnowledgeReferenceMetadataResult.fromJson(Map<String, dynamic> json) => _$KnowledgeReferenceMetadataResultFromJson(json);

@override final  int index;
@override final  String content;
@override final  double similarity;
@override final  String? documentId;

/// Create a copy of KnowledgeReferenceMetadataResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KnowledgeReferenceMetadataResultCopyWith<_KnowledgeReferenceMetadataResult> get copyWith => __$KnowledgeReferenceMetadataResultCopyWithImpl<_KnowledgeReferenceMetadataResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KnowledgeReferenceMetadataResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KnowledgeReferenceMetadataResult&&(identical(other.index, index) || other.index == index)&&(identical(other.content, content) || other.content == content)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.documentId, documentId) || other.documentId == documentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,content,similarity,documentId);

@override
String toString() {
  return 'KnowledgeReferenceMetadataResult(index: $index, content: $content, similarity: $similarity, documentId: $documentId)';
}


}

/// @nodoc
abstract mixin class _$KnowledgeReferenceMetadataResultCopyWith<$Res> implements $KnowledgeReferenceMetadataResultCopyWith<$Res> {
  factory _$KnowledgeReferenceMetadataResultCopyWith(_KnowledgeReferenceMetadataResult value, $Res Function(_KnowledgeReferenceMetadataResult) _then) = __$KnowledgeReferenceMetadataResultCopyWithImpl;
@override @useResult
$Res call({
 int index, String content, double similarity, String? documentId
});




}
/// @nodoc
class __$KnowledgeReferenceMetadataResultCopyWithImpl<$Res>
    implements _$KnowledgeReferenceMetadataResultCopyWith<$Res> {
  __$KnowledgeReferenceMetadataResultCopyWithImpl(this._self, this._then);

  final _KnowledgeReferenceMetadataResult _self;
  final $Res Function(_KnowledgeReferenceMetadataResult) _then;

/// Create a copy of KnowledgeReferenceMetadataResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? content = null,Object? similarity = null,Object? documentId = freezed,}) {
  return _then(_KnowledgeReferenceMetadataResult(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,similarity: null == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double,documentId: freezed == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
