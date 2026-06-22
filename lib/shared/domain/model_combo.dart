import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_combo.freezed.dart';
part 'model_combo.g.dart';

/// The strategy a model combo uses to orchestrate its models.
enum ModelComboStrategy {
  /// Think with model A, generate with model B (DeepClaude pattern).
  sequential,

  /// Call multiple models in parallel, show all results for user to pick.
  comparison,
}

/// A single model participating in a combo, with its assigned role.
@freezed
abstract class ComboModelEntry with _$ComboModelEntry {
  const factory ComboModelEntry({
    /// The model's identity key: `providerId/modelId`.
    required String modelId,

    /// Role within the combo: `thinking`, `generating`, or `candidate`.
    required String role,

    /// Execution priority (lower = runs first). Used by sequential strategy.
    @Default(0) int priority,
  }) = _ComboModelEntry;

  factory ComboModelEntry.fromJson(Map<String, dynamic> json) =>
      _$ComboModelEntryFromJson(json);
}

/// A model combo configuration. Persisted as a JSON list via [JsonKvNotifier].
@freezed
abstract class ModelComboConfig with _$ModelComboConfig {
  const factory ModelComboConfig({
    required String id,
    required String name,
    @Default('') String description,
    required ModelComboStrategy strategy,
    @Default(true) bool enabled,
    @Default(<ComboModelEntry>[]) List<ComboModelEntry> models,

    /// Whether to display the thinking model's reasoning in the chat UI.
    @Default(true) bool showThinking,

    /// Custom prompt template for passing thinking output to the generating
    /// model. `null` means use the built-in default.
    String? handoffPrompt,

    required String createdAt,
    required String updatedAt,
  }) = _ModelComboConfig;

  factory ModelComboConfig.fromJson(Map<String, dynamic> json) =>
      _$ModelComboConfigFromJson(json);
}

/// Persisted state: the list of all combos + global settings.
@freezed
abstract class ModelComboState with _$ModelComboState {
  const factory ModelComboState({
    @Default(<ModelComboConfig>[]) List<ModelComboConfig> combos,
    @Default(false) bool enableSmartRouting,
    String? routingModelId,

    /// The id of the currently active combo (selected in model selector), or
    /// `null` when a normal (non-combo) model is active.
    String? selectedComboId,
  }) = _ModelComboState;

  factory ModelComboState.fromJson(Map<String, dynamic> json) =>
      _$ModelComboStateFromJson(json);
}
