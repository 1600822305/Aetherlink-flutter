import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant_regex.freezed.dart';
part 'assistant_regex.g.dart';

/// Which side a regex replacement applies to. Mirrors `AssistantRegexScope`
/// (`src/shared/types/Assistant.ts`).
enum AssistantRegexScope {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
}

/// A regex find/replace rule attached to an assistant. Mirrors
/// `AssistantRegex` (`src/shared/types/Assistant.ts`).
@freezed
abstract class AssistantRegex with _$AssistantRegex {
  const factory AssistantRegex({
    required String id,
    required String name,
    required String pattern,
    required String replacement,
    @Default(<AssistantRegexScope>[]) List<AssistantRegexScope> scopes,
    required bool visualOnly,
    required bool enabled,
  }) = _AssistantRegex;

  factory AssistantRegex.fromJson(Map<String, dynamic> json) =>
      _$AssistantRegexFromJson(json);
}
