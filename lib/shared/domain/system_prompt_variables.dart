import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_prompt_variables.freezed.dart';
part 'system_prompt_variables.g.dart';

/// The 系统提示词变量注入 configuration (the port of the web
/// `settings.systemPromptVariables` / `SystemPromptVariableConfig`).
///
/// Each flag appends a dynamic line (time / location / OS) to the assembled
/// system prompt before a message is sent; [customLocation] overrides the
/// auto-detected location when set. Defaults mirror the original fallback —
/// every variable off and no custom location.
@freezed
abstract class SystemPromptVariables with _$SystemPromptVariables {
  const factory SystemPromptVariables({
    @Default(false) bool enableTimeVariable,
    @Default(false) bool enableLocationVariable,
    @Default('') String customLocation,
    @Default(false) bool enableOSVariable,
    @Default(false) bool enableLocaleVariable,
  }) = _SystemPromptVariables;

  factory SystemPromptVariables.fromJson(Map<String, dynamic> json) =>
      _$SystemPromptVariablesFromJson(json);
}
