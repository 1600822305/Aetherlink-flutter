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

 Model get model; List<LlmMessage> get messages; String? get system; double? get temperature; int? get maxTokens; double? get topP; int? get topK; double? get frequencyPenalty; double? get presencePenalty; int? get seed; List<String>? get stopSequences; String? get responseFormat; bool? get parallelToolCalls; bool? get logprobs; String? get user; String? get reasoningEffort; int? get thinkingBudget; bool? get includeThoughts; bool? get cacheControl; String? get structuredOutputMode; bool? get webSearchEnabled; bool? get codeExecutionEnabled; bool? get useSearchGrounding; String? get safetyLevel; Map<String, dynamic>? get customParameters; bool get stream; bool get useResponsesAPI; List<McpToolDefinition>? get tools; Map<String, String>? get extraHeaders; Map<String, dynamic>? get extraBody;
/// Create a copy of LlmChatRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LlmChatRequestCopyWith<LlmChatRequest> get copyWith => _$LlmChatRequestCopyWithImpl<LlmChatRequest>(this as LlmChatRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LlmChatRequest&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.system, system) || other.system == system)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.topK, topK) || other.topK == topK)&&(identical(other.frequencyPenalty, frequencyPenalty) || other.frequencyPenalty == frequencyPenalty)&&(identical(other.presencePenalty, presencePenalty) || other.presencePenalty == presencePenalty)&&(identical(other.seed, seed) || other.seed == seed)&&const DeepCollectionEquality().equals(other.stopSequences, stopSequences)&&(identical(other.responseFormat, responseFormat) || other.responseFormat == responseFormat)&&(identical(other.parallelToolCalls, parallelToolCalls) || other.parallelToolCalls == parallelToolCalls)&&(identical(other.logprobs, logprobs) || other.logprobs == logprobs)&&(identical(other.user, user) || other.user == user)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.thinkingBudget, thinkingBudget) || other.thinkingBudget == thinkingBudget)&&(identical(other.includeThoughts, includeThoughts) || other.includeThoughts == includeThoughts)&&(identical(other.cacheControl, cacheControl) || other.cacheControl == cacheControl)&&(identical(other.structuredOutputMode, structuredOutputMode) || other.structuredOutputMode == structuredOutputMode)&&(identical(other.webSearchEnabled, webSearchEnabled) || other.webSearchEnabled == webSearchEnabled)&&(identical(other.codeExecutionEnabled, codeExecutionEnabled) || other.codeExecutionEnabled == codeExecutionEnabled)&&(identical(other.useSearchGrounding, useSearchGrounding) || other.useSearchGrounding == useSearchGrounding)&&(identical(other.safetyLevel, safetyLevel) || other.safetyLevel == safetyLevel)&&const DeepCollectionEquality().equals(other.customParameters, customParameters)&&(identical(other.stream, stream) || other.stream == stream)&&(identical(other.useResponsesAPI, useResponsesAPI) || other.useResponsesAPI == useResponsesAPI)&&const DeepCollectionEquality().equals(other.tools, tools)&&const DeepCollectionEquality().equals(other.extraHeaders, extraHeaders)&&const DeepCollectionEquality().equals(other.extraBody, extraBody));
}


@override
int get hashCode => Object.hashAll([runtimeType,model,const DeepCollectionEquality().hash(messages),system,temperature,maxTokens,topP,topK,frequencyPenalty,presencePenalty,seed,const DeepCollectionEquality().hash(stopSequences),responseFormat,parallelToolCalls,logprobs,user,reasoningEffort,thinkingBudget,includeThoughts,cacheControl,structuredOutputMode,webSearchEnabled,codeExecutionEnabled,useSearchGrounding,safetyLevel,const DeepCollectionEquality().hash(customParameters),stream,useResponsesAPI,const DeepCollectionEquality().hash(tools),const DeepCollectionEquality().hash(extraHeaders),const DeepCollectionEquality().hash(extraBody)]);

@override
String toString() {
  return 'LlmChatRequest(model: $model, messages: $messages, system: $system, temperature: $temperature, maxTokens: $maxTokens, topP: $topP, topK: $topK, frequencyPenalty: $frequencyPenalty, presencePenalty: $presencePenalty, seed: $seed, stopSequences: $stopSequences, responseFormat: $responseFormat, parallelToolCalls: $parallelToolCalls, logprobs: $logprobs, user: $user, reasoningEffort: $reasoningEffort, thinkingBudget: $thinkingBudget, includeThoughts: $includeThoughts, cacheControl: $cacheControl, structuredOutputMode: $structuredOutputMode, webSearchEnabled: $webSearchEnabled, codeExecutionEnabled: $codeExecutionEnabled, useSearchGrounding: $useSearchGrounding, safetyLevel: $safetyLevel, customParameters: $customParameters, stream: $stream, useResponsesAPI: $useResponsesAPI, tools: $tools, extraHeaders: $extraHeaders, extraBody: $extraBody)';
}


}

/// @nodoc
abstract mixin class $LlmChatRequestCopyWith<$Res>  {
  factory $LlmChatRequestCopyWith(LlmChatRequest value, $Res Function(LlmChatRequest) _then) = _$LlmChatRequestCopyWithImpl;
@useResult
$Res call({
 Model model, List<LlmMessage> messages, String? system, double? temperature, int? maxTokens, double? topP, int? topK, double? frequencyPenalty, double? presencePenalty, int? seed, List<String>? stopSequences, String? responseFormat, bool? parallelToolCalls, bool? logprobs, String? user, String? reasoningEffort, int? thinkingBudget, bool? includeThoughts, bool? cacheControl, String? structuredOutputMode, bool? webSearchEnabled, bool? codeExecutionEnabled, bool? useSearchGrounding, String? safetyLevel, Map<String, dynamic>? customParameters, bool stream, bool useResponsesAPI, List<McpToolDefinition>? tools, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody
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
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? messages = null,Object? system = freezed,Object? temperature = freezed,Object? maxTokens = freezed,Object? topP = freezed,Object? topK = freezed,Object? frequencyPenalty = freezed,Object? presencePenalty = freezed,Object? seed = freezed,Object? stopSequences = freezed,Object? responseFormat = freezed,Object? parallelToolCalls = freezed,Object? logprobs = freezed,Object? user = freezed,Object? reasoningEffort = freezed,Object? thinkingBudget = freezed,Object? includeThoughts = freezed,Object? cacheControl = freezed,Object? structuredOutputMode = freezed,Object? webSearchEnabled = freezed,Object? codeExecutionEnabled = freezed,Object? useSearchGrounding = freezed,Object? safetyLevel = freezed,Object? customParameters = freezed,Object? stream = null,Object? useResponsesAPI = null,Object? tools = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,}) {
  return _then(_self.copyWith(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<LlmMessage>,system: freezed == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,topP: freezed == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double?,topK: freezed == topK ? _self.topK : topK // ignore: cast_nullable_to_non_nullable
as int?,frequencyPenalty: freezed == frequencyPenalty ? _self.frequencyPenalty : frequencyPenalty // ignore: cast_nullable_to_non_nullable
as double?,presencePenalty: freezed == presencePenalty ? _self.presencePenalty : presencePenalty // ignore: cast_nullable_to_non_nullable
as double?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,stopSequences: freezed == stopSequences ? _self.stopSequences : stopSequences // ignore: cast_nullable_to_non_nullable
as List<String>?,responseFormat: freezed == responseFormat ? _self.responseFormat : responseFormat // ignore: cast_nullable_to_non_nullable
as String?,parallelToolCalls: freezed == parallelToolCalls ? _self.parallelToolCalls : parallelToolCalls // ignore: cast_nullable_to_non_nullable
as bool?,logprobs: freezed == logprobs ? _self.logprobs : logprobs // ignore: cast_nullable_to_non_nullable
as bool?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String?,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,thinkingBudget: freezed == thinkingBudget ? _self.thinkingBudget : thinkingBudget // ignore: cast_nullable_to_non_nullable
as int?,includeThoughts: freezed == includeThoughts ? _self.includeThoughts : includeThoughts // ignore: cast_nullable_to_non_nullable
as bool?,cacheControl: freezed == cacheControl ? _self.cacheControl : cacheControl // ignore: cast_nullable_to_non_nullable
as bool?,structuredOutputMode: freezed == structuredOutputMode ? _self.structuredOutputMode : structuredOutputMode // ignore: cast_nullable_to_non_nullable
as String?,webSearchEnabled: freezed == webSearchEnabled ? _self.webSearchEnabled : webSearchEnabled // ignore: cast_nullable_to_non_nullable
as bool?,codeExecutionEnabled: freezed == codeExecutionEnabled ? _self.codeExecutionEnabled : codeExecutionEnabled // ignore: cast_nullable_to_non_nullable
as bool?,useSearchGrounding: freezed == useSearchGrounding ? _self.useSearchGrounding : useSearchGrounding // ignore: cast_nullable_to_non_nullable
as bool?,safetyLevel: freezed == safetyLevel ? _self.safetyLevel : safetyLevel // ignore: cast_nullable_to_non_nullable
as String?,customParameters: freezed == customParameters ? _self.customParameters : customParameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,stream: null == stream ? _self.stream : stream // ignore: cast_nullable_to_non_nullable
as bool,useResponsesAPI: null == useResponsesAPI ? _self.useResponsesAPI : useResponsesAPI // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Model model,  List<LlmMessage> messages,  String? system,  double? temperature,  int? maxTokens,  double? topP,  int? topK,  double? frequencyPenalty,  double? presencePenalty,  int? seed,  List<String>? stopSequences,  String? responseFormat,  bool? parallelToolCalls,  bool? logprobs,  String? user,  String? reasoningEffort,  int? thinkingBudget,  bool? includeThoughts,  bool? cacheControl,  String? structuredOutputMode,  bool? webSearchEnabled,  bool? codeExecutionEnabled,  bool? useSearchGrounding,  String? safetyLevel,  Map<String, dynamic>? customParameters,  bool stream,  bool useResponsesAPI,  List<McpToolDefinition>? tools,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LlmChatRequest() when $default != null:
return $default(_that.model,_that.messages,_that.system,_that.temperature,_that.maxTokens,_that.topP,_that.topK,_that.frequencyPenalty,_that.presencePenalty,_that.seed,_that.stopSequences,_that.responseFormat,_that.parallelToolCalls,_that.logprobs,_that.user,_that.reasoningEffort,_that.thinkingBudget,_that.includeThoughts,_that.cacheControl,_that.structuredOutputMode,_that.webSearchEnabled,_that.codeExecutionEnabled,_that.useSearchGrounding,_that.safetyLevel,_that.customParameters,_that.stream,_that.useResponsesAPI,_that.tools,_that.extraHeaders,_that.extraBody);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Model model,  List<LlmMessage> messages,  String? system,  double? temperature,  int? maxTokens,  double? topP,  int? topK,  double? frequencyPenalty,  double? presencePenalty,  int? seed,  List<String>? stopSequences,  String? responseFormat,  bool? parallelToolCalls,  bool? logprobs,  String? user,  String? reasoningEffort,  int? thinkingBudget,  bool? includeThoughts,  bool? cacheControl,  String? structuredOutputMode,  bool? webSearchEnabled,  bool? codeExecutionEnabled,  bool? useSearchGrounding,  String? safetyLevel,  Map<String, dynamic>? customParameters,  bool stream,  bool useResponsesAPI,  List<McpToolDefinition>? tools,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)  $default,) {final _that = this;
switch (_that) {
case _LlmChatRequest():
return $default(_that.model,_that.messages,_that.system,_that.temperature,_that.maxTokens,_that.topP,_that.topK,_that.frequencyPenalty,_that.presencePenalty,_that.seed,_that.stopSequences,_that.responseFormat,_that.parallelToolCalls,_that.logprobs,_that.user,_that.reasoningEffort,_that.thinkingBudget,_that.includeThoughts,_that.cacheControl,_that.structuredOutputMode,_that.webSearchEnabled,_that.codeExecutionEnabled,_that.useSearchGrounding,_that.safetyLevel,_that.customParameters,_that.stream,_that.useResponsesAPI,_that.tools,_that.extraHeaders,_that.extraBody);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Model model,  List<LlmMessage> messages,  String? system,  double? temperature,  int? maxTokens,  double? topP,  int? topK,  double? frequencyPenalty,  double? presencePenalty,  int? seed,  List<String>? stopSequences,  String? responseFormat,  bool? parallelToolCalls,  bool? logprobs,  String? user,  String? reasoningEffort,  int? thinkingBudget,  bool? includeThoughts,  bool? cacheControl,  String? structuredOutputMode,  bool? webSearchEnabled,  bool? codeExecutionEnabled,  bool? useSearchGrounding,  String? safetyLevel,  Map<String, dynamic>? customParameters,  bool stream,  bool useResponsesAPI,  List<McpToolDefinition>? tools,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)?  $default,) {final _that = this;
switch (_that) {
case _LlmChatRequest() when $default != null:
return $default(_that.model,_that.messages,_that.system,_that.temperature,_that.maxTokens,_that.topP,_that.topK,_that.frequencyPenalty,_that.presencePenalty,_that.seed,_that.stopSequences,_that.responseFormat,_that.parallelToolCalls,_that.logprobs,_that.user,_that.reasoningEffort,_that.thinkingBudget,_that.includeThoughts,_that.cacheControl,_that.structuredOutputMode,_that.webSearchEnabled,_that.codeExecutionEnabled,_that.useSearchGrounding,_that.safetyLevel,_that.customParameters,_that.stream,_that.useResponsesAPI,_that.tools,_that.extraHeaders,_that.extraBody);case _:
  return null;

}
}

}

/// @nodoc


class _LlmChatRequest implements LlmChatRequest {
  const _LlmChatRequest({required this.model, required final  List<LlmMessage> messages, this.system, this.temperature, this.maxTokens, this.topP, this.topK, this.frequencyPenalty, this.presencePenalty, this.seed, final  List<String>? stopSequences, this.responseFormat, this.parallelToolCalls, this.logprobs, this.user, this.reasoningEffort, this.thinkingBudget, this.includeThoughts, this.cacheControl, this.structuredOutputMode, this.webSearchEnabled, this.codeExecutionEnabled, this.useSearchGrounding, this.safetyLevel, final  Map<String, dynamic>? customParameters, this.stream = true, this.useResponsesAPI = false, final  List<McpToolDefinition>? tools, final  Map<String, String>? extraHeaders, final  Map<String, dynamic>? extraBody}): _messages = messages,_stopSequences = stopSequences,_customParameters = customParameters,_tools = tools,_extraHeaders = extraHeaders,_extraBody = extraBody;
  

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
@override final  int? topK;
@override final  double? frequencyPenalty;
@override final  double? presencePenalty;
@override final  int? seed;
 final  List<String>? _stopSequences;
@override List<String>? get stopSequences {
  final value = _stopSequences;
  if (value == null) return null;
  if (_stopSequences is EqualUnmodifiableListView) return _stopSequences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? responseFormat;
@override final  bool? parallelToolCalls;
@override final  bool? logprobs;
@override final  String? user;
@override final  String? reasoningEffort;
@override final  int? thinkingBudget;
@override final  bool? includeThoughts;
@override final  bool? cacheControl;
@override final  String? structuredOutputMode;
@override final  bool? webSearchEnabled;
@override final  bool? codeExecutionEnabled;
@override final  bool? useSearchGrounding;
@override final  String? safetyLevel;
 final  Map<String, dynamic>? _customParameters;
@override Map<String, dynamic>? get customParameters {
  final value = _customParameters;
  if (value == null) return null;
  if (_customParameters is EqualUnmodifiableMapView) return _customParameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool stream;
@override@JsonKey() final  bool useResponsesAPI;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LlmChatRequest&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.system, system) || other.system == system)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.topK, topK) || other.topK == topK)&&(identical(other.frequencyPenalty, frequencyPenalty) || other.frequencyPenalty == frequencyPenalty)&&(identical(other.presencePenalty, presencePenalty) || other.presencePenalty == presencePenalty)&&(identical(other.seed, seed) || other.seed == seed)&&const DeepCollectionEquality().equals(other._stopSequences, _stopSequences)&&(identical(other.responseFormat, responseFormat) || other.responseFormat == responseFormat)&&(identical(other.parallelToolCalls, parallelToolCalls) || other.parallelToolCalls == parallelToolCalls)&&(identical(other.logprobs, logprobs) || other.logprobs == logprobs)&&(identical(other.user, user) || other.user == user)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort)&&(identical(other.thinkingBudget, thinkingBudget) || other.thinkingBudget == thinkingBudget)&&(identical(other.includeThoughts, includeThoughts) || other.includeThoughts == includeThoughts)&&(identical(other.cacheControl, cacheControl) || other.cacheControl == cacheControl)&&(identical(other.structuredOutputMode, structuredOutputMode) || other.structuredOutputMode == structuredOutputMode)&&(identical(other.webSearchEnabled, webSearchEnabled) || other.webSearchEnabled == webSearchEnabled)&&(identical(other.codeExecutionEnabled, codeExecutionEnabled) || other.codeExecutionEnabled == codeExecutionEnabled)&&(identical(other.useSearchGrounding, useSearchGrounding) || other.useSearchGrounding == useSearchGrounding)&&(identical(other.safetyLevel, safetyLevel) || other.safetyLevel == safetyLevel)&&const DeepCollectionEquality().equals(other._customParameters, _customParameters)&&(identical(other.stream, stream) || other.stream == stream)&&(identical(other.useResponsesAPI, useResponsesAPI) || other.useResponsesAPI == useResponsesAPI)&&const DeepCollectionEquality().equals(other._tools, _tools)&&const DeepCollectionEquality().equals(other._extraHeaders, _extraHeaders)&&const DeepCollectionEquality().equals(other._extraBody, _extraBody));
}


@override
int get hashCode => Object.hashAll([runtimeType,model,const DeepCollectionEquality().hash(_messages),system,temperature,maxTokens,topP,topK,frequencyPenalty,presencePenalty,seed,const DeepCollectionEquality().hash(_stopSequences),responseFormat,parallelToolCalls,logprobs,user,reasoningEffort,thinkingBudget,includeThoughts,cacheControl,structuredOutputMode,webSearchEnabled,codeExecutionEnabled,useSearchGrounding,safetyLevel,const DeepCollectionEquality().hash(_customParameters),stream,useResponsesAPI,const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_extraHeaders),const DeepCollectionEquality().hash(_extraBody)]);

@override
String toString() {
  return 'LlmChatRequest(model: $model, messages: $messages, system: $system, temperature: $temperature, maxTokens: $maxTokens, topP: $topP, topK: $topK, frequencyPenalty: $frequencyPenalty, presencePenalty: $presencePenalty, seed: $seed, stopSequences: $stopSequences, responseFormat: $responseFormat, parallelToolCalls: $parallelToolCalls, logprobs: $logprobs, user: $user, reasoningEffort: $reasoningEffort, thinkingBudget: $thinkingBudget, includeThoughts: $includeThoughts, cacheControl: $cacheControl, structuredOutputMode: $structuredOutputMode, webSearchEnabled: $webSearchEnabled, codeExecutionEnabled: $codeExecutionEnabled, useSearchGrounding: $useSearchGrounding, safetyLevel: $safetyLevel, customParameters: $customParameters, stream: $stream, useResponsesAPI: $useResponsesAPI, tools: $tools, extraHeaders: $extraHeaders, extraBody: $extraBody)';
}


}

/// @nodoc
abstract mixin class _$LlmChatRequestCopyWith<$Res> implements $LlmChatRequestCopyWith<$Res> {
  factory _$LlmChatRequestCopyWith(_LlmChatRequest value, $Res Function(_LlmChatRequest) _then) = __$LlmChatRequestCopyWithImpl;
@override @useResult
$Res call({
 Model model, List<LlmMessage> messages, String? system, double? temperature, int? maxTokens, double? topP, int? topK, double? frequencyPenalty, double? presencePenalty, int? seed, List<String>? stopSequences, String? responseFormat, bool? parallelToolCalls, bool? logprobs, String? user, String? reasoningEffort, int? thinkingBudget, bool? includeThoughts, bool? cacheControl, String? structuredOutputMode, bool? webSearchEnabled, bool? codeExecutionEnabled, bool? useSearchGrounding, String? safetyLevel, Map<String, dynamic>? customParameters, bool stream, bool useResponsesAPI, List<McpToolDefinition>? tools, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody
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
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? messages = null,Object? system = freezed,Object? temperature = freezed,Object? maxTokens = freezed,Object? topP = freezed,Object? topK = freezed,Object? frequencyPenalty = freezed,Object? presencePenalty = freezed,Object? seed = freezed,Object? stopSequences = freezed,Object? responseFormat = freezed,Object? parallelToolCalls = freezed,Object? logprobs = freezed,Object? user = freezed,Object? reasoningEffort = freezed,Object? thinkingBudget = freezed,Object? includeThoughts = freezed,Object? cacheControl = freezed,Object? structuredOutputMode = freezed,Object? webSearchEnabled = freezed,Object? codeExecutionEnabled = freezed,Object? useSearchGrounding = freezed,Object? safetyLevel = freezed,Object? customParameters = freezed,Object? stream = null,Object? useResponsesAPI = null,Object? tools = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,}) {
  return _then(_LlmChatRequest(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<LlmMessage>,system: freezed == system ? _self.system : system // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,topP: freezed == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double?,topK: freezed == topK ? _self.topK : topK // ignore: cast_nullable_to_non_nullable
as int?,frequencyPenalty: freezed == frequencyPenalty ? _self.frequencyPenalty : frequencyPenalty // ignore: cast_nullable_to_non_nullable
as double?,presencePenalty: freezed == presencePenalty ? _self.presencePenalty : presencePenalty // ignore: cast_nullable_to_non_nullable
as double?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,stopSequences: freezed == stopSequences ? _self._stopSequences : stopSequences // ignore: cast_nullable_to_non_nullable
as List<String>?,responseFormat: freezed == responseFormat ? _self.responseFormat : responseFormat // ignore: cast_nullable_to_non_nullable
as String?,parallelToolCalls: freezed == parallelToolCalls ? _self.parallelToolCalls : parallelToolCalls // ignore: cast_nullable_to_non_nullable
as bool?,logprobs: freezed == logprobs ? _self.logprobs : logprobs // ignore: cast_nullable_to_non_nullable
as bool?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String?,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,thinkingBudget: freezed == thinkingBudget ? _self.thinkingBudget : thinkingBudget // ignore: cast_nullable_to_non_nullable
as int?,includeThoughts: freezed == includeThoughts ? _self.includeThoughts : includeThoughts // ignore: cast_nullable_to_non_nullable
as bool?,cacheControl: freezed == cacheControl ? _self.cacheControl : cacheControl // ignore: cast_nullable_to_non_nullable
as bool?,structuredOutputMode: freezed == structuredOutputMode ? _self.structuredOutputMode : structuredOutputMode // ignore: cast_nullable_to_non_nullable
as String?,webSearchEnabled: freezed == webSearchEnabled ? _self.webSearchEnabled : webSearchEnabled // ignore: cast_nullable_to_non_nullable
as bool?,codeExecutionEnabled: freezed == codeExecutionEnabled ? _self.codeExecutionEnabled : codeExecutionEnabled // ignore: cast_nullable_to_non_nullable
as bool?,useSearchGrounding: freezed == useSearchGrounding ? _self.useSearchGrounding : useSearchGrounding // ignore: cast_nullable_to_non_nullable
as bool?,safetyLevel: freezed == safetyLevel ? _self.safetyLevel : safetyLevel // ignore: cast_nullable_to_non_nullable
as String?,customParameters: freezed == customParameters ? _self._customParameters : customParameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,stream: null == stream ? _self.stream : stream // ignore: cast_nullable_to_non_nullable
as bool,useResponsesAPI: null == useResponsesAPI ? _self.useResponsesAPI : useResponsesAPI // ignore: cast_nullable_to_non_nullable
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
