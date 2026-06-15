// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_capabilities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelCapabilities {

 bool? get multimodal; bool? get vision; bool? get imageGeneration; bool? get videoGeneration; bool? get webSearch; bool? get reasoning; bool? get functionCalling; bool? get toolUse; bool? get embedding; bool? get rerank; bool? get codeGen; bool? get translation; bool? get transcription;
/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelCapabilitiesCopyWith<ModelCapabilities> get copyWith => _$ModelCapabilitiesCopyWithImpl<ModelCapabilities>(this as ModelCapabilities, _$identity);

  /// Serializes this ModelCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelCapabilities&&(identical(other.multimodal, multimodal) || other.multimodal == multimodal)&&(identical(other.vision, vision) || other.vision == vision)&&(identical(other.imageGeneration, imageGeneration) || other.imageGeneration == imageGeneration)&&(identical(other.videoGeneration, videoGeneration) || other.videoGeneration == videoGeneration)&&(identical(other.webSearch, webSearch) || other.webSearch == webSearch)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.functionCalling, functionCalling) || other.functionCalling == functionCalling)&&(identical(other.toolUse, toolUse) || other.toolUse == toolUse)&&(identical(other.embedding, embedding) || other.embedding == embedding)&&(identical(other.rerank, rerank) || other.rerank == rerank)&&(identical(other.codeGen, codeGen) || other.codeGen == codeGen)&&(identical(other.translation, translation) || other.translation == translation)&&(identical(other.transcription, transcription) || other.transcription == transcription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,multimodal,vision,imageGeneration,videoGeneration,webSearch,reasoning,functionCalling,toolUse,embedding,rerank,codeGen,translation,transcription);

@override
String toString() {
  return 'ModelCapabilities(multimodal: $multimodal, vision: $vision, imageGeneration: $imageGeneration, videoGeneration: $videoGeneration, webSearch: $webSearch, reasoning: $reasoning, functionCalling: $functionCalling, toolUse: $toolUse, embedding: $embedding, rerank: $rerank, codeGen: $codeGen, translation: $translation, transcription: $transcription)';
}


}

/// @nodoc
abstract mixin class $ModelCapabilitiesCopyWith<$Res>  {
  factory $ModelCapabilitiesCopyWith(ModelCapabilities value, $Res Function(ModelCapabilities) _then) = _$ModelCapabilitiesCopyWithImpl;
@useResult
$Res call({
 bool? multimodal, bool? vision, bool? imageGeneration, bool? videoGeneration, bool? webSearch, bool? reasoning, bool? functionCalling, bool? toolUse, bool? embedding, bool? rerank, bool? codeGen, bool? translation, bool? transcription
});




}
/// @nodoc
class _$ModelCapabilitiesCopyWithImpl<$Res>
    implements $ModelCapabilitiesCopyWith<$Res> {
  _$ModelCapabilitiesCopyWithImpl(this._self, this._then);

  final ModelCapabilities _self;
  final $Res Function(ModelCapabilities) _then;

/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? multimodal = freezed,Object? vision = freezed,Object? imageGeneration = freezed,Object? videoGeneration = freezed,Object? webSearch = freezed,Object? reasoning = freezed,Object? functionCalling = freezed,Object? toolUse = freezed,Object? embedding = freezed,Object? rerank = freezed,Object? codeGen = freezed,Object? translation = freezed,Object? transcription = freezed,}) {
  return _then(_self.copyWith(
multimodal: freezed == multimodal ? _self.multimodal : multimodal // ignore: cast_nullable_to_non_nullable
as bool?,vision: freezed == vision ? _self.vision : vision // ignore: cast_nullable_to_non_nullable
as bool?,imageGeneration: freezed == imageGeneration ? _self.imageGeneration : imageGeneration // ignore: cast_nullable_to_non_nullable
as bool?,videoGeneration: freezed == videoGeneration ? _self.videoGeneration : videoGeneration // ignore: cast_nullable_to_non_nullable
as bool?,webSearch: freezed == webSearch ? _self.webSearch : webSearch // ignore: cast_nullable_to_non_nullable
as bool?,reasoning: freezed == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool?,functionCalling: freezed == functionCalling ? _self.functionCalling : functionCalling // ignore: cast_nullable_to_non_nullable
as bool?,toolUse: freezed == toolUse ? _self.toolUse : toolUse // ignore: cast_nullable_to_non_nullable
as bool?,embedding: freezed == embedding ? _self.embedding : embedding // ignore: cast_nullable_to_non_nullable
as bool?,rerank: freezed == rerank ? _self.rerank : rerank // ignore: cast_nullable_to_non_nullable
as bool?,codeGen: freezed == codeGen ? _self.codeGen : codeGen // ignore: cast_nullable_to_non_nullable
as bool?,translation: freezed == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as bool?,transcription: freezed == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelCapabilities].
extension ModelCapabilitiesPatterns on ModelCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _ModelCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool? multimodal,  bool? vision,  bool? imageGeneration,  bool? videoGeneration,  bool? webSearch,  bool? reasoning,  bool? functionCalling,  bool? toolUse,  bool? embedding,  bool? rerank,  bool? codeGen,  bool? translation,  bool? transcription)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
return $default(_that.multimodal,_that.vision,_that.imageGeneration,_that.videoGeneration,_that.webSearch,_that.reasoning,_that.functionCalling,_that.toolUse,_that.embedding,_that.rerank,_that.codeGen,_that.translation,_that.transcription);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool? multimodal,  bool? vision,  bool? imageGeneration,  bool? videoGeneration,  bool? webSearch,  bool? reasoning,  bool? functionCalling,  bool? toolUse,  bool? embedding,  bool? rerank,  bool? codeGen,  bool? translation,  bool? transcription)  $default,) {final _that = this;
switch (_that) {
case _ModelCapabilities():
return $default(_that.multimodal,_that.vision,_that.imageGeneration,_that.videoGeneration,_that.webSearch,_that.reasoning,_that.functionCalling,_that.toolUse,_that.embedding,_that.rerank,_that.codeGen,_that.translation,_that.transcription);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool? multimodal,  bool? vision,  bool? imageGeneration,  bool? videoGeneration,  bool? webSearch,  bool? reasoning,  bool? functionCalling,  bool? toolUse,  bool? embedding,  bool? rerank,  bool? codeGen,  bool? translation,  bool? transcription)?  $default,) {final _that = this;
switch (_that) {
case _ModelCapabilities() when $default != null:
return $default(_that.multimodal,_that.vision,_that.imageGeneration,_that.videoGeneration,_that.webSearch,_that.reasoning,_that.functionCalling,_that.toolUse,_that.embedding,_that.rerank,_that.codeGen,_that.translation,_that.transcription);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelCapabilities implements ModelCapabilities {
  const _ModelCapabilities({this.multimodal, this.vision, this.imageGeneration, this.videoGeneration, this.webSearch, this.reasoning, this.functionCalling, this.toolUse, this.embedding, this.rerank, this.codeGen, this.translation, this.transcription});
  factory _ModelCapabilities.fromJson(Map<String, dynamic> json) => _$ModelCapabilitiesFromJson(json);

@override final  bool? multimodal;
@override final  bool? vision;
@override final  bool? imageGeneration;
@override final  bool? videoGeneration;
@override final  bool? webSearch;
@override final  bool? reasoning;
@override final  bool? functionCalling;
@override final  bool? toolUse;
@override final  bool? embedding;
@override final  bool? rerank;
@override final  bool? codeGen;
@override final  bool? translation;
@override final  bool? transcription;

/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelCapabilitiesCopyWith<_ModelCapabilities> get copyWith => __$ModelCapabilitiesCopyWithImpl<_ModelCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelCapabilities&&(identical(other.multimodal, multimodal) || other.multimodal == multimodal)&&(identical(other.vision, vision) || other.vision == vision)&&(identical(other.imageGeneration, imageGeneration) || other.imageGeneration == imageGeneration)&&(identical(other.videoGeneration, videoGeneration) || other.videoGeneration == videoGeneration)&&(identical(other.webSearch, webSearch) || other.webSearch == webSearch)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.functionCalling, functionCalling) || other.functionCalling == functionCalling)&&(identical(other.toolUse, toolUse) || other.toolUse == toolUse)&&(identical(other.embedding, embedding) || other.embedding == embedding)&&(identical(other.rerank, rerank) || other.rerank == rerank)&&(identical(other.codeGen, codeGen) || other.codeGen == codeGen)&&(identical(other.translation, translation) || other.translation == translation)&&(identical(other.transcription, transcription) || other.transcription == transcription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,multimodal,vision,imageGeneration,videoGeneration,webSearch,reasoning,functionCalling,toolUse,embedding,rerank,codeGen,translation,transcription);

@override
String toString() {
  return 'ModelCapabilities(multimodal: $multimodal, vision: $vision, imageGeneration: $imageGeneration, videoGeneration: $videoGeneration, webSearch: $webSearch, reasoning: $reasoning, functionCalling: $functionCalling, toolUse: $toolUse, embedding: $embedding, rerank: $rerank, codeGen: $codeGen, translation: $translation, transcription: $transcription)';
}


}

/// @nodoc
abstract mixin class _$ModelCapabilitiesCopyWith<$Res> implements $ModelCapabilitiesCopyWith<$Res> {
  factory _$ModelCapabilitiesCopyWith(_ModelCapabilities value, $Res Function(_ModelCapabilities) _then) = __$ModelCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 bool? multimodal, bool? vision, bool? imageGeneration, bool? videoGeneration, bool? webSearch, bool? reasoning, bool? functionCalling, bool? toolUse, bool? embedding, bool? rerank, bool? codeGen, bool? translation, bool? transcription
});




}
/// @nodoc
class __$ModelCapabilitiesCopyWithImpl<$Res>
    implements _$ModelCapabilitiesCopyWith<$Res> {
  __$ModelCapabilitiesCopyWithImpl(this._self, this._then);

  final _ModelCapabilities _self;
  final $Res Function(_ModelCapabilities) _then;

/// Create a copy of ModelCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? multimodal = freezed,Object? vision = freezed,Object? imageGeneration = freezed,Object? videoGeneration = freezed,Object? webSearch = freezed,Object? reasoning = freezed,Object? functionCalling = freezed,Object? toolUse = freezed,Object? embedding = freezed,Object? rerank = freezed,Object? codeGen = freezed,Object? translation = freezed,Object? transcription = freezed,}) {
  return _then(_ModelCapabilities(
multimodal: freezed == multimodal ? _self.multimodal : multimodal // ignore: cast_nullable_to_non_nullable
as bool?,vision: freezed == vision ? _self.vision : vision // ignore: cast_nullable_to_non_nullable
as bool?,imageGeneration: freezed == imageGeneration ? _self.imageGeneration : imageGeneration // ignore: cast_nullable_to_non_nullable
as bool?,videoGeneration: freezed == videoGeneration ? _self.videoGeneration : videoGeneration // ignore: cast_nullable_to_non_nullable
as bool?,webSearch: freezed == webSearch ? _self.webSearch : webSearch // ignore: cast_nullable_to_non_nullable
as bool?,reasoning: freezed == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as bool?,functionCalling: freezed == functionCalling ? _self.functionCalling : functionCalling // ignore: cast_nullable_to_non_nullable
as bool?,toolUse: freezed == toolUse ? _self.toolUse : toolUse // ignore: cast_nullable_to_non_nullable
as bool?,embedding: freezed == embedding ? _self.embedding : embedding // ignore: cast_nullable_to_non_nullable
as bool?,rerank: freezed == rerank ? _self.rerank : rerank // ignore: cast_nullable_to_non_nullable
as bool?,codeGen: freezed == codeGen ? _self.codeGen : codeGen // ignore: cast_nullable_to_non_nullable
as bool?,translation: freezed == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as bool?,transcription: freezed == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
