// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LlmMessage {

 MessageRole get role; String get content; List<LlmToolCall>? get toolCalls; String? get toolCallId; String? get toolName;
/// Create a copy of LlmMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmMessageCopyWith<LlmMessage> get copyWith => _$LlmMessageCopyWithImpl<LlmMessage>(this as LlmMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content)&&const DeepCollectionEquality().equals(other.toolCalls, toolCalls)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolName, toolName) || other.toolName == toolName));
}


@override
int get hashCode => Object.hash(runtimeType,role,content,const DeepCollectionEquality().hash(toolCalls),toolCallId,toolName);

@override
String toString() {
  return 'LlmMessage(role: $role, content: $content, toolCalls: $toolCalls, toolCallId: $toolCallId, toolName: $toolName)';
}


}

/// @nodoc
abstract mixin class $LlmMessageCopyWith<$Res>  {
  factory $LlmMessageCopyWith(LlmMessage value, $Res Function(LlmMessage) _then) = _$LlmMessageCopyWithImpl;
@useResult
$Res call({
 MessageRole role, String content, List<LlmToolCall>? toolCalls, String? toolCallId, String? toolName
});




}
/// @nodoc
class _$LlmMessageCopyWithImpl<$Res>
    implements $LlmMessageCopyWith<$Res> {
  _$LlmMessageCopyWithImpl(this._self, this._then);

  final LlmMessage _self;
  final $Res Function(LlmMessage) _then;

/// Create a copy of LlmMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? content = null,Object? toolCalls = freezed,Object? toolCallId = freezed,Object? toolName = freezed,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,toolCalls: freezed == toolCalls ? _self.toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<LlmToolCall>?,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LlmMessage].
extension LlmMessagePatterns on LlmMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmMessage value)  $default,){
final _that = this;
switch (_that) {
case _LlmMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmMessage value)?  $default,){
final _that = this;
switch (_that) {
case _LlmMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MessageRole role,  String content,  List<LlmToolCall>? toolCalls,  String? toolCallId,  String? toolName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmMessage() when $default != null:
return $default(_that.role,_that.content,_that.toolCalls,_that.toolCallId,_that.toolName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MessageRole role,  String content,  List<LlmToolCall>? toolCalls,  String? toolCallId,  String? toolName)  $default,) {final _that = this;
switch (_that) {
case _LlmMessage():
return $default(_that.role,_that.content,_that.toolCalls,_that.toolCallId,_that.toolName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MessageRole role,  String content,  List<LlmToolCall>? toolCalls,  String? toolCallId,  String? toolName)?  $default,) {final _that = this;
switch (_that) {
case _LlmMessage() when $default != null:
return $default(_that.role,_that.content,_that.toolCalls,_that.toolCallId,_that.toolName);case _:
  return null;

}
}

}

/// @nodoc


class _LlmMessage implements LlmMessage {
  const _LlmMessage({required this.role, required this.content, final  List<LlmToolCall>? toolCalls, this.toolCallId, this.toolName}): _toolCalls = toolCalls;
  

@override final  MessageRole role;
@override final  String content;
 final  List<LlmToolCall>? _toolCalls;
@override List<LlmToolCall>? get toolCalls {
  final value = _toolCalls;
  if (value == null) return null;
  if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? toolCallId;
@override final  String? toolName;

/// Create a copy of LlmMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmMessageCopyWith<_LlmMessage> get copyWith => __$LlmMessageCopyWithImpl<_LlmMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content)&&const DeepCollectionEquality().equals(other._toolCalls, _toolCalls)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolName, toolName) || other.toolName == toolName));
}


@override
int get hashCode => Object.hash(runtimeType,role,content,const DeepCollectionEquality().hash(_toolCalls),toolCallId,toolName);

@override
String toString() {
  return 'LlmMessage(role: $role, content: $content, toolCalls: $toolCalls, toolCallId: $toolCallId, toolName: $toolName)';
}


}

/// @nodoc
abstract mixin class _$LlmMessageCopyWith<$Res> implements $LlmMessageCopyWith<$Res> {
  factory _$LlmMessageCopyWith(_LlmMessage value, $Res Function(_LlmMessage) _then) = __$LlmMessageCopyWithImpl;
@override @useResult
$Res call({
 MessageRole role, String content, List<LlmToolCall>? toolCalls, String? toolCallId, String? toolName
});




}
/// @nodoc
class __$LlmMessageCopyWithImpl<$Res>
    implements _$LlmMessageCopyWith<$Res> {
  __$LlmMessageCopyWithImpl(this._self, this._then);

  final _LlmMessage _self;
  final $Res Function(_LlmMessage) _then;

/// Create a copy of LlmMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? content = null,Object? toolCalls = freezed,Object? toolCallId = freezed,Object? toolName = freezed,}) {
  return _then(_LlmMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,toolCalls: freezed == toolCalls ? _self._toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<LlmToolCall>?,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
