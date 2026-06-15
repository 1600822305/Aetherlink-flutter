// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Message {

 String get id; MessageRole get role; String get assistantId; String get topicId;@IsoDateTimeConverter() DateTime get createdAt;@IsoDateTimeConverter() DateTime? get updatedAt; MessageStatus get status; String? get modelId; Model? get model; String? get type; bool? get isPreset; bool? get useful; String? get askId; List<Model>? get mentions; Usage? get usage; Metrics? get metrics; List<String> get blocks; List<MessageVersion>? get versions; String? get currentVersionId; Map<String, dynamic>? get metadata; MultiModelMessageStyle? get multiModelMessageStyle; bool? get foldSelected;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.assistantId, assistantId) || other.assistantId == assistantId)&&(identical(other.topicId, topicId) || other.topicId == topicId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.model, model) || other.model == model)&&(identical(other.type, type) || other.type == type)&&(identical(other.isPreset, isPreset) || other.isPreset == isPreset)&&(identical(other.useful, useful) || other.useful == useful)&&(identical(other.askId, askId) || other.askId == askId)&&const DeepCollectionEquality().equals(other.mentions, mentions)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.metrics, metrics) || other.metrics == metrics)&&const DeepCollectionEquality().equals(other.blocks, blocks)&&const DeepCollectionEquality().equals(other.versions, versions)&&(identical(other.currentVersionId, currentVersionId) || other.currentVersionId == currentVersionId)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&(identical(other.multiModelMessageStyle, multiModelMessageStyle) || other.multiModelMessageStyle == multiModelMessageStyle)&&(identical(other.foldSelected, foldSelected) || other.foldSelected == foldSelected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,role,assistantId,topicId,createdAt,updatedAt,status,modelId,model,type,isPreset,useful,askId,const DeepCollectionEquality().hash(mentions),usage,metrics,const DeepCollectionEquality().hash(blocks),const DeepCollectionEquality().hash(versions),currentVersionId,const DeepCollectionEquality().hash(metadata),multiModelMessageStyle,foldSelected]);

@override
String toString() {
  return 'Message(id: $id, role: $role, assistantId: $assistantId, topicId: $topicId, createdAt: $createdAt, updatedAt: $updatedAt, status: $status, modelId: $modelId, model: $model, type: $type, isPreset: $isPreset, useful: $useful, askId: $askId, mentions: $mentions, usage: $usage, metrics: $metrics, blocks: $blocks, versions: $versions, currentVersionId: $currentVersionId, metadata: $metadata, multiModelMessageStyle: $multiModelMessageStyle, foldSelected: $foldSelected)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String id, MessageRole role, String assistantId, String topicId,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, MessageStatus status, String? modelId, Model? model, String? type, bool? isPreset, bool? useful, String? askId, List<Model>? mentions, Usage? usage, Metrics? metrics, List<String> blocks, List<MessageVersion>? versions, String? currentVersionId, Map<String, dynamic>? metadata, MultiModelMessageStyle? multiModelMessageStyle, bool? foldSelected
});


$ModelCopyWith<$Res>? get model;$UsageCopyWith<$Res>? get usage;$MetricsCopyWith<$Res>? get metrics;

}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? role = null,Object? assistantId = null,Object? topicId = null,Object? createdAt = null,Object? updatedAt = freezed,Object? status = null,Object? modelId = freezed,Object? model = freezed,Object? type = freezed,Object? isPreset = freezed,Object? useful = freezed,Object? askId = freezed,Object? mentions = freezed,Object? usage = freezed,Object? metrics = freezed,Object? blocks = null,Object? versions = freezed,Object? currentVersionId = freezed,Object? metadata = freezed,Object? multiModelMessageStyle = freezed,Object? foldSelected = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,assistantId: null == assistantId ? _self.assistantId : assistantId // ignore: cast_nullable_to_non_nullable
as String,topicId: null == topicId ? _self.topicId : topicId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,isPreset: freezed == isPreset ? _self.isPreset : isPreset // ignore: cast_nullable_to_non_nullable
as bool?,useful: freezed == useful ? _self.useful : useful // ignore: cast_nullable_to_non_nullable
as bool?,askId: freezed == askId ? _self.askId : askId // ignore: cast_nullable_to_non_nullable
as String?,mentions: freezed == mentions ? _self.mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<Model>?,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as Usage?,metrics: freezed == metrics ? _self.metrics : metrics // ignore: cast_nullable_to_non_nullable
as Metrics?,blocks: null == blocks ? _self.blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<String>,versions: freezed == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<MessageVersion>?,currentVersionId: freezed == currentVersionId ? _self.currentVersionId : currentVersionId // ignore: cast_nullable_to_non_nullable
as String?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,multiModelMessageStyle: freezed == multiModelMessageStyle ? _self.multiModelMessageStyle : multiModelMessageStyle // ignore: cast_nullable_to_non_nullable
as MultiModelMessageStyle?,foldSelected: freezed == foldSelected ? _self.foldSelected : foldSelected // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of Message
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
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $UsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetricsCopyWith<$Res>? get metrics {
    if (_self.metrics == null) {
    return null;
  }

  return $MetricsCopyWith<$Res>(_self.metrics!, (value) {
    return _then(_self.copyWith(metrics: value));
  });
}
}


/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Message value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Message value)  $default,){
final _that = this;
switch (_that) {
case _Message():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Message value)?  $default,){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MessageRole role,  String assistantId,  String topicId, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  MessageStatus status,  String? modelId,  Model? model,  String? type,  bool? isPreset,  bool? useful,  String? askId,  List<Model>? mentions,  Usage? usage,  Metrics? metrics,  List<String> blocks,  List<MessageVersion>? versions,  String? currentVersionId,  Map<String, dynamic>? metadata,  MultiModelMessageStyle? multiModelMessageStyle,  bool? foldSelected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.role,_that.assistantId,_that.topicId,_that.createdAt,_that.updatedAt,_that.status,_that.modelId,_that.model,_that.type,_that.isPreset,_that.useful,_that.askId,_that.mentions,_that.usage,_that.metrics,_that.blocks,_that.versions,_that.currentVersionId,_that.metadata,_that.multiModelMessageStyle,_that.foldSelected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MessageRole role,  String assistantId,  String topicId, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  MessageStatus status,  String? modelId,  Model? model,  String? type,  bool? isPreset,  bool? useful,  String? askId,  List<Model>? mentions,  Usage? usage,  Metrics? metrics,  List<String> blocks,  List<MessageVersion>? versions,  String? currentVersionId,  Map<String, dynamic>? metadata,  MultiModelMessageStyle? multiModelMessageStyle,  bool? foldSelected)  $default,) {final _that = this;
switch (_that) {
case _Message():
return $default(_that.id,_that.role,_that.assistantId,_that.topicId,_that.createdAt,_that.updatedAt,_that.status,_that.modelId,_that.model,_that.type,_that.isPreset,_that.useful,_that.askId,_that.mentions,_that.usage,_that.metrics,_that.blocks,_that.versions,_that.currentVersionId,_that.metadata,_that.multiModelMessageStyle,_that.foldSelected);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MessageRole role,  String assistantId,  String topicId, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  MessageStatus status,  String? modelId,  Model? model,  String? type,  bool? isPreset,  bool? useful,  String? askId,  List<Model>? mentions,  Usage? usage,  Metrics? metrics,  List<String> blocks,  List<MessageVersion>? versions,  String? currentVersionId,  Map<String, dynamic>? metadata,  MultiModelMessageStyle? multiModelMessageStyle,  bool? foldSelected)?  $default,) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.role,_that.assistantId,_that.topicId,_that.createdAt,_that.updatedAt,_that.status,_that.modelId,_that.model,_that.type,_that.isPreset,_that.useful,_that.askId,_that.mentions,_that.usage,_that.metrics,_that.blocks,_that.versions,_that.currentVersionId,_that.metadata,_that.multiModelMessageStyle,_that.foldSelected);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Message implements Message {
  const _Message({required this.id, required this.role, required this.assistantId, required this.topicId, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, required this.status, this.modelId, this.model, this.type, this.isPreset, this.useful, this.askId, final  List<Model>? mentions, this.usage, this.metrics, final  List<String> blocks = const <String>[], final  List<MessageVersion>? versions, this.currentVersionId, final  Map<String, dynamic>? metadata, this.multiModelMessageStyle, this.foldSelected}): _mentions = mentions,_blocks = blocks,_versions = versions,_metadata = metadata;
  factory _Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

@override final  String id;
@override final  MessageRole role;
@override final  String assistantId;
@override final  String topicId;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  MessageStatus status;
@override final  String? modelId;
@override final  Model? model;
@override final  String? type;
@override final  bool? isPreset;
@override final  bool? useful;
@override final  String? askId;
 final  List<Model>? _mentions;
@override List<Model>? get mentions {
  final value = _mentions;
  if (value == null) return null;
  if (_mentions is EqualUnmodifiableListView) return _mentions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  Usage? usage;
@override final  Metrics? metrics;
 final  List<String> _blocks;
@override@JsonKey() List<String> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

 final  List<MessageVersion>? _versions;
@override List<MessageVersion>? get versions {
  final value = _versions;
  if (value == null) return null;
  if (_versions is EqualUnmodifiableListView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? currentVersionId;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  MultiModelMessageStyle? multiModelMessageStyle;
@override final  bool? foldSelected;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageCopyWith<_Message> get copyWith => __$MessageCopyWithImpl<_Message>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Message&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.assistantId, assistantId) || other.assistantId == assistantId)&&(identical(other.topicId, topicId) || other.topicId == topicId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.model, model) || other.model == model)&&(identical(other.type, type) || other.type == type)&&(identical(other.isPreset, isPreset) || other.isPreset == isPreset)&&(identical(other.useful, useful) || other.useful == useful)&&(identical(other.askId, askId) || other.askId == askId)&&const DeepCollectionEquality().equals(other._mentions, _mentions)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.metrics, metrics) || other.metrics == metrics)&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&const DeepCollectionEquality().equals(other._versions, _versions)&&(identical(other.currentVersionId, currentVersionId) || other.currentVersionId == currentVersionId)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&(identical(other.multiModelMessageStyle, multiModelMessageStyle) || other.multiModelMessageStyle == multiModelMessageStyle)&&(identical(other.foldSelected, foldSelected) || other.foldSelected == foldSelected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,role,assistantId,topicId,createdAt,updatedAt,status,modelId,model,type,isPreset,useful,askId,const DeepCollectionEquality().hash(_mentions),usage,metrics,const DeepCollectionEquality().hash(_blocks),const DeepCollectionEquality().hash(_versions),currentVersionId,const DeepCollectionEquality().hash(_metadata),multiModelMessageStyle,foldSelected]);

@override
String toString() {
  return 'Message(id: $id, role: $role, assistantId: $assistantId, topicId: $topicId, createdAt: $createdAt, updatedAt: $updatedAt, status: $status, modelId: $modelId, model: $model, type: $type, isPreset: $isPreset, useful: $useful, askId: $askId, mentions: $mentions, usage: $usage, metrics: $metrics, blocks: $blocks, versions: $versions, currentVersionId: $currentVersionId, metadata: $metadata, multiModelMessageStyle: $multiModelMessageStyle, foldSelected: $foldSelected)';
}


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) = __$MessageCopyWithImpl;
@override @useResult
$Res call({
 String id, MessageRole role, String assistantId, String topicId,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, MessageStatus status, String? modelId, Model? model, String? type, bool? isPreset, bool? useful, String? askId, List<Model>? mentions, Usage? usage, Metrics? metrics, List<String> blocks, List<MessageVersion>? versions, String? currentVersionId, Map<String, dynamic>? metadata, MultiModelMessageStyle? multiModelMessageStyle, bool? foldSelected
});


@override $ModelCopyWith<$Res>? get model;@override $UsageCopyWith<$Res>? get usage;@override $MetricsCopyWith<$Res>? get metrics;

}
/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? role = null,Object? assistantId = null,Object? topicId = null,Object? createdAt = null,Object? updatedAt = freezed,Object? status = null,Object? modelId = freezed,Object? model = freezed,Object? type = freezed,Object? isPreset = freezed,Object? useful = freezed,Object? askId = freezed,Object? mentions = freezed,Object? usage = freezed,Object? metrics = freezed,Object? blocks = null,Object? versions = freezed,Object? currentVersionId = freezed,Object? metadata = freezed,Object? multiModelMessageStyle = freezed,Object? foldSelected = freezed,}) {
  return _then(_Message(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,assistantId: null == assistantId ? _self.assistantId : assistantId // ignore: cast_nullable_to_non_nullable
as String,topicId: null == topicId ? _self.topicId : topicId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageStatus,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,isPreset: freezed == isPreset ? _self.isPreset : isPreset // ignore: cast_nullable_to_non_nullable
as bool?,useful: freezed == useful ? _self.useful : useful // ignore: cast_nullable_to_non_nullable
as bool?,askId: freezed == askId ? _self.askId : askId // ignore: cast_nullable_to_non_nullable
as String?,mentions: freezed == mentions ? _self._mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<Model>?,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as Usage?,metrics: freezed == metrics ? _self.metrics : metrics // ignore: cast_nullable_to_non_nullable
as Metrics?,blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<String>,versions: freezed == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<MessageVersion>?,currentVersionId: freezed == currentVersionId ? _self.currentVersionId : currentVersionId // ignore: cast_nullable_to_non_nullable
as String?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,multiModelMessageStyle: freezed == multiModelMessageStyle ? _self.multiModelMessageStyle : multiModelMessageStyle // ignore: cast_nullable_to_non_nullable
as MultiModelMessageStyle?,foldSelected: freezed == foldSelected ? _self.foldSelected : foldSelected // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of Message
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
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $UsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetricsCopyWith<$Res>? get metrics {
    if (_self.metrics == null) {
    return null;
  }

  return $MetricsCopyWith<$Res>(_self.metrics!, (value) {
    return _then(_self.copyWith(metrics: value));
  });
}
}

// dart format on
