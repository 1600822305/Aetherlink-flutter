// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_chat_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LlmChatRequest {

 Model get model; List<LlmMessage> get messages; String? get system; double? get temperature; int? get maxTokens; double? get topP; bool get stream; List<McpToolDefinition>? get tools; Map<String, String>? get extraHeaders; Map<String, dynamic>? get extraBody;
/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmChatRequestCopyWith<LlmChatRequest> get copyWith => _$LlmChatRequestCopyWithImpl<LlmChatRequest>(this as LlmChatRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmChatRequest&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.system, system) || other.system == system)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.stream, stream) || other.stream == stream)&&const DeepCollectionEquality().equals(other.tools, tools)&&const DeepCollectionEquality().equals(other.extraHeaders, extraHeaders)&&const DeepCollectionEquality().equals(other.extraBody, extraBody));
}


@override
int get hashCode => Object.hash(runtimeType,model,const DeepCollectionEquality().hash(messages),system,temperature,maxTokens,topP,stream,const DeepCollectionEquality().hash(tools),const DeepCollectionEquality().hash(extraHeaders),const DeepCollectionEquality().hash(extraBody));

@override
String toString() {
  return 'LlmChatRequest(model: $model, messages: $messages, system: $system, temperature: $temperature, maxTokens: $maxTokens, topP: $topP, stream: $stream, tools: $tools, extraHeaders: $extraHeaders, extraBody: $extraBody)';
}


}

/// @nodoc
abstract mixin class $LlmChatRequestCopyWith<$Res>  {
  factory $LlmChatRequestCopyWith(LlmChatRequest value, $Res Function(LlmChatRequest) _then) = _$LlmChatRequestCopyWithImpl;
@useResult
$Res call({
 Model model, List<LlmMessage> messages, String? system, double? temperature, int? maxTokens, double? topP, bool stream, List<McpToolDefinition>? tools, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody
});


$ModelCopyWith<$Res> get model;

}
/// @nodoc
class _$LlmChatRequestCopyWithImpl<$Res>
    implements $LlmChatRequestCopyWith<$Res> {
  _$LlmChatRequestCopyWithImpl(this._self, this._then);

  final LlmChatRequest _self;
  final $Res Function(LlmChatRequest) _then;

/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? messages = null,Object? system = freezed,Object? temperature = freezed,Object? maxTokens = freezed,Object? topP = freezed,Object? stream = null,Object? tools = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,}) {
  return _then(_self.copyWith(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<LlmMessage>,system: freezed == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,topP: freezed == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double?,stream: null == stream ? _self.stream : stream // ignore: cast_nullable_to_non_nullable
as bool,tools: freezed == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<McpToolDefinition>?,extraHeaders: freezed == extraHeaders ? _self.extraHeaders : extraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,extraBody: freezed == extraBody ? _self.extraBody : extraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCopyWith<$Res> get model {
  
  return $ModelCopyWith<$Res>(_self.model, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// Adds pattern-matching-related methods to [LlmChatRequest].
extension LlmChatRequestPatterns on LlmChatRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LlmChatRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LlmChatRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LlmChatRequest value)  $default,){
final _that = this;
switch (_that) {
case _LlmChatRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LlmChatRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LlmChatRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Model model,  List<LlmMessage> messages,  String? system,  double? temperature,  int? maxTokens,  double? topP,  bool stream,  List<McpToolDefinition>? tools,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmChatRequest() when $default != null:
return $default(_that.model,_that.messages,_that.system,_that.temperature,_that.maxTokens,_that.topP,_that.stream,_that.tools,_that.extraHeaders,_that.extraBody);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Model model,  List<LlmMessage> messages,  String? system,  double? temperature,  int? maxTokens,  double? topP,  bool stream,  List<McpToolDefinition>? tools,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)  $default,) {final _that = this;
switch (_that) {
case _LlmChatRequest():
return $default(_that.model,_that.messages,_that.system,_that.temperature,_that.maxTokens,_that.topP,_that.stream,_that.tools,_that.extraHeaders,_that.extraBody);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Model model,  List<LlmMessage> messages,  String? system,  double? temperature,  int? maxTokens,  double? topP,  bool stream,  List<McpToolDefinition>? tools,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)?  $default,) {final _that = this;
switch (_that) {
case _LlmChatRequest() when $default != null:
return $default(_that.model,_that.messages,_that.system,_that.temperature,_that.maxTokens,_that.topP,_that.stream,_that.tools,_that.extraHeaders,_that.extraBody);case _:
  return null;

}
}

}

/// @nodoc


class _LlmChatRequest implements LlmChatRequest {
  const _LlmChatRequest({required this.model, required final  List<LlmMessage> messages, this.system, this.temperature, this.maxTokens, this.topP, this.stream = true, final  List<McpToolDefinition>? tools, final  Map<String, String>? extraHeaders, final  Map<String, dynamic>? extraBody}): _messages = messages,_tools = tools,_extraHeaders = extraHeaders,_extraBody = extraBody;
  

@override final  Model model;
 final  List<LlmMessage> _messages;
@override List<LlmMessage> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override final  String? system;
@override final  double? temperature;
@override final  int? maxTokens;
@override final  double? topP;
@override@JsonKey() final  bool stream;
 final  List<McpToolDefinition>? _tools;
@override List<McpToolDefinition>? get tools {
  final value = _tools;
  if (value == null) return null;
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  Map<String, String>? _extraHeaders;
@override Map<String, String>? get extraHeaders {
  final value = _extraHeaders;
  if (value == null) return null;
  if (_extraHeaders is EqualUnmodifiableMapView) return _extraHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _extraBody;
@override Map<String, dynamic>? get extraBody {
  final value = _extraBody;
  if (value == null) return null;
  if (_extraBody is EqualUnmodifiableMapView) return _extraBody;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LlmChatRequestCopyWith<_LlmChatRequest> get copyWith => __$LlmChatRequestCopyWithImpl<_LlmChatRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmChatRequest&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.system, system) || other.system == system)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.stream, stream) || other.stream == stream)&&const DeepCollectionEquality().equals(other._tools, _tools)&&const DeepCollectionEquality().equals(other._extraHeaders, _extraHeaders)&&const DeepCollectionEquality().equals(other._extraBody, _extraBody));
}


@override
int get hashCode => Object.hash(runtimeType,model,const DeepCollectionEquality().hash(_messages),system,temperature,maxTokens,topP,stream,const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_extraHeaders),const DeepCollectionEquality().hash(_extraBody));

@override
String toString() {
  return 'LlmChatRequest(model: $model, messages: $messages, system: $system, temperature: $temperature, maxTokens: $maxTokens, topP: $topP, stream: $stream, tools: $tools, extraHeaders: $extraHeaders, extraBody: $extraBody)';
}


}

/// @nodoc
abstract mixin class _$LlmChatRequestCopyWith<$Res> implements $LlmChatRequestCopyWith<$Res> {
  factory _$LlmChatRequestCopyWith(_LlmChatRequest value, $Res Function(_LlmChatRequest) _then) = __$LlmChatRequestCopyWithImpl;
@override @useResult
$Res call({
 Model model, List<LlmMessage> messages, String? system, double? temperature, int? maxTokens, double? topP, bool stream, List<McpToolDefinition>? tools, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody
});


@override $ModelCopyWith<$Res> get model;

}
/// @nodoc
class __$LlmChatRequestCopyWithImpl<$Res>
    implements _$LlmChatRequestCopyWith<$Res> {
  __$LlmChatRequestCopyWithImpl(this._self, this._then);

  final _LlmChatRequest _self;
  final $Res Function(_LlmChatRequest) _then;

/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? messages = null,Object? system = freezed,Object? temperature = freezed,Object? maxTokens = freezed,Object? topP = freezed,Object? stream = null,Object? tools = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,}) {
  return _then(_LlmChatRequest(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<LlmMessage>,system: freezed == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,topP: freezed == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double?,stream: null == stream ? _self.stream : stream // ignore: cast_nullable_to_non_nullable
as bool,tools: freezed == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<McpToolDefinition>?,extraHeaders: freezed == extraHeaders ? _self._extraHeaders : extraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,extraBody: freezed == extraBody ? _self._extraBody : extraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCopyWith<$Res> get model {
  
  return $ModelCopyWith<$Res>(_self.model, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}

// dart format on
