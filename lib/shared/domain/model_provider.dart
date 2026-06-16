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
/// [useResponsesAPI], [apiKeys] and [keyManagement] are modelled for UI +
/// persistence (the 三级页 配置 Tab edits them and they round-trip through the
/// JSON blob), but the request layer does **not** consume them yet: the OpenAI
/// adapter still posts to `/chat/completions` with the single [apiKey], so the
/// UI marks the Responses-API toggle and multi-key scheduling as 即将支持. See
/// `docs/DOMAIN_MODEL.md` §4.
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
    // `/chat/completions` (only meaningful for OpenAI-family types). UI +
    // persistence only — the adapter does not branch on it yet (即将支持).
    bool? useResponsesAPI,
    // The multi-key pool + its load-balancing config. Edited by the multi-key
    // manager page and persisted, but not yet consumed by request scheduling
    // (即将支持); chat / model-fetch still use the single [apiKey].
    List<ApiKeyConfig>? apiKeys,
    KeyManagementConfig? keyManagement,
  }) = _ModelProvider;

  factory ModelProvider.fromJson(Map<String, dynamic> json) =>
      _$ModelProviderFromJson(json);
}
