// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_block.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
MessageBlock _$MessageBlockFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'main_text':
          return MainTextBlock.fromJson(
            json
          );
                case 'thinking':
          return ThinkingBlock.fromJson(
            json
          );
                case 'image':
          return ImageBlock.fromJson(
            json
          );
                case 'video':
          return VideoBlock.fromJson(
            json
          );
                case 'code':
          return CodeBlock.fromJson(
            json
          );
                case 'tool':
          return ToolBlock.fromJson(
            json
          );
                case 'file':
          return FileBlock.fromJson(
            json
          );
                case 'error':
          return ErrorBlock.fromJson(
            json
          );
                case 'citation':
          return CitationBlock.fromJson(
            json
          );
                case 'translation':
          return TranslationBlock.fromJson(
            json
          );
                case 'chart':
          return ChartBlock.fromJson(
            json
          );
                case 'math':
          return MathBlock.fromJson(
            json
          );
                case 'knowledge_reference':
          return KnowledgeReferenceBlock.fromJson(
            json
          );
                case 'context_summary':
          return ContextSummaryBlock.fromJson(
            json
          );
        
          default:
            return UnknownBlock.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$MessageBlock {

 String get id; String get messageId; MessageBlockStatus get status;@IsoDateTimeConverter() DateTime get createdAt;@IsoDateTimeConverter() DateTime? get updatedAt; Model? get model; Object? get metadata; Map<String, dynamic>? get error;
/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageBlockCopyWith<MessageBlock> get copyWith => _$MessageBlockCopyWithImpl<MessageBlock>(this as MessageBlock, _$identity);

  /// Serializes this MessageBlock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&const DeepCollectionEquality().equals(other.error, error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(metadata),const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'MessageBlock(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error)';
}


}

/// @nodoc
abstract mixin class $MessageBlockCopyWith<$Res>  {
  factory $MessageBlockCopyWith(MessageBlock value, $Res Function(MessageBlock) _then) = _$MessageBlockCopyWithImpl;
@useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? error
});


$ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$MessageBlockCopyWithImpl<$Res>
    implements $MessageBlockCopyWith<$Res> {
  _$MessageBlockCopyWithImpl(this._self, this._then);

  final MessageBlock _self;
  final $Res Function(MessageBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of MessageBlock
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


/// Adds pattern-matching-related methods to [MessageBlock].
extension MessageBlockPatterns on MessageBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UnknownBlock value)?  unknown,TResult Function( MainTextBlock value)?  mainText,TResult Function( ThinkingBlock value)?  thinking,TResult Function( ImageBlock value)?  image,TResult Function( VideoBlock value)?  video,TResult Function( CodeBlock value)?  code,TResult Function( ToolBlock value)?  tool,TResult Function( FileBlock value)?  file,TResult Function( ErrorBlock value)?  error,TResult Function( CitationBlock value)?  citation,TResult Function( TranslationBlock value)?  translation,TResult Function( ChartBlock value)?  chart,TResult Function( MathBlock value)?  math,TResult Function( KnowledgeReferenceBlock value)?  knowledgeReference,TResult Function( ContextSummaryBlock value)?  contextSummary,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UnknownBlock() when unknown != null:
return unknown(_that);case MainTextBlock() when mainText != null:
return mainText(_that);case ThinkingBlock() when thinking != null:
return thinking(_that);case ImageBlock() when image != null:
return image(_that);case VideoBlock() when video != null:
return video(_that);case CodeBlock() when code != null:
return code(_that);case ToolBlock() when tool != null:
return tool(_that);case FileBlock() when file != null:
return file(_that);case ErrorBlock() when error != null:
return error(_that);case CitationBlock() when citation != null:
return citation(_that);case TranslationBlock() when translation != null:
return translation(_that);case ChartBlock() when chart != null:
return chart(_that);case MathBlock() when math != null:
return math(_that);case KnowledgeReferenceBlock() when knowledgeReference != null:
return knowledgeReference(_that);case ContextSummaryBlock() when contextSummary != null:
return contextSummary(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UnknownBlock value)  unknown,required TResult Function( MainTextBlock value)  mainText,required TResult Function( ThinkingBlock value)  thinking,required TResult Function( ImageBlock value)  image,required TResult Function( VideoBlock value)  video,required TResult Function( CodeBlock value)  code,required TResult Function( ToolBlock value)  tool,required TResult Function( FileBlock value)  file,required TResult Function( ErrorBlock value)  error,required TResult Function( CitationBlock value)  citation,required TResult Function( TranslationBlock value)  translation,required TResult Function( ChartBlock value)  chart,required TResult Function( MathBlock value)  math,required TResult Function( KnowledgeReferenceBlock value)  knowledgeReference,required TResult Function( ContextSummaryBlock value)  contextSummary,}){
final _that = this;
switch (_that) {
case UnknownBlock():
return unknown(_that);case MainTextBlock():
return mainText(_that);case ThinkingBlock():
return thinking(_that);case ImageBlock():
return image(_that);case VideoBlock():
return video(_that);case CodeBlock():
return code(_that);case ToolBlock():
return tool(_that);case FileBlock():
return file(_that);case ErrorBlock():
return error(_that);case CitationBlock():
return citation(_that);case TranslationBlock():
return translation(_that);case ChartBlock():
return chart(_that);case MathBlock():
return math(_that);case KnowledgeReferenceBlock():
return knowledgeReference(_that);case ContextSummaryBlock():
return contextSummary(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UnknownBlock value)?  unknown,TResult? Function( MainTextBlock value)?  mainText,TResult? Function( ThinkingBlock value)?  thinking,TResult? Function( ImageBlock value)?  image,TResult? Function( VideoBlock value)?  video,TResult? Function( CodeBlock value)?  code,TResult? Function( ToolBlock value)?  tool,TResult? Function( FileBlock value)?  file,TResult? Function( ErrorBlock value)?  error,TResult? Function( CitationBlock value)?  citation,TResult? Function( TranslationBlock value)?  translation,TResult? Function( ChartBlock value)?  chart,TResult? Function( MathBlock value)?  math,TResult? Function( KnowledgeReferenceBlock value)?  knowledgeReference,TResult? Function( ContextSummaryBlock value)?  contextSummary,}){
final _that = this;
switch (_that) {
case UnknownBlock() when unknown != null:
return unknown(_that);case MainTextBlock() when mainText != null:
return mainText(_that);case ThinkingBlock() when thinking != null:
return thinking(_that);case ImageBlock() when image != null:
return image(_that);case VideoBlock() when video != null:
return video(_that);case CodeBlock() when code != null:
return code(_that);case ToolBlock() when tool != null:
return tool(_that);case FileBlock() when file != null:
return file(_that);case ErrorBlock() when error != null:
return error(_that);case CitationBlock() when citation != null:
return citation(_that);case TranslationBlock() when translation != null:
return translation(_that);case ChartBlock() when chart != null:
return chart(_that);case MathBlock() when math != null:
return math(_that);case KnowledgeReferenceBlock() when knowledgeReference != null:
return knowledgeReference(_that);case ContextSummaryBlock() when contextSummary != null:
return contextSummary(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String? content)?  unknown,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content)?  mainText,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content, @JsonKey(name: 'thinking_millsec')  int? thinkingMillsec,  int? thinkingStartTime)?  thinking,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String url,  String mimeType,  String? base64Data,  int? width,  int? height,  int? size,  MessageFileReference? file)?  image,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String url,  String mimeType,  String? base64Data,  int? width,  int? height,  int? size,  int? duration,  String? poster,  MessageFileReference? file)?  video,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? language)?  code,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String toolId,  String? toolName,  Map<String, dynamic>? arguments,  Object? content)?  tool,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String name,  String url,  String mimeType,  int? size,  MessageFileReference? file)?  file,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? message,  String? details,  String? code)?  error,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? source,  String? url,  List<CitationSource>? sources,  Object? response,  List<KnowledgeReferenceItem>? knowledge,  List<WebSearchReferenceItem>? webSearch,  CitationMetadata? citationMetadata)?  citation,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String sourceContent,  String sourceLanguage,  String targetLanguage,  String? sourceBlockId)?  translation,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  ChartType chartType,  Object? data,  Map<String, dynamic>? options)?  chart,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  bool displayMode)?  math,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  KnowledgeReferenceMetadata? metadata,  Map<String, dynamic>? error,  String content,  String knowledgeBaseId,  String? source,  double? similarity)?  knowledgeReference,TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  int originalMessageCount,  int originalTokens,  int compressedTokens,  int tokensSaved,  double? cost, @IsoDateTimeConverter()  DateTime compressedAt,  String? modelId)?  contextSummary,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UnknownBlock() when unknown != null:
return unknown(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content);case MainTextBlock() when mainText != null:
return mainText(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content);case ThinkingBlock() when thinking != null:
return thinking(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.thinkingMillsec,_that.thinkingStartTime);case ImageBlock() when image != null:
return image(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.url,_that.mimeType,_that.base64Data,_that.width,_that.height,_that.size,_that.file);case VideoBlock() when video != null:
return video(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.url,_that.mimeType,_that.base64Data,_that.width,_that.height,_that.size,_that.duration,_that.poster,_that.file);case CodeBlock() when code != null:
return code(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.language);case ToolBlock() when tool != null:
return tool(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.toolId,_that.toolName,_that.arguments,_that.content);case FileBlock() when file != null:
return file(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.name,_that.url,_that.mimeType,_that.size,_that.file);case ErrorBlock() when error != null:
return error(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.message,_that.details,_that.code);case CitationBlock() when citation != null:
return citation(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.source,_that.url,_that.sources,_that.response,_that.knowledge,_that.webSearch,_that.citationMetadata);case TranslationBlock() when translation != null:
return translation(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.sourceContent,_that.sourceLanguage,_that.targetLanguage,_that.sourceBlockId);case ChartBlock() when chart != null:
return chart(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.chartType,_that.data,_that.options);case MathBlock() when math != null:
return math(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.displayMode);case KnowledgeReferenceBlock() when knowledgeReference != null:
return knowledgeReference(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.knowledgeBaseId,_that.source,_that.similarity);case ContextSummaryBlock() when contextSummary != null:
return contextSummary(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.originalMessageCount,_that.originalTokens,_that.compressedTokens,_that.tokensSaved,_that.cost,_that.compressedAt,_that.modelId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String? content)  unknown,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content)  mainText,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content, @JsonKey(name: 'thinking_millsec')  int? thinkingMillsec,  int? thinkingStartTime)  thinking,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String url,  String mimeType,  String? base64Data,  int? width,  int? height,  int? size,  MessageFileReference? file)  image,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String url,  String mimeType,  String? base64Data,  int? width,  int? height,  int? size,  int? duration,  String? poster,  MessageFileReference? file)  video,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? language)  code,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String toolId,  String? toolName,  Map<String, dynamic>? arguments,  Object? content)  tool,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String name,  String url,  String mimeType,  int? size,  MessageFileReference? file)  file,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? message,  String? details,  String? code)  error,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? source,  String? url,  List<CitationSource>? sources,  Object? response,  List<KnowledgeReferenceItem>? knowledge,  List<WebSearchReferenceItem>? webSearch,  CitationMetadata? citationMetadata)  citation,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String sourceContent,  String sourceLanguage,  String targetLanguage,  String? sourceBlockId)  translation,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  ChartType chartType,  Object? data,  Map<String, dynamic>? options)  chart,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  bool displayMode)  math,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  KnowledgeReferenceMetadata? metadata,  Map<String, dynamic>? error,  String content,  String knowledgeBaseId,  String? source,  double? similarity)  knowledgeReference,required TResult Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  int originalMessageCount,  int originalTokens,  int compressedTokens,  int tokensSaved,  double? cost, @IsoDateTimeConverter()  DateTime compressedAt,  String? modelId)  contextSummary,}) {final _that = this;
switch (_that) {
case UnknownBlock():
return unknown(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content);case MainTextBlock():
return mainText(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content);case ThinkingBlock():
return thinking(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.thinkingMillsec,_that.thinkingStartTime);case ImageBlock():
return image(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.url,_that.mimeType,_that.base64Data,_that.width,_that.height,_that.size,_that.file);case VideoBlock():
return video(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.url,_that.mimeType,_that.base64Data,_that.width,_that.height,_that.size,_that.duration,_that.poster,_that.file);case CodeBlock():
return code(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.language);case ToolBlock():
return tool(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.toolId,_that.toolName,_that.arguments,_that.content);case FileBlock():
return file(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.name,_that.url,_that.mimeType,_that.size,_that.file);case ErrorBlock():
return error(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.message,_that.details,_that.code);case CitationBlock():
return citation(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.source,_that.url,_that.sources,_that.response,_that.knowledge,_that.webSearch,_that.citationMetadata);case TranslationBlock():
return translation(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.sourceContent,_that.sourceLanguage,_that.targetLanguage,_that.sourceBlockId);case ChartBlock():
return chart(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.chartType,_that.data,_that.options);case MathBlock():
return math(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.displayMode);case KnowledgeReferenceBlock():
return knowledgeReference(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.knowledgeBaseId,_that.source,_that.similarity);case ContextSummaryBlock():
return contextSummary(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.originalMessageCount,_that.originalTokens,_that.compressedTokens,_that.tokensSaved,_that.cost,_that.compressedAt,_that.modelId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String? content)?  unknown,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content)?  mainText,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content, @JsonKey(name: 'thinking_millsec')  int? thinkingMillsec,  int? thinkingStartTime)?  thinking,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String url,  String mimeType,  String? base64Data,  int? width,  int? height,  int? size,  MessageFileReference? file)?  image,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String url,  String mimeType,  String? base64Data,  int? width,  int? height,  int? size,  int? duration,  String? poster,  MessageFileReference? file)?  video,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? language)?  code,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String toolId,  String? toolName,  Map<String, dynamic>? arguments,  Object? content)?  tool,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String name,  String url,  String mimeType,  int? size,  MessageFileReference? file)?  file,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? message,  String? details,  String? code)?  error,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String? source,  String? url,  List<CitationSource>? sources,  Object? response,  List<KnowledgeReferenceItem>? knowledge,  List<WebSearchReferenceItem>? webSearch,  CitationMetadata? citationMetadata)?  citation,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  String sourceContent,  String sourceLanguage,  String targetLanguage,  String? sourceBlockId)?  translation,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  ChartType chartType,  Object? data,  Map<String, dynamic>? options)?  chart,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  bool displayMode)?  math,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  KnowledgeReferenceMetadata? metadata,  Map<String, dynamic>? error,  String content,  String knowledgeBaseId,  String? source,  double? similarity)?  knowledgeReference,TResult? Function( String id,  String messageId,  MessageBlockStatus status, @IsoDateTimeConverter()  DateTime createdAt, @IsoDateTimeConverter()  DateTime? updatedAt,  Model? model,  Map<String, dynamic>? metadata,  Map<String, dynamic>? error,  String content,  int originalMessageCount,  int originalTokens,  int compressedTokens,  int tokensSaved,  double? cost, @IsoDateTimeConverter()  DateTime compressedAt,  String? modelId)?  contextSummary,}) {final _that = this;
switch (_that) {
case UnknownBlock() when unknown != null:
return unknown(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content);case MainTextBlock() when mainText != null:
return mainText(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content);case ThinkingBlock() when thinking != null:
return thinking(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.thinkingMillsec,_that.thinkingStartTime);case ImageBlock() when image != null:
return image(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.url,_that.mimeType,_that.base64Data,_that.width,_that.height,_that.size,_that.file);case VideoBlock() when video != null:
return video(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.url,_that.mimeType,_that.base64Data,_that.width,_that.height,_that.size,_that.duration,_that.poster,_that.file);case CodeBlock() when code != null:
return code(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.language);case ToolBlock() when tool != null:
return tool(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.toolId,_that.toolName,_that.arguments,_that.content);case FileBlock() when file != null:
return file(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.name,_that.url,_that.mimeType,_that.size,_that.file);case ErrorBlock() when error != null:
return error(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.message,_that.details,_that.code);case CitationBlock() when citation != null:
return citation(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.source,_that.url,_that.sources,_that.response,_that.knowledge,_that.webSearch,_that.citationMetadata);case TranslationBlock() when translation != null:
return translation(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.sourceContent,_that.sourceLanguage,_that.targetLanguage,_that.sourceBlockId);case ChartBlock() when chart != null:
return chart(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.chartType,_that.data,_that.options);case MathBlock() when math != null:
return math(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.displayMode);case KnowledgeReferenceBlock() when knowledgeReference != null:
return knowledgeReference(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.knowledgeBaseId,_that.source,_that.similarity);case ContextSummaryBlock() when contextSummary != null:
return contextSummary(_that.id,_that.messageId,_that.status,_that.createdAt,_that.updatedAt,_that.model,_that.metadata,_that.error,_that.content,_that.originalMessageCount,_that.originalTokens,_that.compressedTokens,_that.tokensSaved,_that.cost,_that.compressedAt,_that.modelId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class UnknownBlock implements MessageBlock {
  const UnknownBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, this.content, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'unknown';
  factory UnknownBlock.fromJson(Map<String, dynamic> json) => _$UnknownBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String? content;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnknownBlockCopyWith<UnknownBlock> get copyWith => _$UnknownBlockCopyWithImpl<UnknownBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnknownBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content);

@override
String toString() {
  return 'MessageBlock.unknown(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content)';
}


}

/// @nodoc
abstract mixin class $UnknownBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $UnknownBlockCopyWith(UnknownBlock value, $Res Function(UnknownBlock) _then) = _$UnknownBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String? content
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$UnknownBlockCopyWithImpl<$Res>
    implements $UnknownBlockCopyWith<$Res> {
  _$UnknownBlockCopyWithImpl(this._self, this._then);

  final UnknownBlock _self;
  final $Res Function(UnknownBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = freezed,}) {
  return _then(UnknownBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class MainTextBlock implements MessageBlock {
  const MainTextBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'main_text';
  factory MainTextBlock.fromJson(Map<String, dynamic> json) => _$MainTextBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MainTextBlockCopyWith<MainTextBlock> get copyWith => _$MainTextBlockCopyWithImpl<MainTextBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MainTextBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MainTextBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content);

@override
String toString() {
  return 'MessageBlock.mainText(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content)';
}


}

/// @nodoc
abstract mixin class $MainTextBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $MainTextBlockCopyWith(MainTextBlock value, $Res Function(MainTextBlock) _then) = _$MainTextBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$MainTextBlockCopyWithImpl<$Res>
    implements $MainTextBlockCopyWith<$Res> {
  _$MainTextBlockCopyWithImpl(this._self, this._then);

  final MainTextBlock _self;
  final $Res Function(MainTextBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,}) {
  return _then(MainTextBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class ThinkingBlock implements MessageBlock {
  const ThinkingBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, @JsonKey(name: 'thinking_millsec') this.thinkingMillsec, this.thinkingStartTime, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'thinking';
  factory ThinkingBlock.fromJson(Map<String, dynamic> json) => _$ThinkingBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
@JsonKey(name: 'thinking_millsec') final  int? thinkingMillsec;
 final  int? thinkingStartTime;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThinkingBlockCopyWith<ThinkingBlock> get copyWith => _$ThinkingBlockCopyWithImpl<ThinkingBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThinkingBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThinkingBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.thinkingMillsec, thinkingMillsec) || other.thinkingMillsec == thinkingMillsec)&&(identical(other.thinkingStartTime, thinkingStartTime) || other.thinkingStartTime == thinkingStartTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,thinkingMillsec,thinkingStartTime);

@override
String toString() {
  return 'MessageBlock.thinking(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, thinkingMillsec: $thinkingMillsec, thinkingStartTime: $thinkingStartTime)';
}


}

/// @nodoc
abstract mixin class $ThinkingBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $ThinkingBlockCopyWith(ThinkingBlock value, $Res Function(ThinkingBlock) _then) = _$ThinkingBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content,@JsonKey(name: 'thinking_millsec') int? thinkingMillsec, int? thinkingStartTime
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$ThinkingBlockCopyWithImpl<$Res>
    implements $ThinkingBlockCopyWith<$Res> {
  _$ThinkingBlockCopyWithImpl(this._self, this._then);

  final ThinkingBlock _self;
  final $Res Function(ThinkingBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? thinkingMillsec = freezed,Object? thinkingStartTime = freezed,}) {
  return _then(ThinkingBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,thinkingMillsec: freezed == thinkingMillsec ? _self.thinkingMillsec : thinkingMillsec // ignore: cast_nullable_to_non_nullable
as int?,thinkingStartTime: freezed == thinkingStartTime ? _self.thinkingStartTime : thinkingStartTime // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class ImageBlock implements MessageBlock {
  const ImageBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.url, required this.mimeType, this.base64Data, this.width, this.height, this.size, this.file, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'image';
  factory ImageBlock.fromJson(Map<String, dynamic> json) => _$ImageBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String url;
 final  String mimeType;
 final  String? base64Data;
 final  int? width;
 final  int? height;
 final  int? size;
 final  MessageFileReference? file;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageBlockCopyWith<ImageBlock> get copyWith => _$ImageBlockCopyWithImpl<ImageBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImageBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.url, url) || other.url == url)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.base64Data, base64Data) || other.base64Data == base64Data)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.size, size) || other.size == size)&&(identical(other.file, file) || other.file == file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),url,mimeType,base64Data,width,height,size,file);

@override
String toString() {
  return 'MessageBlock.image(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, url: $url, mimeType: $mimeType, base64Data: $base64Data, width: $width, height: $height, size: $size, file: $file)';
}


}

/// @nodoc
abstract mixin class $ImageBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $ImageBlockCopyWith(ImageBlock value, $Res Function(ImageBlock) _then) = _$ImageBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String url, String mimeType, String? base64Data, int? width, int? height, int? size, MessageFileReference? file
});


@override $ModelCopyWith<$Res>? get model;$MessageFileReferenceCopyWith<$Res>? get file;

}
/// @nodoc
class _$ImageBlockCopyWithImpl<$Res>
    implements $ImageBlockCopyWith<$Res> {
  _$ImageBlockCopyWithImpl(this._self, this._then);

  final ImageBlock _self;
  final $Res Function(ImageBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? url = null,Object? mimeType = null,Object? base64Data = freezed,Object? width = freezed,Object? height = freezed,Object? size = freezed,Object? file = freezed,}) {
  return _then(ImageBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,base64Data: freezed == base64Data ? _self.base64Data : base64Data // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as MessageFileReference?,
  ));
}

/// Create a copy of MessageBlock
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
}/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageFileReferenceCopyWith<$Res>? get file {
    if (_self.file == null) {
    return null;
  }

  return $MessageFileReferenceCopyWith<$Res>(_self.file!, (value) {
    return _then(_self.copyWith(file: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class VideoBlock implements MessageBlock {
  const VideoBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.url, required this.mimeType, this.base64Data, this.width, this.height, this.size, this.duration, this.poster, this.file, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'video';
  factory VideoBlock.fromJson(Map<String, dynamic> json) => _$VideoBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String url;
 final  String mimeType;
 final  String? base64Data;
 final  int? width;
 final  int? height;
 final  int? size;
 final  int? duration;
 final  String? poster;
 final  MessageFileReference? file;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoBlockCopyWith<VideoBlock> get copyWith => _$VideoBlockCopyWithImpl<VideoBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.url, url) || other.url == url)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.base64Data, base64Data) || other.base64Data == base64Data)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.size, size) || other.size == size)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.poster, poster) || other.poster == poster)&&(identical(other.file, file) || other.file == file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),url,mimeType,base64Data,width,height,size,duration,poster,file);

@override
String toString() {
  return 'MessageBlock.video(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, url: $url, mimeType: $mimeType, base64Data: $base64Data, width: $width, height: $height, size: $size, duration: $duration, poster: $poster, file: $file)';
}


}

/// @nodoc
abstract mixin class $VideoBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $VideoBlockCopyWith(VideoBlock value, $Res Function(VideoBlock) _then) = _$VideoBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String url, String mimeType, String? base64Data, int? width, int? height, int? size, int? duration, String? poster, MessageFileReference? file
});


@override $ModelCopyWith<$Res>? get model;$MessageFileReferenceCopyWith<$Res>? get file;

}
/// @nodoc
class _$VideoBlockCopyWithImpl<$Res>
    implements $VideoBlockCopyWith<$Res> {
  _$VideoBlockCopyWithImpl(this._self, this._then);

  final VideoBlock _self;
  final $Res Function(VideoBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? url = null,Object? mimeType = null,Object? base64Data = freezed,Object? width = freezed,Object? height = freezed,Object? size = freezed,Object? duration = freezed,Object? poster = freezed,Object? file = freezed,}) {
  return _then(VideoBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,base64Data: freezed == base64Data ? _self.base64Data : base64Data // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,poster: freezed == poster ? _self.poster : poster // ignore: cast_nullable_to_non_nullable
as String?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as MessageFileReference?,
  ));
}

/// Create a copy of MessageBlock
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
}/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageFileReferenceCopyWith<$Res>? get file {
    if (_self.file == null) {
    return null;
  }

  return $MessageFileReferenceCopyWith<$Res>(_self.file!, (value) {
    return _then(_self.copyWith(file: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class CodeBlock implements MessageBlock {
  const CodeBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, this.language, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'code';
  factory CodeBlock.fromJson(Map<String, dynamic> json) => _$CodeBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  String? language;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodeBlockCopyWith<CodeBlock> get copyWith => _$CodeBlockCopyWithImpl<CodeBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodeBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodeBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.language, language) || other.language == language));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,language);

@override
String toString() {
  return 'MessageBlock.code(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, language: $language)';
}


}

/// @nodoc
abstract mixin class $CodeBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $CodeBlockCopyWith(CodeBlock value, $Res Function(CodeBlock) _then) = _$CodeBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content, String? language
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$CodeBlockCopyWithImpl<$Res>
    implements $CodeBlockCopyWith<$Res> {
  _$CodeBlockCopyWithImpl(this._self, this._then);

  final CodeBlock _self;
  final $Res Function(CodeBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? language = freezed,}) {
  return _then(CodeBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class ToolBlock implements MessageBlock {
  const ToolBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.toolId, this.toolName, final  Map<String, dynamic>? arguments, this.content, final  String? $type}): _metadata = metadata,_error = error,_arguments = arguments,$type = $type ?? 'tool';
  factory ToolBlock.fromJson(Map<String, dynamic> json) => _$ToolBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String toolId;
 final  String? toolName;
 final  Map<String, dynamic>? _arguments;
 Map<String, dynamic>? get arguments {
  final value = _arguments;
  if (value == null) return null;
  if (_arguments is EqualUnmodifiableMapView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Object? content;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolBlockCopyWith<ToolBlock> get copyWith => _$ToolBlockCopyWithImpl<ToolBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.toolId, toolId) || other.toolId == toolId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other._arguments, _arguments)&&const DeepCollectionEquality().equals(other.content, content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),toolId,toolName,const DeepCollectionEquality().hash(_arguments),const DeepCollectionEquality().hash(content));

@override
String toString() {
  return 'MessageBlock.tool(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, toolId: $toolId, toolName: $toolName, arguments: $arguments, content: $content)';
}


}

/// @nodoc
abstract mixin class $ToolBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $ToolBlockCopyWith(ToolBlock value, $Res Function(ToolBlock) _then) = _$ToolBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String toolId, String? toolName, Map<String, dynamic>? arguments, Object? content
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$ToolBlockCopyWithImpl<$Res>
    implements $ToolBlockCopyWith<$Res> {
  _$ToolBlockCopyWithImpl(this._self, this._then);

  final ToolBlock _self;
  final $Res Function(ToolBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? toolId = null,Object? toolName = freezed,Object? arguments = freezed,Object? content = freezed,}) {
  return _then(ToolBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,toolId: null == toolId ? _self.toolId : toolId // ignore: cast_nullable_to_non_nullable
as String,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self._arguments : arguments // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: freezed == content ? _self.content : content ,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class FileBlock implements MessageBlock {
  const FileBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.name, required this.url, required this.mimeType, this.size, this.file, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'file';
  factory FileBlock.fromJson(Map<String, dynamic> json) => _$FileBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String name;
 final  String url;
 final  String mimeType;
 final  int? size;
 final  MessageFileReference? file;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileBlockCopyWith<FileBlock> get copyWith => _$FileBlockCopyWithImpl<FileBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.size, size) || other.size == size)&&(identical(other.file, file) || other.file == file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),name,url,mimeType,size,file);

@override
String toString() {
  return 'MessageBlock.file(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, name: $name, url: $url, mimeType: $mimeType, size: $size, file: $file)';
}


}

/// @nodoc
abstract mixin class $FileBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $FileBlockCopyWith(FileBlock value, $Res Function(FileBlock) _then) = _$FileBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String name, String url, String mimeType, int? size, MessageFileReference? file
});


@override $ModelCopyWith<$Res>? get model;$MessageFileReferenceCopyWith<$Res>? get file;

}
/// @nodoc
class _$FileBlockCopyWithImpl<$Res>
    implements $FileBlockCopyWith<$Res> {
  _$FileBlockCopyWithImpl(this._self, this._then);

  final FileBlock _self;
  final $Res Function(FileBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? name = null,Object? url = null,Object? mimeType = null,Object? size = freezed,Object? file = freezed,}) {
  return _then(FileBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as MessageFileReference?,
  ));
}

/// Create a copy of MessageBlock
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
}/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageFileReferenceCopyWith<$Res>? get file {
    if (_self.file == null) {
    return null;
  }

  return $MessageFileReferenceCopyWith<$Res>(_self.file!, (value) {
    return _then(_self.copyWith(file: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ErrorBlock implements MessageBlock {
  const ErrorBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, this.message, this.details, this.code, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'error';
  factory ErrorBlock.fromJson(Map<String, dynamic> json) => _$ErrorBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  String? message;
 final  String? details;
 final  String? code;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorBlockCopyWith<ErrorBlock> get copyWith => _$ErrorBlockCopyWithImpl<ErrorBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.message, message) || other.message == message)&&(identical(other.details, details) || other.details == details)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,message,details,code);

@override
String toString() {
  return 'MessageBlock.error(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, message: $message, details: $details, code: $code)';
}


}

/// @nodoc
abstract mixin class $ErrorBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $ErrorBlockCopyWith(ErrorBlock value, $Res Function(ErrorBlock) _then) = _$ErrorBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content, String? message, String? details, String? code
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$ErrorBlockCopyWithImpl<$Res>
    implements $ErrorBlockCopyWith<$Res> {
  _$ErrorBlockCopyWithImpl(this._self, this._then);

  final ErrorBlock _self;
  final $Res Function(ErrorBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? message = freezed,Object? details = freezed,Object? code = freezed,}) {
  return _then(ErrorBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class CitationBlock implements MessageBlock {
  const CitationBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, this.source, this.url, final  List<CitationSource>? sources, this.response, final  List<KnowledgeReferenceItem>? knowledge, final  List<WebSearchReferenceItem>? webSearch, this.citationMetadata, final  String? $type}): _metadata = metadata,_error = error,_sources = sources,_knowledge = knowledge,_webSearch = webSearch,$type = $type ?? 'citation';
  factory CitationBlock.fromJson(Map<String, dynamic> json) => _$CitationBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  String? source;
 final  String? url;
 final  List<CitationSource>? _sources;
 List<CitationSource>? get sources {
  final value = _sources;
  if (value == null) return null;
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  Object? response;
 final  List<KnowledgeReferenceItem>? _knowledge;
 List<KnowledgeReferenceItem>? get knowledge {
  final value = _knowledge;
  if (value == null) return null;
  if (_knowledge is EqualUnmodifiableListView) return _knowledge;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<WebSearchReferenceItem>? _webSearch;
 List<WebSearchReferenceItem>? get webSearch {
  final value = _webSearch;
  if (value == null) return null;
  if (_webSearch is EqualUnmodifiableListView) return _webSearch;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  CitationMetadata? citationMetadata;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CitationBlockCopyWith<CitationBlock> get copyWith => _$CitationBlockCopyWithImpl<CitationBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CitationBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CitationBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.source, source) || other.source == source)&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other._sources, _sources)&&const DeepCollectionEquality().equals(other.response, response)&&const DeepCollectionEquality().equals(other._knowledge, _knowledge)&&const DeepCollectionEquality().equals(other._webSearch, _webSearch)&&(identical(other.citationMetadata, citationMetadata) || other.citationMetadata == citationMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,source,url,const DeepCollectionEquality().hash(_sources),const DeepCollectionEquality().hash(response),const DeepCollectionEquality().hash(_knowledge),const DeepCollectionEquality().hash(_webSearch),citationMetadata);

@override
String toString() {
  return 'MessageBlock.citation(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, source: $source, url: $url, sources: $sources, response: $response, knowledge: $knowledge, webSearch: $webSearch, citationMetadata: $citationMetadata)';
}


}

/// @nodoc
abstract mixin class $CitationBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $CitationBlockCopyWith(CitationBlock value, $Res Function(CitationBlock) _then) = _$CitationBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content, String? source, String? url, List<CitationSource>? sources, Object? response, List<KnowledgeReferenceItem>? knowledge, List<WebSearchReferenceItem>? webSearch, CitationMetadata? citationMetadata
});


@override $ModelCopyWith<$Res>? get model;$CitationMetadataCopyWith<$Res>? get citationMetadata;

}
/// @nodoc
class _$CitationBlockCopyWithImpl<$Res>
    implements $CitationBlockCopyWith<$Res> {
  _$CitationBlockCopyWithImpl(this._self, this._then);

  final CitationBlock _self;
  final $Res Function(CitationBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? source = freezed,Object? url = freezed,Object? sources = freezed,Object? response = freezed,Object? knowledge = freezed,Object? webSearch = freezed,Object? citationMetadata = freezed,}) {
  return _then(CitationBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,sources: freezed == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<CitationSource>?,response: freezed == response ? _self.response : response ,knowledge: freezed == knowledge ? _self._knowledge : knowledge // ignore: cast_nullable_to_non_nullable
as List<KnowledgeReferenceItem>?,webSearch: freezed == webSearch ? _self._webSearch : webSearch // ignore: cast_nullable_to_non_nullable
as List<WebSearchReferenceItem>?,citationMetadata: freezed == citationMetadata ? _self.citationMetadata : citationMetadata // ignore: cast_nullable_to_non_nullable
as CitationMetadata?,
  ));
}

/// Create a copy of MessageBlock
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
}/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CitationMetadataCopyWith<$Res>? get citationMetadata {
    if (_self.citationMetadata == null) {
    return null;
  }

  return $CitationMetadataCopyWith<$Res>(_self.citationMetadata!, (value) {
    return _then(_self.copyWith(citationMetadata: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class TranslationBlock implements MessageBlock {
  const TranslationBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, required this.sourceContent, required this.sourceLanguage, required this.targetLanguage, this.sourceBlockId, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'translation';
  factory TranslationBlock.fromJson(Map<String, dynamic> json) => _$TranslationBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  String sourceContent;
 final  String sourceLanguage;
 final  String targetLanguage;
 final  String? sourceBlockId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranslationBlockCopyWith<TranslationBlock> get copyWith => _$TranslationBlockCopyWithImpl<TranslationBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TranslationBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TranslationBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.sourceContent, sourceContent) || other.sourceContent == sourceContent)&&(identical(other.sourceLanguage, sourceLanguage) || other.sourceLanguage == sourceLanguage)&&(identical(other.targetLanguage, targetLanguage) || other.targetLanguage == targetLanguage)&&(identical(other.sourceBlockId, sourceBlockId) || other.sourceBlockId == sourceBlockId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,sourceContent,sourceLanguage,targetLanguage,sourceBlockId);

@override
String toString() {
  return 'MessageBlock.translation(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, sourceContent: $sourceContent, sourceLanguage: $sourceLanguage, targetLanguage: $targetLanguage, sourceBlockId: $sourceBlockId)';
}


}

/// @nodoc
abstract mixin class $TranslationBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $TranslationBlockCopyWith(TranslationBlock value, $Res Function(TranslationBlock) _then) = _$TranslationBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content, String sourceContent, String sourceLanguage, String targetLanguage, String? sourceBlockId
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$TranslationBlockCopyWithImpl<$Res>
    implements $TranslationBlockCopyWith<$Res> {
  _$TranslationBlockCopyWithImpl(this._self, this._then);

  final TranslationBlock _self;
  final $Res Function(TranslationBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? sourceContent = null,Object? sourceLanguage = null,Object? targetLanguage = null,Object? sourceBlockId = freezed,}) {
  return _then(TranslationBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,sourceContent: null == sourceContent ? _self.sourceContent : sourceContent // ignore: cast_nullable_to_non_nullable
as String,sourceLanguage: null == sourceLanguage ? _self.sourceLanguage : sourceLanguage // ignore: cast_nullable_to_non_nullable
as String,targetLanguage: null == targetLanguage ? _self.targetLanguage : targetLanguage // ignore: cast_nullable_to_non_nullable
as String,sourceBlockId: freezed == sourceBlockId ? _self.sourceBlockId : sourceBlockId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class ChartBlock implements MessageBlock {
  const ChartBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.chartType, required this.data, final  Map<String, dynamic>? options, final  String? $type}): _metadata = metadata,_error = error,_options = options,$type = $type ?? 'chart';
  factory ChartBlock.fromJson(Map<String, dynamic> json) => _$ChartBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  ChartType chartType;
 final  Object? data;
 final  Map<String, dynamic>? _options;
 Map<String, dynamic>? get options {
  final value = _options;
  if (value == null) return null;
  if (_options is EqualUnmodifiableMapView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChartBlockCopyWith<ChartBlock> get copyWith => _$ChartBlockCopyWithImpl<ChartBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChartBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChartBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.chartType, chartType) || other.chartType == chartType)&&const DeepCollectionEquality().equals(other.data, data)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),chartType,const DeepCollectionEquality().hash(data),const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'MessageBlock.chart(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, chartType: $chartType, data: $data, options: $options)';
}


}

/// @nodoc
abstract mixin class $ChartBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $ChartBlockCopyWith(ChartBlock value, $Res Function(ChartBlock) _then) = _$ChartBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, ChartType chartType, Object? data, Map<String, dynamic>? options
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$ChartBlockCopyWithImpl<$Res>
    implements $ChartBlockCopyWith<$Res> {
  _$ChartBlockCopyWithImpl(this._self, this._then);

  final ChartBlock _self;
  final $Res Function(ChartBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? chartType = null,Object? data = freezed,Object? options = freezed,}) {
  return _then(ChartBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,chartType: null == chartType ? _self.chartType : chartType // ignore: cast_nullable_to_non_nullable
as ChartType,data: freezed == data ? _self.data : data ,options: freezed == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class MathBlock implements MessageBlock {
  const MathBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, required this.displayMode, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'math';
  factory MathBlock.fromJson(Map<String, dynamic> json) => _$MathBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  bool displayMode;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MathBlockCopyWith<MathBlock> get copyWith => _$MathBlockCopyWithImpl<MathBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MathBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MathBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.displayMode, displayMode) || other.displayMode == displayMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,displayMode);

@override
String toString() {
  return 'MessageBlock.math(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, displayMode: $displayMode)';
}


}

/// @nodoc
abstract mixin class $MathBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $MathBlockCopyWith(MathBlock value, $Res Function(MathBlock) _then) = _$MathBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content, bool displayMode
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$MathBlockCopyWithImpl<$Res>
    implements $MathBlockCopyWith<$Res> {
  _$MathBlockCopyWithImpl(this._self, this._then);

  final MathBlock _self;
  final $Res Function(MathBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? displayMode = null,}) {
  return _then(MathBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,displayMode: null == displayMode ? _self.displayMode : displayMode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of MessageBlock
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

/// @nodoc
@JsonSerializable()

class KnowledgeReferenceBlock implements MessageBlock {
  const KnowledgeReferenceBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, this.metadata, final  Map<String, dynamic>? error, required this.content, required this.knowledgeBaseId, this.source, this.similarity, final  String? $type}): _error = error,$type = $type ?? 'knowledge_reference';
  factory KnowledgeReferenceBlock.fromJson(Map<String, dynamic> json) => _$KnowledgeReferenceBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
@override final  KnowledgeReferenceMetadata? metadata;
 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  String knowledgeBaseId;
 final  String? source;
 final  double? similarity;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KnowledgeReferenceBlockCopyWith<KnowledgeReferenceBlock> get copyWith => _$KnowledgeReferenceBlockCopyWithImpl<KnowledgeReferenceBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KnowledgeReferenceBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KnowledgeReferenceBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.knowledgeBaseId, knowledgeBaseId) || other.knowledgeBaseId == knowledgeBaseId)&&(identical(other.source, source) || other.source == source)&&(identical(other.similarity, similarity) || other.similarity == similarity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,metadata,const DeepCollectionEquality().hash(_error),content,knowledgeBaseId,source,similarity);

@override
String toString() {
  return 'MessageBlock.knowledgeReference(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, knowledgeBaseId: $knowledgeBaseId, source: $source, similarity: $similarity)';
}


}

/// @nodoc
abstract mixin class $KnowledgeReferenceBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $KnowledgeReferenceBlockCopyWith(KnowledgeReferenceBlock value, $Res Function(KnowledgeReferenceBlock) _then) = _$KnowledgeReferenceBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, KnowledgeReferenceMetadata? metadata, Map<String, dynamic>? error, String content, String knowledgeBaseId, String? source, double? similarity
});


@override $ModelCopyWith<$Res>? get model;$KnowledgeReferenceMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$KnowledgeReferenceBlockCopyWithImpl<$Res>
    implements $KnowledgeReferenceBlockCopyWith<$Res> {
  _$KnowledgeReferenceBlockCopyWithImpl(this._self, this._then);

  final KnowledgeReferenceBlock _self;
  final $Res Function(KnowledgeReferenceBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? knowledgeBaseId = null,Object? source = freezed,Object? similarity = freezed,}) {
  return _then(KnowledgeReferenceBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as KnowledgeReferenceMetadata?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,knowledgeBaseId: null == knowledgeBaseId ? _self.knowledgeBaseId : knowledgeBaseId // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,similarity: freezed == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of MessageBlock
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
}/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$KnowledgeReferenceMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $KnowledgeReferenceMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class ContextSummaryBlock implements MessageBlock {
  const ContextSummaryBlock({required this.id, required this.messageId, required this.status, @IsoDateTimeConverter() required this.createdAt, @IsoDateTimeConverter() this.updatedAt, this.model, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? error, required this.content, required this.originalMessageCount, required this.originalTokens, required this.compressedTokens, required this.tokensSaved, this.cost, @IsoDateTimeConverter() required this.compressedAt, this.modelId, final  String? $type}): _metadata = metadata,_error = error,$type = $type ?? 'context_summary';
  factory ContextSummaryBlock.fromJson(Map<String, dynamic> json) => _$ContextSummaryBlockFromJson(json);

@override final  String id;
@override final  String messageId;
@override final  MessageBlockStatus status;
@override@IsoDateTimeConverter() final  DateTime createdAt;
@override@IsoDateTimeConverter() final  DateTime? updatedAt;
@override final  Model? model;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _error;
@override Map<String, dynamic>? get error {
  final value = _error;
  if (value == null) return null;
  if (_error is EqualUnmodifiableMapView) return _error;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  String content;
 final  int originalMessageCount;
 final  int originalTokens;
 final  int compressedTokens;
 final  int tokensSaved;
 final  double? cost;
@IsoDateTimeConverter() final  DateTime compressedAt;
 final  String? modelId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContextSummaryBlockCopyWith<ContextSummaryBlock> get copyWith => _$ContextSummaryBlockCopyWithImpl<ContextSummaryBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContextSummaryBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContextSummaryBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.model, model) || other.model == model)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._error, _error)&&(identical(other.content, content) || other.content == content)&&(identical(other.originalMessageCount, originalMessageCount) || other.originalMessageCount == originalMessageCount)&&(identical(other.originalTokens, originalTokens) || other.originalTokens == originalTokens)&&(identical(other.compressedTokens, compressedTokens) || other.compressedTokens == compressedTokens)&&(identical(other.tokensSaved, tokensSaved) || other.tokensSaved == tokensSaved)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.compressedAt, compressedAt) || other.compressedAt == compressedAt)&&(identical(other.modelId, modelId) || other.modelId == modelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,messageId,status,createdAt,updatedAt,model,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_error),content,originalMessageCount,originalTokens,compressedTokens,tokensSaved,cost,compressedAt,modelId);

@override
String toString() {
  return 'MessageBlock.contextSummary(id: $id, messageId: $messageId, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, model: $model, metadata: $metadata, error: $error, content: $content, originalMessageCount: $originalMessageCount, originalTokens: $originalTokens, compressedTokens: $compressedTokens, tokensSaved: $tokensSaved, cost: $cost, compressedAt: $compressedAt, modelId: $modelId)';
}


}

/// @nodoc
abstract mixin class $ContextSummaryBlockCopyWith<$Res> implements $MessageBlockCopyWith<$Res> {
  factory $ContextSummaryBlockCopyWith(ContextSummaryBlock value, $Res Function(ContextSummaryBlock) _then) = _$ContextSummaryBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, String messageId, MessageBlockStatus status,@IsoDateTimeConverter() DateTime createdAt,@IsoDateTimeConverter() DateTime? updatedAt, Model? model, Map<String, dynamic>? metadata, Map<String, dynamic>? error, String content, int originalMessageCount, int originalTokens, int compressedTokens, int tokensSaved, double? cost,@IsoDateTimeConverter() DateTime compressedAt, String? modelId
});


@override $ModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$ContextSummaryBlockCopyWithImpl<$Res>
    implements $ContextSummaryBlockCopyWith<$Res> {
  _$ContextSummaryBlockCopyWithImpl(this._self, this._then);

  final ContextSummaryBlock _self;
  final $Res Function(ContextSummaryBlock) _then;

/// Create a copy of MessageBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = null,Object? status = null,Object? createdAt = null,Object? updatedAt = freezed,Object? model = freezed,Object? metadata = freezed,Object? error = freezed,Object? content = null,Object? originalMessageCount = null,Object? originalTokens = null,Object? compressedTokens = null,Object? tokensSaved = null,Object? cost = freezed,Object? compressedAt = null,Object? modelId = freezed,}) {
  return _then(ContextSummaryBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MessageBlockStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as Model?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,error: freezed == error ? _self._error : error // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,originalMessageCount: null == originalMessageCount ? _self.originalMessageCount : originalMessageCount // ignore: cast_nullable_to_non_nullable
as int,originalTokens: null == originalTokens ? _self.originalTokens : originalTokens // ignore: cast_nullable_to_non_nullable
as int,compressedTokens: null == compressedTokens ? _self.compressedTokens : compressedTokens // ignore: cast_nullable_to_non_nullable
as int,tokensSaved: null == tokensSaved ? _self.tokensSaved : tokensSaved // ignore: cast_nullable_to_non_nullable
as int,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,compressedAt: null == compressedAt ? _self.compressedAt : compressedAt // ignore: cast_nullable_to_non_nullable
as DateTime,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of MessageBlock
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
