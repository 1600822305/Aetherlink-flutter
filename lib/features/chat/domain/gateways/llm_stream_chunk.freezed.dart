// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_stream_chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LlmStreamChunk {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmStreamChunk);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LlmStreamChunk()';
}


}

/// @nodoc
class $LlmStreamChunkCopyWith<$Res>  {
$LlmStreamChunkCopyWith(LlmStreamChunk _, $Res Function(LlmStreamChunk) __);
}


/// Adds pattern-matching-related methods to [LlmStreamChunk].
extension LlmStreamChunkPatterns on LlmStreamChunk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LlmTextDelta value)?  textDelta,TResult Function( LlmReasoningDelta value)?  reasoningDelta,TResult Function( LlmToolCallChunk value)?  toolCall,TResult Function( LlmDone value)?  done,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LlmTextDelta() when textDelta != null:
return textDelta(_that);case LlmReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that);case LlmToolCallChunk() when toolCall != null:
return toolCall(_that);case LlmDone() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LlmTextDelta value)  textDelta,required TResult Function( LlmReasoningDelta value)  reasoningDelta,required TResult Function( LlmToolCallChunk value)  toolCall,required TResult Function( LlmDone value)  done,}){
final _that = this;
switch (_that) {
case LlmTextDelta():
return textDelta(_that);case LlmReasoningDelta():
return reasoningDelta(_that);case LlmToolCallChunk():
return toolCall(_that);case LlmDone():
return done(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LlmTextDelta value)?  textDelta,TResult? Function( LlmReasoningDelta value)?  reasoningDelta,TResult? Function( LlmToolCallChunk value)?  toolCall,TResult? Function( LlmDone value)?  done,}){
final _that = this;
switch (_that) {
case LlmTextDelta() when textDelta != null:
return textDelta(_that);case LlmReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that);case LlmToolCallChunk() when toolCall != null:
return toolCall(_that);case LlmDone() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  textDelta,TResult Function( String text)?  reasoningDelta,TResult Function( LlmToolCall call)?  toolCall,TResult Function( Usage? usage,  String? finishReason)?  done,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LlmTextDelta() when textDelta != null:
return textDelta(_that.text);case LlmReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that.text);case LlmToolCallChunk() when toolCall != null:
return toolCall(_that.call);case LlmDone() when done != null:
return done(_that.usage,_that.finishReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  textDelta,required TResult Function( String text)  reasoningDelta,required TResult Function( LlmToolCall call)  toolCall,required TResult Function( Usage? usage,  String? finishReason)  done,}) {final _that = this;
switch (_that) {
case LlmTextDelta():
return textDelta(_that.text);case LlmReasoningDelta():
return reasoningDelta(_that.text);case LlmToolCallChunk():
return toolCall(_that.call);case LlmDone():
return done(_that.usage,_that.finishReason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  textDelta,TResult? Function( String text)?  reasoningDelta,TResult? Function( LlmToolCall call)?  toolCall,TResult? Function( Usage? usage,  String? finishReason)?  done,}) {final _that = this;
switch (_that) {
case LlmTextDelta() when textDelta != null:
return textDelta(_that.text);case LlmReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that.text);case LlmToolCallChunk() when toolCall != null:
return toolCall(_that.call);case LlmDone() when done != null:
return done(_that.usage,_that.finishReason);case _:
  return null;

}
}

}

/// @nodoc


class LlmTextDelta implements LlmStreamChunk {
  const LlmTextDelta(this.text);
  

 final  String text;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmTextDeltaCopyWith<LlmTextDelta> get copyWith => _$LlmTextDeltaCopyWithImpl<LlmTextDelta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmTextDelta&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'LlmStreamChunk.textDelta(text: $text)';
}


}

/// @nodoc
abstract mixin class $LlmTextDeltaCopyWith<$Res> implements $LlmStreamChunkCopyWith<$Res> {
  factory $LlmTextDeltaCopyWith(LlmTextDelta value, $Res Function(LlmTextDelta) _then) = _$LlmTextDeltaCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$LlmTextDeltaCopyWithImpl<$Res>
    implements $LlmTextDeltaCopyWith<$Res> {
  _$LlmTextDeltaCopyWithImpl(this._self, this._then);

  final LlmTextDelta _self;
  final $Res Function(LlmTextDelta) _then;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(LlmTextDelta(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LlmReasoningDelta implements LlmStreamChunk {
  const LlmReasoningDelta(this.text);
  

 final  String text;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmReasoningDeltaCopyWith<LlmReasoningDelta> get copyWith => _$LlmReasoningDeltaCopyWithImpl<LlmReasoningDelta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmReasoningDelta&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'LlmStreamChunk.reasoningDelta(text: $text)';
}


}

/// @nodoc
abstract mixin class $LlmReasoningDeltaCopyWith<$Res> implements $LlmStreamChunkCopyWith<$Res> {
  factory $LlmReasoningDeltaCopyWith(LlmReasoningDelta value, $Res Function(LlmReasoningDelta) _then) = _$LlmReasoningDeltaCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$LlmReasoningDeltaCopyWithImpl<$Res>
    implements $LlmReasoningDeltaCopyWith<$Res> {
  _$LlmReasoningDeltaCopyWithImpl(this._self, this._then);

  final LlmReasoningDelta _self;
  final $Res Function(LlmReasoningDelta) _then;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(LlmReasoningDelta(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class LlmToolCallChunk implements LlmStreamChunk {
  const LlmToolCallChunk(this.call);
  

 final  LlmToolCall call;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmToolCallChunkCopyWith<LlmToolCallChunk> get copyWith => _$LlmToolCallChunkCopyWithImpl<LlmToolCallChunk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmToolCallChunk&&(identical(other.call, call) || other.call == call));
}


@override
int get hashCode => Object.hash(runtimeType,call);

@override
String toString() {
  return 'LlmStreamChunk.toolCall(call: $call)';
}


}

/// @nodoc
abstract mixin class $LlmToolCallChunkCopyWith<$Res> implements $LlmStreamChunkCopyWith<$Res> {
  factory $LlmToolCallChunkCopyWith(LlmToolCallChunk value, $Res Function(LlmToolCallChunk) _then) = _$LlmToolCallChunkCopyWithImpl;
@useResult
$Res call({
 LlmToolCall call
});




}
/// @nodoc
class _$LlmToolCallChunkCopyWithImpl<$Res>
    implements $LlmToolCallChunkCopyWith<$Res> {
  _$LlmToolCallChunkCopyWithImpl(this._self, this._then);

  final LlmToolCallChunk _self;
  final $Res Function(LlmToolCallChunk) _then;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? call = null,}) {
  return _then(LlmToolCallChunk(
null == call ? _self.call : call // ignore: cast_nullable_to_non_nullable
as LlmToolCall,
  ));
}


}

/// @nodoc


class LlmDone implements LlmStreamChunk {
  const LlmDone({this.usage, this.finishReason});
  

 final  Usage? usage;
 final  String? finishReason;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmDoneCopyWith<LlmDone> get copyWith => _$LlmDoneCopyWithImpl<LlmDone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmDone&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.finishReason, finishReason) || other.finishReason == finishReason));
}


@override
int get hashCode => Object.hash(runtimeType,usage,finishReason);

@override
String toString() {
  return 'LlmStreamChunk.done(usage: $usage, finishReason: $finishReason)';
}


}

/// @nodoc
abstract mixin class $LlmDoneCopyWith<$Res> implements $LlmStreamChunkCopyWith<$Res> {
  factory $LlmDoneCopyWith(LlmDone value, $Res Function(LlmDone) _then) = _$LlmDoneCopyWithImpl;
@useResult
$Res call({
 Usage? usage, String? finishReason
});


$UsageCopyWith<$Res>? get usage;

}
/// @nodoc
class _$LlmDoneCopyWithImpl<$Res>
    implements $LlmDoneCopyWith<$Res> {
  _$LlmDoneCopyWithImpl(this._self, this._then);

  final LlmDone _self;
  final $Res Function(LlmDone) _then;

/// Create a copy of LlmStreamChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? usage = freezed,Object? finishReason = freezed,}) {
  return _then(LlmDone(
usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as Usage?,finishReason: freezed == finishReason ? _self.finishReason : finishReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of LlmStreamChunk
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
}
}

// dart format on
