import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_provider.freezed.dart';
part 'model_provider.g.dart';

/// A model provider (vendor) configuration. Cross-feature entity (models,
/// settings, chat), hence `shared/domain`. Translation of `ModelProvider`
/// (`src/shared/config/defaultModels.ts`); spec in `docs/DOMAIN_MODEL.md` §4.
///
/// Pure Dart (boundary Rule 2): no Flutter / IO types. [avatar] and [color]
/// stay [String] exactly as the original stores them — `color` is a hex string
/// (`#10a37f`), `avatar` a letter / emoji / asset key — so the JSON blob
/// round-trips 1:1 with the original and no lossy `Color`/`IconData` encoding
/// is invented.
///
/// Dropped per `docs/DOMAIN_MODEL.md` §5: `useCorsPlugin` (webview-only, like
/// `Model.useCorsPlugin`) and the web-only `customModelEndpoint`.
///
/// [useResponsesAPI] is consumed by the request layer: when set, the OpenAI
/// adapter posts to `/responses` (via [LlmChatRequest.useResponsesAPI]) instead
/// of `/chat/completions`. [apiKeys] and [keyManagement] drive multi-key load
/// balancing: when the pool is non-empty the request layer
/// (`ChatController._streamInto` via `ApiKeyManager`) strategy-selects a key per
/// request, fails over to the next key on error and persists per-key
/// usage/status back. See `docs/DOMAIN_MODEL.md` §4.
@freezed
abstract class ModelProvider with _$ModelProvider {
  const factory ModelProvider({
    required String id,
    required String name,
    required String avatar,
    required String color,
    @Default(false) bool isEnabled,
    @Default(<Model>[]) List<Model> models,
    String? apiKey,
    String? baseUrl,
    String? providerType,
    bool? isSystem,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    // Whether to call OpenAI's `/responses` endpoint instead of
    // `/chat/completions` (only meaningful for OpenAI-family types). Consumed
    // by the OpenAI adapter via [LlmChatRequest.useResponsesAPI].
    bool? useResponsesAPI,
    // The multi-key pool + its load-balancing config. Edited by the multi-key
    // manager page, persisted, and consumed by request scheduling
    // (`ApiKeyManager`); model-fetch still uses the single [apiKey].
    List<ApiKeyConfig>? apiKeys,
    KeyManagementConfig? keyManagement,
    /// Provider-level override for parameter display scope. Applied to all
    /// models under this provider unless the model has its own
    /// [Model.parameterScope]. See `docs/PARAMETER_SCOPE_DESIGN.md`.
    String? parameterScope,
  }) = _ModelProvider;

  factory ModelProvider.fromJson(Map<String, dynamic> json) =>
      _$ModelProviderFromJson(json);
}
