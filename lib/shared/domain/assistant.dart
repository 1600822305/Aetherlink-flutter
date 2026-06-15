import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/custom_parameter.dart';
import 'package:aetherlink_flutter/shared/domain/quick_phrase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant.freezed.dart';
part 'assistant.g.dart';

/// An AI assistant configuration. Cross-feature entity (chat, assistants,
/// settings), hence `shared/domain`. Translation of `Assistant`
/// (`src/shared/types/Assistant.ts`).
///
/// Dropped per `docs/DOMAIN_MODEL.md` §5: `icon?: ReactNode` (React-only) and
/// `topics: ChatTopic[]` (runtime aggregate assembled by the repository, not
/// persisted). `topicIds` is retained for persistence.
@freezed
abstract class Assistant with _$Assistant {
  const factory Assistant({
    required String id,
    required String name,
    String? description,
    String? avatar,
    String? emoji,
    List<String>? tags,
    String? engine,
    String? model,
    double? temperature,
    int? maxTokens,
    double? topP,
    double? frequencyPenalty,
    double? presencePenalty,
    String? systemPrompt,
    String? prompt,
    int? maxMessagesInContext,
    bool? isDefault,
    bool? isSystem,
    bool? archived,
    @IsoDateTimeConverter() DateTime? createdAt,
    @IsoDateTimeConverter() DateTime? updatedAt,
    @IsoDateTimeConverter() DateTime? lastUsedAt,
    @Default(<String>[]) List<String> topicIds,
    String? selectedSystemPromptId,
    String? mcpConfigId,
    List<String>? tools,
    @JsonKey(name: 'tool_choice') String? toolChoice,
    String? speechModel,
    String? speechVoice,
    double? speechSpeed,
    String? responseFormat,
    bool? isLocal,
    String? localModelName,
    String? localModelPath,
    String? localModelType,
    @JsonKey(name: 'file_ids') List<String>? fileIds,
    String? type,
    List<QuickPhrase>? regularPhrases,
    String? webSearchProviderId,
    bool? enableWebSearch,
    List<CustomParameter>? customParameters,
    List<AssistantRegex>? regexRules,
    AssistantChatBackground? chatBackground,
    bool? memoryEnabled,
    List<String>? skillIds,
    String? activeSkillId,
  }) = _Assistant;

  factory Assistant.fromJson(Map<String, dynamic> json) =>
      _$AssistantFromJson(json);
}
