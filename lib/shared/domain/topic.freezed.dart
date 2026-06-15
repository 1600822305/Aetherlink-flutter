// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'topic.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Topic {

 String get id; String get assistantId; String get name;@IsoDateTimeConverter() DateTime get createdAt;@IsoDateTimeConverter() DateTime get updatedAt; bool get isNameManuallyEdited; List<String> get messageIds; String? get lastMessageTime; String? get lastMessagePreview; String? get inputTemplate; int? get messageCount; int? get tokenCount; bool? get isDefault; bool get pinned;
/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopicCopyWith<Topic> get copyWith => _$TopicCopyWithImpl<Topic>(this as Topic, _$identity);

  /// Serializes this Topic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Topic&&(identical(other.id, id) || other.id == id)&&(identical(other.assistantId, assistantId) || other.assistantId == assistantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isNameManuallyEdited, isNameManuallyEdited) || other.isNameManuallyEdited == isNameManuallyEdited)&&const DeepCollectionEquality().equals(other.messageIds, messageIds)&&(identical(other.lastMessageTime, lastMessageTime) || other.lastMessageTime == lastMessageTime)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.inputTemplate, inputTemplate) || other.inputTemplate == inputTemplate)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount)&&(identical(other.tokenCount, tokenCount) || other.tokenCount == tokenCount)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.pinned, pinned) || other.pinned == pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,assistantId,name,createdAt,updatedAt,isNameManuallyEdited,const DeepCollectionEquality().hash(messageIds),lastMessageTime,lastMessagePreview,inputTemplate,messageCount,tokenCount,isDefault,pinned);

@override
String toString() {
  return 'Topic(id: $id, assistantId: $assistantId, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, isNameManuallyEdited: $isNameManuallyEdited, messageIds: $messageIds, lastMessageTime: $lastMessageTime, lastMessagePreview: $lastMessagePreview, inputTemplate: $inputTemplate, messageCount: $messageCount, tokenCount: $tokenCount, isDefault: $isDefault, pinned: $pinned)';
}


}

/// @nodoc
abstract mixin class $TopicCopyWith<$Res>  {
  factory $TopicCopyWith(Topic value, $Res Function(Topic) _then) = _$TopicCopyWithImpl;
@useResult
$Res call({
 String id, String assistantId, String name,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime updatedAt, bool isNameManuallyEdited, List<String> messageIds, String? lastMessageTime, String? lastMessagePreview, String? inputTemplate, int? messageCount, int? tokenCount, bool? isDefault, bool pinned
});




}
/// @nodoc
class _$TopicCopyWithImpl<$Res>
    implements $TopicCopyWith<$Res> {
  _$TopicCopyWithImpl(this._self, this._then);

  final Topic _self;
  final $Res Function(Topic) _then;

/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? assistantId = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? isNameManuallyEdited = null,Object? messageIds = null,Object? lastMessageTime = freezed,Object? lastMessagePreview = freezed,Object? inputTemplate = freezed,Object? messageCount = freezed,Object? tokenCount = freezed,Object? isDefault = freezed,Object? pinned = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,assistantId: null == assistantId ? _self.assistantId : assistantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isNameManuallyEdited: null == isNameManuallyEdited ? _self.isNameManuallyEdited : isNameManuallyEdited // ignore: cast_nullable_to_non_nullable
as bool,messageIds: null == messageIds ? _self.messageIds : messageIds // ignore: cast_nullable_to_non_nullable
as List<String>,lastMessageTime: freezed == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as String?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,inputTemplate: freezed == inputTemplate ? _self.inputTemplate : inputTemplate // ignore: cast_nullable_to_non_nullable
as String?,messageCount: freezed == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int?,tokenCount: freezed == tokenCount ? _self.tokenCount : tokenCount // ignore: cast_nullable_to_non_nullable
as int?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Topic].
extension TopicPatterns on Topic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Topic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Topic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Topic value)  $default,){
final _that = this;
switch (_that) {
case _Topic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Topic value)?  $default,){
final _that = this;
switch (_that) {
case _Topic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String assistantId,  String name, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime updatedAt,  bool isNameManuallyEdited,  List<String> messageIds,  String? lastMessageTime,  String? lastMessagePreview,  String? inputTemplate,  int? messageCount,  int? tokenCount,  bool? isDefault,  bool pinned)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Topic() when $default != null:
return $default(_that.id,_that.assistantId,_that.name,_that.createdAt,_that.updatedAt,_that.isNameManuallyEdited,_that.messageIds,_that.lastMessageTime,_that.lastMessagePreview,_that.inputTemplate,_that.messageCount,_that.tokenCount,_that.isDefault,_that.pinned);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String assistantId,  String name, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime updatedAt,  bool isNameManuallyEdited,  List<String> messageIds,  String? lastMessageTime,  String? lastMessagePreview,  String? inputTemplate,  int? messageCount,  int? tokenCount,  bool? isDefault,  bool pinned)  $default,) {final _that = this;
switch (_that) {
case _Topic():
return $default(_that.id,_that.assistantId,_that.name,_that.createdAt,_that.updatedAt,_that.isNameManuallyEdited,_that.messageIds,_that.lastMessageTime,_that.lastMessagePreview,_that.inputTemplate,_that.messageCount,_that.tokenCount,_that.isDefault,_that.pinned);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String assistantId,  String name, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime updatedAt,  bool isNameManuallyEdited,  List<String> messageIds,  String? lastMessageTime,  String? lastMessagePreview,  String? inputTemplate,  int? messageCount,  int? tokenCount,  bool? isDefault,  bool pinned)?  $default,) {final _that = this;
switch (_that) {
case _Topic() when $default != null:
return $default(_that.id,_that.assistantId,_that.name,_that.createdAt,_that.updatedAt,_that.isNameManuallyEdited,_that.messageIds,_that.lastMessageTime,_that.lastMessagePreview,_that.inputTemplate,_that.messageCount,_that.tokenCount,_that.isDefault,_that.pinned);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Topic implements Topic {
  const _Topic({required this.id, required this.assistantId, required this.name, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() required this.updatedAt, this.isNameManuallyEdited = false, final  List<String> messageIds = const <String>[], this.lastMessageTime, this.lastMessagePreview, this.inputTemplate, this.messageCount, this.tokenCount, this.isDefault, this.pinned = false}): _messageIds = messageIds;
  factory _Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

@override final  String id;
@override final  String assistantId;
@override final  String name;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime updatedAt;
@override@JsonKey() final  bool isNameManuallyEdited;
 final  List<String> _messageIds;
@override@JsonKey() List<String> get messageIds {
  if (_messageIds is EqualUnmodifiableListView) return _messageIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messageIds);
}

@override final  String? lastMessageTime;
@override final  String? lastMessagePreview;
@override final  String? inputTemplate;
@override final  int? messageCount;
@override final  int? tokenCount;
@override final  bool? isDefault;
@override@JsonKey() final  bool pinned;

/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopicCopyWith<_Topic> get copyWith => __$TopicCopyWithImpl<_Topic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Topic&&(identical(other.id, id) || other.id == id)&&(identical(other.assistantId, assistantId) || other.assistantId == assistantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isNameManuallyEdited, isNameManuallyEdited) || other.isNameManuallyEdited == isNameManuallyEdited)&&const DeepCollectionEquality().equals(other._messageIds, _messageIds)&&(identical(other.lastMessageTime, lastMessageTime) || other.lastMessageTime == lastMessageTime)&&(identical(other.lastMessagePreview, lastMessagePreview) || other.lastMessagePreview == lastMessagePreview)&&(identical(other.inputTemplate, inputTemplate) || other.inputTemplate == inputTemplate)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount)&&(identical(other.tokenCount, tokenCount) || other.tokenCount == tokenCount)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.pinned, pinned) || other.pinned == pinned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,assistantId,name,createdAt,updatedAt,isNameManuallyEdited,const DeepCollectionEquality().hash(_messageIds),lastMessageTime,lastMessagePreview,inputTemplate,messageCount,tokenCount,isDefault,pinned);

@override
String toString() {
  return 'Topic(id: $id, assistantId: $assistantId, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, isNameManuallyEdited: $isNameManuallyEdited, messageIds: $messageIds, lastMessageTime: $lastMessageTime, lastMessagePreview: $lastMessagePreview, inputTemplate: $inputTemplate, messageCount: $messageCount, tokenCount: $tokenCount, isDefault: $isDefault, pinned: $pinned)';
}


}

/// @nodoc
abstract mixin class _$TopicCopyWith<$Res> implements $TopicCopyWith<$Res> {
  factory _$TopicCopyWith(_Topic value, $Res Function(_Topic) _then) = __$TopicCopyWithImpl;
@override @useResult
$Res call({
 String id, String assistantId, String name,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime updatedAt, bool isNameManuallyEdited, List<String> messageIds, String? lastMessageTime, String? lastMessagePreview, String? inputTemplate, int? messageCount, int? tokenCount, bool? isDefault, bool pinned
});




}
/// @nodoc
class __$TopicCopyWithImpl<$Res>
    implements _$TopicCopyWith<$Res> {
  __$TopicCopyWithImpl(this._self, this._then);

  final _Topic _self;
  final $Res Function(_Topic) _then;

/// Create a copy of Topic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? assistantId = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? isNameManuallyEdited = null,Object? messageIds = null,Object? lastMessageTime = freezed,Object? lastMessagePreview = freezed,Object? inputTemplate = freezed,Object? messageCount = freezed,Object? tokenCount = freezed,Object? isDefault = freezed,Object? pinned = null,}) {
  return _then(_Topic(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,assistantId: null == assistantId ? _self.assistantId : assistantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isNameManuallyEdited: null == isNameManuallyEdited ? _self.isNameManuallyEdited : isNameManuallyEdited // ignore: cast_nullable_to_non_nullable
as bool,messageIds: null == messageIds ? _self._messageIds : messageIds // ignore: cast_nullable_to_non_nullable
as List<String>,lastMessageTime: freezed == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as String?,lastMessagePreview: freezed == lastMessagePreview ? _self.lastMessagePreview : lastMessagePreview // ignore: cast_nullable_to_non_nullable
as String?,inputTemplate: freezed == inputTemplate ? _self.inputTemplate : inputTemplate // ignore: cast_nullable_to_non_nullable
as String?,messageCount: freezed == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int?,tokenCount: freezed == tokenCount ? _self.tokenCount : tokenCount // ignore: cast_nullable_to_non_nullable
as int?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
