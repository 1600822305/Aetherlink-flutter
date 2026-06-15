// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'knowledge_reference_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$KnowledgeReferenceItem {

 int get index; String get content; double get similarity; String? get documentId; String? get knowledgeBaseId; String? get knowledgeBaseName; String? get sourceUrl;
/// Create a copy of KnowledgeReferenceItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KnowledgeReferenceItemCopyWith<KnowledgeReferenceItem> get copyWith => _$KnowledgeReferenceItemCopyWithImpl<KnowledgeReferenceItem>(this as KnowledgeReferenceItem, _$identity);

  /// Serializes this KnowledgeReferenceItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KnowledgeReferenceItem&&(identical(other.index, index) || other.index == index)&&(identical(other.content, content) || other.content == content)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.knowledgeBaseId, knowledgeBaseId) || other.knowledgeBaseId == knowledgeBaseId)&&(identical(other.knowledgeBaseName, knowledgeBaseName) || other.knowledgeBaseName == knowledgeBaseName)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,content,similarity,documentId,knowledgeBaseId,knowledgeBaseName,sourceUrl);

@override
String toString() {
  return 'KnowledgeReferenceItem(index: $index, content: $content, similarity: $similarity, documentId: $documentId, knowledgeBaseId: $knowledgeBaseId, knowledgeBaseName: $knowledgeBaseName, sourceUrl: $sourceUrl)';
}


}

/// @nodoc
abstract mixin class $KnowledgeReferenceItemCopyWith<$Res>  {
  factory $KnowledgeReferenceItemCopyWith(KnowledgeReferenceItem value, $Res Function(KnowledgeReferenceItem) _then) = _$KnowledgeReferenceItemCopyWithImpl;
@useResult
$Res call({
 int index, String content, double similarity, String? documentId, String? knowledgeBaseId, String? knowledgeBaseName, String? sourceUrl
});




}
/// @nodoc
class _$KnowledgeReferenceItemCopyWithImpl<$Res>
    implements $KnowledgeReferenceItemCopyWith<$Res> {
  _$KnowledgeReferenceItemCopyWithImpl(this._self, this._then);

  final KnowledgeReferenceItem _self;
  final $Res Function(KnowledgeReferenceItem) _then;

/// Create a copy of KnowledgeReferenceItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? content = null,Object? similarity = null,Object? documentId = freezed,Object? knowledgeBaseId = freezed,Object? knowledgeBaseName = freezed,Object? sourceUrl = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,similarity: null == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double,documentId: freezed == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String?,knowledgeBaseId: freezed == knowledgeBaseId ? _self.knowledgeBaseId : knowledgeBaseId // ignore: cast_nullable_to_non_nullable
as String?,knowledgeBaseName: freezed == knowledgeBaseName ? _self.knowledgeBaseName : knowledgeBaseName // ignore: cast_nullable_to_non_nullable
as String?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KnowledgeReferenceItem].
extension KnowledgeReferenceItemPatterns on KnowledgeReferenceItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KnowledgeReferenceItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KnowledgeReferenceItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KnowledgeReferenceItem value)  $default,){
final _that = this;
switch (_that) {
case _KnowledgeReferenceItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KnowledgeReferenceItem value)?  $default,){
final _that = this;
switch (_that) {
case _KnowledgeReferenceItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String content,  double similarity,  String? documentId,  String? knowledgeBaseId,  String? knowledgeBaseName,  String? sourceUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KnowledgeReferenceItem() when $default != null:
return $default(_that.index,_that.content,_that.similarity,_that.documentId,_that.knowledgeBaseId,_that.knowledgeBaseName,_that.sourceUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String content,  double similarity,  String? documentId,  String? knowledgeBaseId,  String? knowledgeBaseName,  String? sourceUrl)  $default,) {final _that = this;
switch (_that) {
case _KnowledgeReferenceItem():
return $default(_that.index,_that.content,_that.similarity,_that.documentId,_that.knowledgeBaseId,_that.knowledgeBaseName,_that.sourceUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String content,  double similarity,  String? documentId,  String? knowledgeBaseId,  String? knowledgeBaseName,  String? sourceUrl)?  $default,) {final _that = this;
switch (_that) {
case _KnowledgeReferenceItem() when $default != null:
return $default(_that.index,_that.content,_that.similarity,_that.documentId,_that.knowledgeBaseId,_that.knowledgeBaseName,_that.sourceUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KnowledgeReferenceItem implements KnowledgeReferenceItem {
  const _KnowledgeReferenceItem({required this.index, required this.content, required this.similarity, this.documentId, this.knowledgeBaseId, this.knowledgeBaseName, this.sourceUrl});
  factory _KnowledgeReferenceItem.fromJson(Map<String, dynamic> json) => _$KnowledgeReferenceItemFromJson(json);

@override final  int index;
@override final  String content;
@override final  double similarity;
@override final  String? documentId;
@override final  String? knowledgeBaseId;
@override final  String? knowledgeBaseName;
@override final  String? sourceUrl;

/// Create a copy of KnowledgeReferenceItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KnowledgeReferenceItemCopyWith<_KnowledgeReferenceItem> get copyWith => __$KnowledgeReferenceItemCopyWithImpl<_KnowledgeReferenceItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KnowledgeReferenceItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KnowledgeReferenceItem&&(identical(other.index, index) || other.index == index)&&(identical(other.content, content) || other.content == content)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.knowledgeBaseId, knowledgeBaseId) || other.knowledgeBaseId == knowledgeBaseId)&&(identical(other.knowledgeBaseName, knowledgeBaseName) || other.knowledgeBaseName == knowledgeBaseName)&&(identical(other.sourceUrl, sourceUrl) || other.sourceUrl == sourceUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,content,similarity,documentId,knowledgeBaseId,knowledgeBaseName,sourceUrl);

@override
String toString() {
  return 'KnowledgeReferenceItem(index: $index, content: $content, similarity: $similarity, documentId: $documentId, knowledgeBaseId: $knowledgeBaseId, knowledgeBaseName: $knowledgeBaseName, sourceUrl: $sourceUrl)';
}


}

/// @nodoc
abstract mixin class _$KnowledgeReferenceItemCopyWith<$Res> implements $KnowledgeReferenceItemCopyWith<$Res> {
  factory _$KnowledgeReferenceItemCopyWith(_KnowledgeReferenceItem value, $Res Function(_KnowledgeReferenceItem) _then) = __$KnowledgeReferenceItemCopyWithImpl;
@override @useResult
$Res call({
 int index, String content, double similarity, String? documentId, String? knowledgeBaseId, String? knowledgeBaseName, String? sourceUrl
});




}
/// @nodoc
class __$KnowledgeReferenceItemCopyWithImpl<$Res>
    implements _$KnowledgeReferenceItemCopyWith<$Res> {
  __$KnowledgeReferenceItemCopyWithImpl(this._self, this._then);

  final _KnowledgeReferenceItem _self;
  final $Res Function(_KnowledgeReferenceItem) _then;

/// Create a copy of KnowledgeReferenceItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? content = null,Object? similarity = null,Object? documentId = freezed,Object? knowledgeBaseId = freezed,Object? knowledgeBaseName = freezed,Object? sourceUrl = freezed,}) {
  return _then(_KnowledgeReferenceItem(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,similarity: null == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double,documentId: freezed == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String?,knowledgeBaseId: freezed == knowledgeBaseId ? _self.knowledgeBaseId : knowledgeBaseId // ignore: cast_nullable_to_non_nullable
as String?,knowledgeBaseName: freezed == knowledgeBaseName ? _self.knowledgeBaseName : knowledgeBaseName // ignore: cast_nullable_to_non_nullable
as String?,sourceUrl: freezed == sourceUrl ? _self.sourceUrl : sourceUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
