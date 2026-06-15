// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Assistant {

 String get id; String get name; String? get description; String? get avatar; String? get emoji; List<String>? get tags; String? get engine; String? get model; double? get temperature; int? get maxTokens; double? get topP; double? get frequencyPenalty; double? get presencePenalty; String? get systemPrompt; String? get prompt; int? get maxMessagesInContext; bool? get isDefault; bool? get isSystem; bool? get archived;@IsoDateTimeConverter() DateTime? get createdAt;@IsoDateTimeConverter() DateTime? get updatedAt;@IsoDateTimeConverter() DateTime? get lastUsedAt; List<String> get topicIds; String? get selectedSystemPromptId; String? get mcpConfigId; List<String>? get tools;@JsonKey(name: 'tool_choice') String? get toolChoice; String? get speechModel; String? get speechVoice; double? get speechSpeed; String? get responseFormat; bool? get isLocal; String? get localModelName; String? get localModelPath; String? get localModelType;@JsonKey(name: 'file_ids') List<String>? get fileIds; String? get type; List<QuickPhrase>? get regularPhrases; String? get webSearchProviderId; bool? get enableWebSearch; List<CustomParameter>? get customParameters; List<AssistantRegex>? get regexRules; AssistantChatBackground? get chatBackground; bool? get memoryEnabled; List<String>? get skillIds; String? get activeSkillId;
/// Create a copy of Assistant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantCopyWith<Assistant> get copyWith => _$AssistantCopyWithImpl<Assistant>(this as Assistant, _$identity);

  /// Serializes this Assistant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Assistant&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.engine, engine) || other.engine == engine)&&(identical(other.model, model) || other.model == model)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.frequencyPenalty, frequencyPenalty) || other.frequencyPenalty == frequencyPenalty)&&(identical(other.presencePenalty, presencePenalty) || other.presencePenalty == presencePenalty)&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.maxMessagesInContext, maxMessagesInContext) || other.maxMessagesInContext == maxMessagesInContext)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&const DeepCollectionEquality().equals(other.topicIds, topicIds)&&(identical(other.selectedSystemPromptId, selectedSystemPromptId) || other.selectedSystemPromptId == selectedSystemPromptId)&&(identical(other.mcpConfigId, mcpConfigId) || other.mcpConfigId == mcpConfigId)&&const DeepCollectionEquality().equals(other.tools, tools)&&(identical(other.toolChoice, toolChoice) || other.toolChoice == toolChoice)&&(identical(other.speechModel, speechModel) || other.speechModel == speechModel)&&(identical(other.speechVoice, speechVoice) || other.speechVoice == speechVoice)&&(identical(other.speechSpeed, speechSpeed) || other.speechSpeed == speechSpeed)&&(identical(other.responseFormat, responseFormat) || other.responseFormat == responseFormat)&&(identical(other.isLocal, isLocal) || other.isLocal == isLocal)&&(identical(other.localModelName, localModelName) || other.localModelName == localModelName)&&(identical(other.localModelPath, localModelPath) || other.localModelPath == localModelPath)&&(identical(other.localModelType, localModelType) || other.localModelType == localModelType)&&const DeepCollectionEquality().equals(other.fileIds, fileIds)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.regularPhrases, regularPhrases)&&(identical(other.webSearchProviderId, webSearchProviderId) || other.webSearchProviderId == webSearchProviderId)&&(identical(other.enableWebSearch, enableWebSearch) || other.enableWebSearch == enableWebSearch)&&const DeepCollectionEquality().equals(other.customParameters, customParameters)&&const DeepCollectionEquality().equals(other.regexRules, regexRules)&&(identical(other.chatBackground, chatBackground) || other.chatBackground == chatBackground)&&(identical(other.memoryEnabled, memoryEnabled) || other.memoryEnabled == memoryEnabled)&&const DeepCollectionEquality().equals(other.skillIds, skillIds)&&(identical(other.activeSkillId, activeSkillId) || other.activeSkillId == activeSkillId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,description,avatar,emoji,const DeepCollectionEquality().hash(tags),engine,model,temperature,maxTokens,topP,frequencyPenalty,presencePenalty,systemPrompt,prompt,maxMessagesInContext,isDefault,isSystem,archived,createdAt,updatedAt,lastUsedAt,const DeepCollectionEquality().hash(topicIds),selectedSystemPromptId,mcpConfigId,const DeepCollectionEquality().hash(tools),toolChoice,speechModel,speechVoice,speechSpeed,responseFormat,isLocal,localModelName,localModelPath,localModelType,const DeepCollectionEquality().hash(fileIds),type,const DeepCollectionEquality().hash(regularPhrases),webSearchProviderId,enableWebSearch,const DeepCollectionEquality().hash(customParameters),const DeepCollectionEquality().hash(regexRules),chatBackground,memoryEnabled,const DeepCollectionEquality().hash(skillIds),activeSkillId]);

@override
String toString() {
  return 'Assistant(id: $id, name: $name, description: $description, avatar: $avatar, emoji: $emoji, tags: $tags, engine: $engine, model: $model, temperature: $temperature, maxTokens: $maxTokens, topP: $topP, frequencyPenalty: $frequencyPenalty, presencePenalty: $presencePenalty, systemPrompt: $systemPrompt, prompt: $prompt, maxMessagesInContext: $maxMessagesInContext, isDefault: $isDefault, isSystem: $isSystem, archived: $archived, createdAt: $createdAt, updatedAt: $updatedAt, lastUsedAt: $lastUsedAt, topicIds: $topicIds, selectedSystemPromptId: $selectedSystemPromptId, mcpConfigId: $mcpConfigId, tools: $tools, toolChoice: $toolChoice, speechModel: $speechModel, speechVoice: $speechVoice, speechSpeed: $speechSpeed, responseFormat: $responseFormat, isLocal: $isLocal, localModelName: $localModelName, localModelPath: $localModelPath, localModelType: $localModelType, fileIds: $fileIds, type: $type, regularPhrases: $regularPhrases, webSearchProviderId: $webSearchProviderId, enableWebSearch: $enableWebSearch, customParameters: $customParameters, regexRules: $regexRules, chatBackground: $chatBackground, memoryEnabled: $memoryEnabled, skillIds: $skillIds, activeSkillId: $activeSkillId)';
}


}

/// @nodoc
abstract mixin class $AssistantCopyWith<$Res>  {
  factory $AssistantCopyWith(Assistant value, $Res Function(Assistant) _then) = _$AssistantCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, String? avatar, String? emoji, List<String>? tags, String? engine, String? model, double? temperature, int? maxTokens, double? topP, double? frequencyPenalty, double? presencePenalty, String? systemPrompt, String? prompt, int? maxMessagesInContext, bool? isDefault, bool? isSystem, bool? archived,@IsoDateTimeConverter() DateTime? createdAt,@IsoDateTimeConverter() DateTime? updatedAt,@IsoDateTimeConverter() DateTime? lastUsedAt, List<String> topicIds, String? selectedSystemPromptId, String? mcpConfigId, List<String>? tools,@JsonKey(name: 'tool_choice') String? toolChoice, String? speechModel, String? speechVoice, double? speechSpeed, String? responseFormat, bool? isLocal, String? localModelName, String? localModelPath, String? localModelType,@JsonKey(name: 'file_ids') List<String>? fileIds, String? type, List<QuickPhrase>? regularPhrases, String? webSearchProviderId, bool? enableWebSearch, List<CustomParameter>? customParameters, List<AssistantRegex>? regexRules, AssistantChatBackground? chatBackground, bool? memoryEnabled, List<String>? skillIds, String? activeSkillId
});


$AssistantChatBackgroundCopyWith<$Res>? get chatBackground;

}
/// @nodoc
class _$AssistantCopyWithImpl<$Res>
    implements $AssistantCopyWith<$Res> {
  _$AssistantCopyWithImpl(this._self, this._then);

  final Assistant _self;
  final $Res Function(Assistant) _then;

/// Create a copy of Assistant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? avatar = freezed,Object? emoji = freezed,Object? tags = freezed,Object? engine = freezed,Object? model = freezed,Object? temperature = freezed,Object? maxTokens = freezed,Object? topP = freezed,Object? frequencyPenalty = freezed,Object? presencePenalty = freezed,Object? systemPrompt = freezed,Object? prompt = freezed,Object? maxMessagesInContext = freezed,Object? isDefault = freezed,Object? isSystem = freezed,Object? archived = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lastUsedAt = freezed,Object? topicIds = null,Object? selectedSystemPromptId = freezed,Object? mcpConfigId = freezed,Object? tools = freezed,Object? toolChoice = freezed,Object? speechModel = freezed,Object? speechVoice = freezed,Object? speechSpeed = freezed,Object? responseFormat = freezed,Object? isLocal = freezed,Object? localModelName = freezed,Object? localModelPath = freezed,Object? localModelType = freezed,Object? fileIds = freezed,Object? type = freezed,Object? regularPhrases = freezed,Object? webSearchProviderId = freezed,Object? enableWebSearch = freezed,Object? customParameters = freezed,Object? regexRules = freezed,Object? chatBackground = freezed,Object? memoryEnabled = freezed,Object? skillIds = freezed,Object? activeSkillId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,engine: freezed == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,topP: freezed == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double?,frequencyPenalty: freezed == frequencyPenalty ? _self.frequencyPenalty : frequencyPenalty // ignore: cast_nullable_to_non_nullable
as double?,presencePenalty: freezed == presencePenalty ? _self.presencePenalty : presencePenalty // ignore: cast_nullable_to_non_nullable
as double?,systemPrompt: freezed == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,maxMessagesInContext: freezed == maxMessagesInContext ? _self.maxMessagesInContext : maxMessagesInContext // ignore: cast_nullable_to_non_nullable
as int?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,isSystem: freezed == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool?,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,topicIds: null == topicIds ? _self.topicIds : topicIds // ignore: cast_nullable_to_non_nullable
as List<String>,selectedSystemPromptId: freezed == selectedSystemPromptId ? _self.selectedSystemPromptId : selectedSystemPromptId // ignore: cast_nullable_to_non_nullable
as String?,mcpConfigId: freezed == mcpConfigId ? _self.mcpConfigId : mcpConfigId // ignore: cast_nullable_to_non_nullable
as String?,tools: freezed == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<String>?,toolChoice: freezed == toolChoice ? _self.toolChoice : toolChoice // ignore: cast_nullable_to_non_nullable
as String?,speechModel: freezed == speechModel ? _self.speechModel : speechModel // ignore: cast_nullable_to_non_nullable
as String?,speechVoice: freezed == speechVoice ? _self.speechVoice : speechVoice // ignore: cast_nullable_to_non_nullable
as String?,speechSpeed: freezed == speechSpeed ? _self.speechSpeed : speechSpeed // ignore: cast_nullable_to_non_nullable
as double?,responseFormat: freezed == responseFormat ? _self.responseFormat : responseFormat // ignore: cast_nullable_to_non_nullable
as String?,isLocal: freezed == isLocal ? _self.isLocal : isLocal // ignore: cast_nullable_to_non_nullable
as bool?,localModelName: freezed == localModelName ? _self.localModelName : localModelName // ignore: cast_nullable_to_non_nullable
as String?,localModelPath: freezed == localModelPath ? _self.localModelPath : localModelPath // ignore: cast_nullable_to_non_nullable
as String?,localModelType: freezed == localModelType ? _self.localModelType : localModelType // ignore: cast_nullable_to_non_nullable
as String?,fileIds: freezed == fileIds ? _self.fileIds : fileIds // ignore: cast_nullable_to_non_nullable
as List<String>?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,regularPhrases: freezed == regularPhrases ? _self.regularPhrases : regularPhrases // ignore: cast_nullable_to_non_nullable
as List<QuickPhrase>?,webSearchProviderId: freezed == webSearchProviderId ? _self.webSearchProviderId : webSearchProviderId // ignore: cast_nullable_to_non_nullable
as String?,enableWebSearch: freezed == enableWebSearch ? _self.enableWebSearch : enableWebSearch // ignore: cast_nullable_to_non_nullable
as bool?,customParameters: freezed == customParameters ? _self.customParameters : customParameters // ignore: cast_nullable_to_non_nullable
as List<CustomParameter>?,regexRules: freezed == regexRules ? _self.regexRules : regexRules // ignore: cast_nullable_to_non_nullable
as List<AssistantRegex>?,chatBackground: freezed == chatBackground ? _self.chatBackground : chatBackground // ignore: cast_nullable_to_non_nullable
as AssistantChatBackground?,memoryEnabled: freezed == memoryEnabled ? _self.memoryEnabled : memoryEnabled // ignore: cast_nullable_to_non_nullable
as bool?,skillIds: freezed == skillIds ? _self.skillIds : skillIds // ignore: cast_nullable_to_non_nullable
as List<String>?,activeSkillId: freezed == activeSkillId ? _self.activeSkillId : activeSkillId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Assistant
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantChatBackgroundCopyWith<$Res>? get chatBackground {
    if (_self.chatBackground == null) {
    return null;
  }

  return $AssistantChatBackgroundCopyWith<$Res>(_self.chatBackground!, (value) {
    return _then(_self.copyWith(chatBackground: value));
  });
}
}


/// Adds pattern-matching-related methods to [Assistant].
extension AssistantPatterns on Assistant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Assistant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Assistant() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Assistant value)  $default,){
final _that = this;
switch (_that) {
case _Assistant():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Assistant value)?  $default,){
final _that = this;
switch (_that) {
case _Assistant() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? avatar,  String? emoji,  List<String>? tags,  String? engine,  String? model,  double? temperature,  int? maxTokens,  double? topP,  double? frequencyPenalty,  double? presencePenalty,  String? systemPrompt,  String? prompt,  int? maxMessagesInContext,  bool? isDefault,  bool? isSystem,  bool? archived, @IsoDateTimeConverter()  DateTime? createdAt, @IsoDateTimeConverter()  DateTime? updatedAt, @IsoDateTimeConverter()  DateTime? lastUsedAt,  List<String> topicIds,  String? selectedSystemPromptId,  String? mcpConfigId,  List<String>? tools, @JsonKey(name: 'tool_choice')  String? toolChoice,  String? speechModel,  String? speechVoice,  double? speechSpeed,  String? responseFormat,  bool? isLocal,  String? localModelName,  String? localModelPath,  String? localModelType, @JsonKey(name: 'file_ids')  List<String>? fileIds,  String? type,  List<QuickPhrase>? regularPhrases,  String? webSearchProviderId,  bool? enableWebSearch,  List<CustomParameter>? customParameters,  List<AssistantRegex>? regexRules,  AssistantChatBackground? chatBackground,  bool? memoryEnabled,  List<String>? skillIds,  String? activeSkillId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Assistant() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.avatar,_that.emoji,_that.tags,_that.engine,_that.model,_that.temperature,_that.maxTokens,_that.topP,_that.frequencyPenalty,_that.presencePenalty,_that.systemPrompt,_that.prompt,_that.maxMessagesInContext,_that.isDefault,_that.isSystem,_that.archived,_that.createdAt,_that.updatedAt,_that.lastUsedAt,_that.topicIds,_that.selectedSystemPromptId,_that.mcpConfigId,_that.tools,_that.toolChoice,_that.speechModel,_that.speechVoice,_that.speechSpeed,_that.responseFormat,_that.isLocal,_that.localModelName,_that.localModelPath,_that.localModelType,_that.fileIds,_that.type,_that.regularPhrases,_that.webSearchProviderId,_that.enableWebSearch,_that.customParameters,_that.regexRules,_that.chatBackground,_that.memoryEnabled,_that.skillIds,_that.activeSkillId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  String? avatar,  String? emoji,  List<String>? tags,  String? engine,  String? model,  double? temperature,  int? maxTokens,  double? topP,  double? frequencyPenalty,  double? presencePenalty,  String? systemPrompt,  String? prompt,  int? maxMessagesInContext,  bool? isDefault,  bool? isSystem,  bool? archived, @IsoDateTimeConverter()  DateTime? createdAt, @IsoDateTimeConverter()  DateTime? updatedAt, @IsoDateTimeConverter()  DateTime? lastUsedAt,  List<String> topicIds,  String? selectedSystemPromptId,  String? mcpConfigId,  List<String>? tools, @JsonKey(name: 'tool_choice')  String? toolChoice,  String? speechModel,  String? speechVoice,  double? speechSpeed,  String? responseFormat,  bool? isLocal,  String? localModelName,  String? localModelPath,  String? localModelType, @JsonKey(name: 'file_ids')  List<String>? fileIds,  String? type,  List<QuickPhrase>? regularPhrases,  String? webSearchProviderId,  bool? enableWebSearch,  List<CustomParameter>? customParameters,  List<AssistantRegex>? regexRules,  AssistantChatBackground? chatBackground,  bool? memoryEnabled,  List<String>? skillIds,  String? activeSkillId)  $default,) {final _that = this;
switch (_that) {
case _Assistant():
return $default(_that.id,_that.name,_that.description,_that.avatar,_that.emoji,_that.tags,_that.engine,_that.model,_that.temperature,_that.maxTokens,_that.topP,_that.frequencyPenalty,_that.presencePenalty,_that.systemPrompt,_that.prompt,_that.maxMessagesInContext,_that.isDefault,_that.isSystem,_that.archived,_that.createdAt,_that.updatedAt,_that.lastUsedAt,_that.topicIds,_that.selectedSystemPromptId,_that.mcpConfigId,_that.tools,_that.toolChoice,_that.speechModel,_that.speechVoice,_that.speechSpeed,_that.responseFormat,_that.isLocal,_that.localModelName,_that.localModelPath,_that.localModelType,_that.fileIds,_that.type,_that.regularPhrases,_that.webSearchProviderId,_that.enableWebSearch,_that.customParameters,_that.regexRules,_that.chatBackground,_that.memoryEnabled,_that.skillIds,_that.activeSkillId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  String? avatar,  String? emoji,  List<String>? tags,  String? engine,  String? model,  double? temperature,  int? maxTokens,  double? topP,  double? frequencyPenalty,  double? presencePenalty,  String? systemPrompt,  String? prompt,  int? maxMessagesInContext,  bool? isDefault,  bool? isSystem,  bool? archived, @IsoDateTimeConverter()  DateTime? createdAt, @IsoDateTimeConverter()  DateTime? updatedAt, @IsoDateTimeConverter()  DateTime? lastUsedAt,  List<String> topicIds,  String? selectedSystemPromptId,  String? mcpConfigId,  List<String>? tools, @JsonKey(name: 'tool_choice')  String? toolChoice,  String? speechModel,  String? speechVoice,  double? speechSpeed,  String? responseFormat,  bool? isLocal,  String? localModelName,  String? localModelPath,  String? localModelType, @JsonKey(name: 'file_ids')  List<String>? fileIds,  String? type,  List<QuickPhrase>? regularPhrases,  String? webSearchProviderId,  bool? enableWebSearch,  List<CustomParameter>? customParameters,  List<AssistantRegex>? regexRules,  AssistantChatBackground? chatBackground,  bool? memoryEnabled,  List<String>? skillIds,  String? activeSkillId)?  $default,) {final _that = this;
switch (_that) {
case _Assistant() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.avatar,_that.emoji,_that.tags,_that.engine,_that.model,_that.temperature,_that.maxTokens,_that.topP,_that.frequencyPenalty,_that.presencePenalty,_that.systemPrompt,_that.prompt,_that.maxMessagesInContext,_that.isDefault,_that.isSystem,_that.archived,_that.createdAt,_that.updatedAt,_that.lastUsedAt,_that.topicIds,_that.selectedSystemPromptId,_that.mcpConfigId,_that.tools,_that.toolChoice,_that.speechModel,_that.speechVoice,_that.speechSpeed,_that.responseFormat,_that.isLocal,_that.localModelName,_that.localModelPath,_that.localModelType,_that.fileIds,_that.type,_that.regularPhrases,_that.webSearchProviderId,_that.enableWebSearch,_that.customParameters,_that.regexRules,_that.chatBackground,_that.memoryEnabled,_that.skillIds,_that.activeSkillId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Assistant implements Assistant {
  const _Assistant({required this.id, required this.name, this.description, this.avatar, this.emoji, final  List<String>? tags, this.engine, this.model, this.temperature, this.maxTokens, this.topP, this.frequencyPenalty, this.presencePenalty, this.systemPrompt, this.prompt, this.maxMessagesInContext, this.isDefault, this.isSystem, this.archived, @IsoDateTimeConverter() this.createdAt, @IsoDateTimeConverter() this.updatedAt, @IsoDateTimeConverter() this.lastUsedAt, final  List<String> topicIds = const <String>[], this.selectedSystemPromptId, this.mcpConfigId, final  List<String>? tools, @JsonKey(name: 'tool_choice') this.toolChoice, this.speechModel, this.speechVoice, this.speechSpeed, this.responseFormat, this.isLocal, this.localModelName, this.localModelPath, this.localModelType, @JsonKey(name: 'file_ids') final  List<String>? fileIds, this.type, final  List<QuickPhrase>? regularPhrases, this.webSearchProviderId, this.enableWebSearch, final  List<CustomParameter>? customParameters, final  List<AssistantRegex>? regexRules, this.chatBackground, this.memoryEnabled, final  List<String>? skillIds, this.activeSkillId}): _tags = tags,_topicIds = topicIds,_tools = tools,_fileIds = fileIds,_regularPhrases = regularPhrases,_customParameters = customParameters,_regexRules = regexRules,_skillIds = skillIds;
  factory _Assistant.fromJson(Map<String, dynamic> json) => _$AssistantFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  String? avatar;
@override final  String? emoji;
 final  List<String>? _tags;
@override List<String>? get tags {
  final value = _tags;
  if (value == null) return null;
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? engine;
@override final  String? model;
@override final  double? temperature;
@override final  int? maxTokens;
@override final  double? topP;
@override final  double? frequencyPenalty;
@override final  double? presencePenalty;
@override final  String? systemPrompt;
@override final  String? prompt;
@override final  int? maxMessagesInContext;
@override final  bool? isDefault;
@override final  bool? isSystem;
@override final  bool? archived;
@override@IsoDateTimeConverter() final  DateTime? createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override@IsoDateTimeConverter() final  DateTime? lastUsedAt;
 final  List<String> _topicIds;
@override@JsonKey() List<String> get topicIds {
  if (_topicIds is EqualUnmodifiableListView) return _topicIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topicIds);
}

@override final  String? selectedSystemPromptId;
@override final  String? mcpConfigId;
 final  List<String>? _tools;
@override List<String>? get tools {
  final value = _tools;
  if (value == null) return null;
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'tool_choice') final  String? toolChoice;
@override final  String? speechModel;
@override final  String? speechVoice;
@override final  double? speechSpeed;
@override final  String? responseFormat;
@override final  bool? isLocal;
@override final  String? localModelName;
@override final  String? localModelPath;
@override final  String? localModelType;
 final  List<String>? _fileIds;
@override@JsonKey(name: 'file_ids') List<String>? get fileIds {
  final value = _fileIds;
  if (value == null) return null;
  if (_fileIds is EqualUnmodifiableListView) return _fileIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? type;
 final  List<QuickPhrase>? _regularPhrases;
@override List<QuickPhrase>? get regularPhrases {
  final value = _regularPhrases;
  if (value == null) return null;
  if (_regularPhrases is EqualUnmodifiableListView) return _regularPhrases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? webSearchProviderId;
@override final  bool? enableWebSearch;
 final  List<CustomParameter>? _customParameters;
@override List<CustomParameter>? get customParameters {
  final value = _customParameters;
  if (value == null) return null;
  if (_customParameters is EqualUnmodifiableListView) return _customParameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<AssistantRegex>? _regexRules;
@override List<AssistantRegex>? get regexRules {
  final value = _regexRules;
  if (value == null) return null;
  if (_regexRules is EqualUnmodifiableListView) return _regexRules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  AssistantChatBackground? chatBackground;
@override final  bool? memoryEnabled;
 final  List<String>? _skillIds;
@override List<String>? get skillIds {
  final value = _skillIds;
  if (value == null) return null;
  if (_skillIds is EqualUnmodifiableListView) return _skillIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? activeSkillId;

/// Create a copy of Assistant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantCopyWith<_Assistant> get copyWith => __$AssistantCopyWithImpl<_Assistant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Assistant&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.engine, engine) || other.engine == engine)&&(identical(other.model, model) || other.model == model)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.topP, topP) || other.topP == topP)&&(identical(other.frequencyPenalty, frequencyPenalty) || other.frequencyPenalty == frequencyPenalty)&&(identical(other.presencePenalty, presencePenalty) || other.presencePenalty == presencePenalty)&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.maxMessagesInContext, maxMessagesInContext) || other.maxMessagesInContext == maxMessagesInContext)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&const DeepCollectionEquality().equals(other._topicIds, _topicIds)&&(identical(other.selectedSystemPromptId, selectedSystemPromptId) || other.selectedSystemPromptId == selectedSystemPromptId)&&(identical(other.mcpConfigId, mcpConfigId) || other.mcpConfigId == mcpConfigId)&&const DeepCollectionEquality().equals(other._tools, _tools)&&(identical(other.toolChoice, toolChoice) || other.toolChoice == toolChoice)&&(identical(other.speechModel, speechModel) || other.speechModel == speechModel)&&(identical(other.speechVoice, speechVoice) || other.speechVoice == speechVoice)&&(identical(other.speechSpeed, speechSpeed) || other.speechSpeed == speechSpeed)&&(identical(other.responseFormat, responseFormat) || other.responseFormat == responseFormat)&&(identical(other.isLocal, isLocal) || other.isLocal == isLocal)&&(identical(other.localModelName, localModelName) || other.localModelName == localModelName)&&(identical(other.localModelPath, localModelPath) || other.localModelPath == localModelPath)&&(identical(other.localModelType, localModelType) || other.localModelType == localModelType)&&const DeepCollectionEquality().equals(other._fileIds, _fileIds)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._regularPhrases, _regularPhrases)&&(identical(other.webSearchProviderId, webSearchProviderId) || other.webSearchProviderId == webSearchProviderId)&&(identical(other.enableWebSearch, enableWebSearch) || other.enableWebSearch == enableWebSearch)&&const DeepCollectionEquality().equals(other._customParameters, _customParameters)&&const DeepCollectionEquality().equals(other._regexRules, _regexRules)&&(identical(other.chatBackground, chatBackground) || other.chatBackground == chatBackground)&&(identical(other.memoryEnabled, memoryEnabled) || other.memoryEnabled == memoryEnabled)&&const DeepCollectionEquality().equals(other._skillIds, _skillIds)&&(identical(other.activeSkillId, activeSkillId) || other.activeSkillId == activeSkillId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,description,avatar,emoji,const DeepCollectionEquality().hash(_tags),engine,model,temperature,maxTokens,topP,frequencyPenalty,presencePenalty,systemPrompt,prompt,maxMessagesInContext,isDefault,isSystem,archived,createdAt,updatedAt,lastUsedAt,const DeepCollectionEquality().hash(_topicIds),selectedSystemPromptId,mcpConfigId,const DeepCollectionEquality().hash(_tools),toolChoice,speechModel,speechVoice,speechSpeed,responseFormat,isLocal,localModelName,localModelPath,localModelType,const DeepCollectionEquality().hash(_fileIds),type,const DeepCollectionEquality().hash(_regularPhrases),webSearchProviderId,enableWebSearch,const DeepCollectionEquality().hash(_customParameters),const DeepCollectionEquality().hash(_regexRules),chatBackground,memoryEnabled,const DeepCollectionEquality().hash(_skillIds),activeSkillId]);

@override
String toString() {
  return 'Assistant(id: $id, name: $name, description: $description, avatar: $avatar, emoji: $emoji, tags: $tags, engine: $engine, model: $model, temperature: $temperature, maxTokens: $maxTokens, topP: $topP, frequencyPenalty: $frequencyPenalty, presencePenalty: $presencePenalty, systemPrompt: $systemPrompt, prompt: $prompt, maxMessagesInContext: $maxMessagesInContext, isDefault: $isDefault, isSystem: $isSystem, archived: $archived, createdAt: $createdAt, updatedAt: $updatedAt, lastUsedAt: $lastUsedAt, topicIds: $topicIds, selectedSystemPromptId: $selectedSystemPromptId, mcpConfigId: $mcpConfigId, tools: $tools, toolChoice: $toolChoice, speechModel: $speechModel, speechVoice: $speechVoice, speechSpeed: $speechSpeed, responseFormat: $responseFormat, isLocal: $isLocal, localModelName: $localModelName, localModelPath: $localModelPath, localModelType: $localModelType, fileIds: $fileIds, type: $type, regularPhrases: $regularPhrases, webSearchProviderId: $webSearchProviderId, enableWebSearch: $enableWebSearch, customParameters: $customParameters, regexRules: $regexRules, chatBackground: $chatBackground, memoryEnabled: $memoryEnabled, skillIds: $skillIds, activeSkillId: $activeSkillId)';
}


}

/// @nodoc
abstract mixin class _$AssistantCopyWith<$Res> implements $AssistantCopyWith<$Res> {
  factory _$AssistantCopyWith(_Assistant value, $Res Function(_Assistant) _then) = __$AssistantCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, String? avatar, String? emoji, List<String>? tags, String? engine, String? model, double? temperature, int? maxTokens, double? topP, double? frequencyPenalty, double? presencePenalty, String? systemPrompt, String? prompt, int? maxMessagesInContext, bool? isDefault, bool? isSystem, bool? archived,@IsoDateTimeConverter() DateTime? createdAt,@IsoDateTimeConverter() DateTime? updatedAt,@IsoDateTimeConverter() DateTime? lastUsedAt, List<String> topicIds, String? selectedSystemPromptId, String? mcpConfigId, List<String>? tools,@JsonKey(name: 'tool_choice') String? toolChoice, String? speechModel, String? speechVoice, double? speechSpeed, String? responseFormat, bool? isLocal, String? localModelName, String? localModelPath, String? localModelType,@JsonKey(name: 'file_ids') List<String>? fileIds, String? type, List<QuickPhrase>? regularPhrases, String? webSearchProviderId, bool? enableWebSearch, List<CustomParameter>? customParameters, List<AssistantRegex>? regexRules, AssistantChatBackground? chatBackground, bool? memoryEnabled, List<String>? skillIds, String? activeSkillId
});


@override $AssistantChatBackgroundCopyWith<$Res>? get chatBackground;

}
/// @nodoc
class __$AssistantCopyWithImpl<$Res>
    implements _$AssistantCopyWith<$Res> {
  __$AssistantCopyWithImpl(this._self, this._then);

  final _Assistant _self;
  final $Res Function(_Assistant) _then;

/// Create a copy of Assistant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? avatar = freezed,Object? emoji = freezed,Object? tags = freezed,Object? engine = freezed,Object? model = freezed,Object? temperature = freezed,Object? maxTokens = freezed,Object? topP = freezed,Object? frequencyPenalty = freezed,Object? presencePenalty = freezed,Object? systemPrompt = freezed,Object? prompt = freezed,Object? maxMessagesInContext = freezed,Object? isDefault = freezed,Object? isSystem = freezed,Object? archived = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lastUsedAt = freezed,Object? topicIds = null,Object? selectedSystemPromptId = freezed,Object? mcpConfigId = freezed,Object? tools = freezed,Object? toolChoice = freezed,Object? speechModel = freezed,Object? speechVoice = freezed,Object? speechSpeed = freezed,Object? responseFormat = freezed,Object? isLocal = freezed,Object? localModelName = freezed,Object? localModelPath = freezed,Object? localModelType = freezed,Object? fileIds = freezed,Object? type = freezed,Object? regularPhrases = freezed,Object? webSearchProviderId = freezed,Object? enableWebSearch = freezed,Object? customParameters = freezed,Object? regexRules = freezed,Object? chatBackground = freezed,Object? memoryEnabled = freezed,Object? skillIds = freezed,Object? activeSkillId = freezed,}) {
  return _then(_Assistant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,tags: freezed == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>?,engine: freezed == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,topP: freezed == topP ? _self.topP : topP // ignore: cast_nullable_to_non_nullable
as double?,frequencyPenalty: freezed == frequencyPenalty ? _self.frequencyPenalty : frequencyPenalty // ignore: cast_nullable_to_non_nullable
as double?,presencePenalty: freezed == presencePenalty ? _self.presencePenalty : presencePenalty // ignore: cast_nullable_to_non_nullable
as double?,systemPrompt: freezed == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String?,prompt: freezed == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String?,maxMessagesInContext: freezed == maxMessagesInContext ? _self.maxMessagesInContext : maxMessagesInContext // ignore: cast_nullable_to_non_nullable
as int?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,isSystem: freezed == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool?,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,topicIds: null == topicIds ? _self._topicIds : topicIds // ignore: cast_nullable_to_non_nullable
as List<String>,selectedSystemPromptId: freezed == selectedSystemPromptId ? _self.selectedSystemPromptId : selectedSystemPromptId // ignore: cast_nullable_to_non_nullable
as String?,mcpConfigId: freezed == mcpConfigId ? _self.mcpConfigId : mcpConfigId // ignore: cast_nullable_to_non_nullable
as String?,tools: freezed == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<String>?,toolChoice: freezed == toolChoice ? _self.toolChoice : toolChoice // ignore: cast_nullable_to_non_nullable
as String?,speechModel: freezed == speechModel ? _self.speechModel : speechModel // ignore: cast_nullable_to_non_nullable
as String?,speechVoice: freezed == speechVoice ? _self.speechVoice : speechVoice // ignore: cast_nullable_to_non_nullable
as String?,speechSpeed: freezed == speechSpeed ? _self.speechSpeed : speechSpeed // ignore: cast_nullable_to_non_nullable
as double?,responseFormat: freezed == responseFormat ? _self.responseFormat : responseFormat // ignore: cast_nullable_to_non_nullable
as String?,isLocal: freezed == isLocal ? _self.isLocal : isLocal // ignore: cast_nullable_to_non_nullable
as bool?,localModelName: freezed == localModelName ? _self.localModelName : localModelName // ignore: cast_nullable_to_non_nullable
as String?,localModelPath: freezed == localModelPath ? _self.localModelPath : localModelPath // ignore: cast_nullable_to_non_nullable
as String?,localModelType: freezed == localModelType ? _self.localModelType : localModelType // ignore: cast_nullable_to_non_nullable
as String?,fileIds: freezed == fileIds ? _self._fileIds : fileIds // ignore: cast_nullable_to_non_nullable
as List<String>?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,regularPhrases: freezed == regularPhrases ? _self._regularPhrases : regularPhrases // ignore: cast_nullable_to_non_nullable
as List<QuickPhrase>?,webSearchProviderId: freezed == webSearchProviderId ? _self.webSearchProviderId : webSearchProviderId // ignore: cast_nullable_to_non_nullable
as String?,enableWebSearch: freezed == enableWebSearch ? _self.enableWebSearch : enableWebSearch // ignore: cast_nullable_to_non_nullable
as bool?,customParameters: freezed == customParameters ? _self._customParameters : customParameters // ignore: cast_nullable_to_non_nullable
as List<CustomParameter>?,regexRules: freezed == regexRules ? _self._regexRules : regexRules // ignore: cast_nullable_to_non_nullable
as List<AssistantRegex>?,chatBackground: freezed == chatBackground ? _self.chatBackground : chatBackground // ignore: cast_nullable_to_non_nullable
as AssistantChatBackground?,memoryEnabled: freezed == memoryEnabled ? _self.memoryEnabled : memoryEnabled // ignore: cast_nullable_to_non_nullable
as bool?,skillIds: freezed == skillIds ? _self._skillIds : skillIds // ignore: cast_nullable_to_non_nullable
as List<String>?,activeSkillId: freezed == activeSkillId ? _self.activeSkillId : activeSkillId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Assistant
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssistantChatBackgroundCopyWith<$Res>? get chatBackground {
    if (_self.chatBackground == null) {
    return null;
  }

  return $AssistantChatBackgroundCopyWith<$Res>(_self.chatBackground!, (value) {
    return _then(_self.copyWith(chatBackground: value));
  });
}
}

// dart format on
