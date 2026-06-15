// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_version.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageVersion {

 String get id; String get messageId; List<String> get blocks;@IsoDateTimeConverter() DateTime get createdAt; String? get modelId; Model? get model; bool? get isActive; Map<String, dynamic>? get metadata;
/// Create a copy of MessageVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageVersionCopyWith<MessageVersion> get copyWith => _$MessageVersionCopyWithImpl<MessageVersion>(this as MessageVersion, _$identity);

  /// Serializes this MessageVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.model, model) || other.model == model)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&const DeepCollectionEquality().equals(other.metadata, metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,const DeepCollectionEquality().hash(blocks),createdAt,modelId,model,isActive,const DeepCollectionEquality().hash(metadata));

@override
String toString() {
  return 'MessageVersion(id: $id, messageId: $messageId, blocks: $blocks, createdAt: $createdAt, modelId: $modelId, model: $model, isActive: $isActive, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $MessageVersionCopyWith<$Res>  {
  factory $MessageVersionCopyWith(MessageVersion value, $Res Function(MessageVersion) _then) = _$MessageVersionCopyWithImpl;
@useResult
$Res call({
 String id, String messageId, List<String> blocks,@IsoDateTimeConverter() DateTime createdAt, String? modelId, Model? model, bool? isActive, Map<String, dynamic>? metadata
});


$ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$MessageVersionCopyWithImpl<$Res>
    implements $MessageVersionCopyWith<$Res> {
  _$MessageVersionCopyWithImpl(this._self, this._then);

  final MessageVersion _self;
  final $Res Function(MessageVersion) _then;

/// Create a copy of MessageVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? messageId = null,Object? blocks = null,Object? createdAt = null,Object? modelId = freezed,Object? model = freezed,Object? isActive = freezed,Object? metadata = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of MessageVersion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageVersion].
extension MessageVersionPatterns on MessageVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageVersion value)  $default,){
final _that = this;
switch (_that) {
case _MessageVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageVersion value)?  $default,){
final _that = this;
switch (_that) {
case _MessageVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String messageId,  List<String> blocks, @IsoDateTimeConverter()  DateTime createdAt,  String? modelId,  Model? model,  bool? isActive,  Map<String, dynamic>? metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageVersion() when $default != null:
return $default(_that.id,_that.messageId,_that.blocks,_that.createdAt,_that.modelId,_that.model,_that.isActive,_that.metadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String messageId,  List<String> blocks, @IsoDateTimeConverter()  DateTime createdAt,  String? modelId,  Model? model,  bool? isActive,  Map<String, dynamic>? metadata)  $default,) {final _that = this;
switch (_that) {
case _MessageVersion():
return $default(_that.id,_that.messageId,_that.blocks,_that.createdAt,_that.modelId,_that.model,_that.isActive,_that.metadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String messageId,  List<String> blocks, @IsoDateTimeConverter()  DateTime createdAt,  String? modelId,  Model? model,  bool? isActive,  Map<String, dynamic>? metadata)?  $default,) {final _that = this;
switch (_that) {
case _MessageVersion() when $default != null:
return $default(_that.id,_that.messageId,_that.blocks,_that.createdAt,_that.modelId,_that.model,_that.isActive,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageVersion implements MessageVersion {
  const _MessageVersion({required this.id, required this.messageId, final  List<String> blocks = const <String>[], @IsoDateTimeConverter() required this.createdAt, this.modelId, this.model, this.isActive, final  Map<String, dynamic>? metadata}): _blocks = blocks,_metadata = metadata;
  factory _MessageVersion.fromJson(Map<String, dynamic> json) => _$MessageVersionFromJson(json);

@override final  String id;
@override final  String messageId;
 final  List<String> _blocks;
@override@JsonKey() List<String> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

@override@IsoDateTimeConverter() final  DateTime createdAt;
@override final  String? modelId;
@override final  Model? model;
@override final  bool? isActive;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of MessageVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageVersionCopyWith<_MessageVersion> get copyWith => __$MessageVersionCopyWithImpl<_MessageVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.model, model) || other.model == model)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&const DeepCollectionEquality().equals(other._metadata, _metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,const DeepCollectionEquality().hash(_blocks),createdAt,modelId,model,isActive,const DeepCollectionEquality().hash(_metadata));

@override
String toString() {
  return 'MessageVersion(id: $id, messageId: $messageId, blocks: $blocks, createdAt: $createdAt, modelId: $modelId, model: $model, isActive: $isActive, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$MessageVersionCopyWith<$Res> implements $MessageVersionCopyWith<$Res> {
  factory _$MessageVersionCopyWith(_MessageVersion value, $Res Function(_MessageVersion) _then) = __$MessageVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, List<String> blocks,@IsoDateTimeConverter() DateTime createdAt, String? modelId, Model? model, bool? isActive, Map<String, dynamic>? metadata
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class __$MessageVersionCopyWithImpl<$Res>
    implements _$MessageVersionCopyWith<$Res> {
  __$MessageVersionCopyWithImpl(this._self, this._then);

  final _MessageVersion _self;
  final $Res Function(_MessageVersion) _then;

/// Create a copy of MessageVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? blocks = null,Object? createdAt = null,Object? modelId = freezed,Object? model = freezed,Object? isActive = freezed,Object? metadata = freezed,}) {
  return _then(_MessageVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of MessageVersion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}

// dart format on
