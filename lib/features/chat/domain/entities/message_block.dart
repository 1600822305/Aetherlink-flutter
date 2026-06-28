import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/chart_type.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/citation_metadata.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/citation_source.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_metadata.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_file_reference.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_reference_item.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_block.freezed.dart';
part 'message_block.g.dart';

/// The message block discriminated union.
///
/// One-to-one translation of `MessageBlock` (`src/shared/types/newMessage.ts`),
/// a `BaseMessageBlock` plus its 15 variants. Modelled as a `sealed` union so
/// rendering is exhaustively checked at compile time. The `type` field is the
/// JSON discriminator (wire values pinned via [FreezedUnionValue]); unknown
/// wire types fall back to [UnknownBlock].
///
/// freezed unions have no shared base-class fields, so the eight common fields
/// from `BaseMessageBlock` (id / messageId / status / createdAt / updatedAt /
/// model / metadata / error) are repeated on every variant.
@Freezed(
  unionKey: 'type',
  unionValueCase: FreezedUnionCase.none,
  fallbackUnion: 'unknown',
)
sealed class MessageBlock with _$MessageBlock {
  /// Placeholder / unrecognised block (`UNKNOWN`).
  @FreezedUnionValue('unknown')
  const factory MessageBlock.unknown({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    String? content,
  }) = UnknownBlock;

  /// Primary assistant/user text (`MAIN_TEXT`).
  @FreezedUnionValue('main_text')
  const factory MessageBlock.mainText({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
  }) = MainTextBlock;

  /// Reasoning / thinking trace (`THINKING`).
  @FreezedUnionValue('thinking')
  const factory MessageBlock.thinking({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    @JsonKey(name: 'thinking_millsec') int? thinkingMillsec,
    int? thinkingStartTime,
  }) = ThinkingBlock;

  /// Image attachment (`IMAGE`).
  @FreezedUnionValue('image')
  const factory MessageBlock.image({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String url,
    required String mimeType,
    String? base64Data,
    int? width,
    int? height,
    int? size,
    MessageFileReference? file,
  }) = ImageBlock;

  /// Video attachment (`VIDEO`).
  @FreezedUnionValue('video')
  const factory MessageBlock.video({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String url,
    required String mimeType,
    String? base64Data,
    int? width,
    int? height,
    int? size,
    int? duration,
    String? poster,
    MessageFileReference? file,
  }) = VideoBlock;

  /// Fenced code (`CODE`).
  @FreezedUnionValue('code')
  const factory MessageBlock.code({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    String? language,
  }) = CodeBlock;

  /// Tool / MCP call (`TOOL`). `content` is `string | object` in the source, so
  /// it stays a dynamic [Object].
  @FreezedUnionValue('tool')
  const factory MessageBlock.tool({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String toolId,
    String? toolName,
    Map<String, dynamic>? arguments,
    Object? content,
  }) = ToolBlock;

  /// File attachment (`FILE`).
  @FreezedUnionValue('file')
  const factory MessageBlock.file({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String name,
    required String url,
    required String mimeType,
    int? size,
    MessageFileReference? file,
  }) = FileBlock;

  /// Error surface (`ERROR`).
  @FreezedUnionValue('error')
  const factory MessageBlock.error({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    String? message,
    String? details,
    String? code,
  }) = ErrorBlock;

  /// Unified citation block (`CITATION`). `response` is `any` in the source, so
  /// it stays a dynamic [Object].
  @FreezedUnionValue('citation')
  const factory MessageBlock.citation({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    String? source,
    String? url,
    List<CitationSource>? sources,
    Object? response,
    List<KnowledgeReferenceItem>? knowledge,
    List<WebSearchReferenceItem>? webSearch,
    CitationMetadata? citationMetadata,
  }) = CitationBlock;

  /// Translation result (`TRANSLATION`).
  @FreezedUnionValue('translation')
  const factory MessageBlock.translation({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    required String sourceContent,
    required String sourceLanguage,
    required String targetLanguage,
    String? sourceBlockId,
  }) = TranslationBlock;

  /// Chart (`CHART`). `data` is `unknown` in the source, so it stays a dynamic
  /// [Object].
  @FreezedUnionValue('chart')
  const factory MessageBlock.chart({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required ChartType chartType,
    required Object? data,
    Map<String, dynamic>? options,
  }) = ChartBlock;

  /// Math formula (`MATH`).
  @FreezedUnionValue('math')
  const factory MessageBlock.math({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    required bool displayMode,
  }) = MathBlock;

  /// Knowledge-base reference (`KNOWLEDGE_REFERENCE`).
  @FreezedUnionValue('knowledge_reference')
  const factory MessageBlock.knowledgeReference({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    KnowledgeReferenceMetadata? metadata,
    Map<String, dynamic>? error,
    required String content,
    required String knowledgeBaseId,
    String? source,
    double? similarity,
  }) = KnowledgeReferenceBlock;

  /// Context-compression summary (`CONTEXT_SUMMARY`).
  @FreezedUnionValue('context_summary')
  const factory MessageBlock.contextSummary({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required String content,
    required int originalMessageCount,
    required int originalTokens,
    required int compressedTokens,
    required int tokensSaved,
    double? cost,
    @IsoDateTimeConverter() required DateTime compressedAt,
    String? modelId,
  }) = ContextSummaryBlock;

  /// Memory injected into the system prompt this turn (`MEMORY_INJECTION`).
  /// A non-model, app-generated info block prepended to the assistant message
  /// so the user can see how many long-term memories were fed in and which —
  /// the 对话内「本轮注入 N 条记忆」可展开块. [memories] holds the injected
  /// contents in injection order; [count] is their number.
  @FreezedUnionValue('memory_injection')
  const factory MessageBlock.memoryInjection({
    required String id,
    required String messageId,
    required MessageBlockStatus status,
    @IsoDateTimeConverter() required DateTime createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    Model? model,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? error,
    required int count,
    @Default(<String>[]) List<String> memories,
  }) = MemoryInjectionBlock;

  factory MessageBlock.fromJson(Map<String, dynamic> json) =>
      _$MessageBlockFromJson(json);
}
