import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'model.freezed.dart';
part 'model.g.dart';

/// A configured model / provider endpoint. Cross-feature entity (chat,
/// settings, models all reference it), hence `shared/domain`. One-to-one
/// translation of `Model` (`src/shared/types/index.ts`).
///
/// Dropped per `docs/DOMAIN_MODEL.md` §5: `providerName` (runtime-injected, not
/// persisted) and `useCorsPlugin` (a webview-only CORS concept with no native
/// equivalent).
@freezed
abstract class Model with _$Model {
  const factory Model({
    required String id,
    required String name,
    required String provider,
    String? description,
    String? providerType,
    String? apiKey,
    String? baseUrl,
    int? maxTokens,
    double? temperature,
    bool? enabled,
    bool? isDefault,
    String? iconUrl,
    String? presetModelId,
    String? group,
    ModelCapabilities? capabilities,
    bool? multimodal,
    bool? imageGeneration,
    bool? videoGeneration,
    List<ModelType>? modelTypes,
    String? apiVersion,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
    Map<String, String>? providerExtraHeaders,
    Map<String, dynamic>? providerExtraBody,
    /// User-override for parameter display scope. When set, the parameter
    /// editor uses this instead of auto-detecting from model ID or
    /// providerType. Values: 'openai', 'anthropic', 'gemini', or null (auto).
    /// See `docs/PARAMETER_SCOPE_DESIGN.md`.
    String? parameterScope,
  }) = _Model;

  factory Model.fromJson(Map<String, dynamic> json) => _$ModelFromJson(json);
}
