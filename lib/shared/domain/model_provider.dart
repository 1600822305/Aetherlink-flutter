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
/// `Model.useCorsPlugin`), plus the web-only `useResponsesAPI` /
/// `customModelEndpoint`. Multi-key (`apiKeys` / `keyManagement` /
/// `ApiKeyConfig`) is not yet spec'd in the SSOT, so only the single
/// backward-compat [apiKey] is carried — see the TODO below.
@freezed
abstract class ModelProvider with _$ModelProvider {
  const factory ModelProvider({
    required String id,
    required String name,
    required String avatar,
    required String color,
    @Default(false) bool isEnabled,
    @Default(<Model>[]) List<Model> models,
    // TODO(multi-key): the original also has `apiKeys: ApiKeyConfig[]` +
    // `keyManagement` for round-robin/quota scheduling. That is a whole
    // web-side runtime concern not yet spec'd in `docs/DOMAIN_MODEL.md`; carry
    // only the single backward-compat key for now and model the multi-key
    // types once the SSOT defines their semantics (don't invent them here).
    String? apiKey,
    String? baseUrl,
    String? providerType,
    bool? isSystem,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
  }) = _ModelProvider;

  factory ModelProvider.fromJson(Map<String, dynamic> json) =>
      _$ModelProviderFromJson(json);
}
