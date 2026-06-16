import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// The app-level "current chat model": the [model] the composer sends to,
/// together with the [provider] that holds its endpoint config (apiKey /
/// baseUrl / providerType / extra headers / body).
///
/// Pure Dart (boundary Rule 2) so both `chat` and `settings` can depend on it
/// across features through `models`' `domain` layer.
class CurrentModel {
  const CurrentModel({required this.provider, required this.model});

  final ModelProvider provider;
  final Model model;
}

/// The single app-level current model: the first model flagged
/// [Model.isDefault] scanning providers in their user-defined order, or `null`
/// when none is selected (a fresh install, or every provider empty).
///
/// Reusing `isDefault` as the app-wide selection keeps the choice persisted by
/// the existing provider store — no extra table or dependency. Selecting a
/// model is therefore "clear `isDefault` everywhere, set it on the chosen one"
/// (see [providersWithCurrentModel]).
CurrentModel? findCurrentModel(List<ModelProvider> providers) {
  for (final provider in providers) {
    for (final model in provider.models) {
      if (model.isDefault ?? false) {
        return CurrentModel(provider: provider, model: model);
      }
    }
  }
  return null;
}

/// The providers list with the app-level current model set to ([providerId],
/// [modelId]): `isDefault` is cleared on every other model and set on the
/// chosen one. Providers whose models are unchanged are returned as-is, so a
/// caller can persist only what actually changed.
List<ModelProvider> providersWithCurrentModel(
  List<ModelProvider> providers, {
  required String providerId,
  required String modelId,
}) {
  return [
    for (final provider in providers)
      provider.copyWith(
        models: [
          for (final model in provider.models)
            model.copyWith(
              isDefault: provider.id == providerId && model.id == modelId,
            ),
        ],
      ),
  ];
}

/// The [Model] to send with: the chosen model enriched with the provider's
/// endpoint config where the model does not override it. The provider's
/// `apiKey` / `baseUrl` / `providerType` fill in for an empty model value, and
/// the provider's extra headers / body are exposed via
/// [providerExtraHeaders] / [providerExtraBody] for callers building a request.
Model effectiveModelFor(CurrentModel current) {
  final model = current.model;
  final provider = current.provider;
  return model.copyWith(
    apiKey: _firstNonEmpty(model.apiKey, provider.apiKey),
    baseUrl: _firstNonEmpty(model.baseUrl, provider.baseUrl),
    providerType: model.providerType ?? provider.providerType,
    providerExtraHeaders: provider.extraHeaders,
    providerExtraBody: provider.extraBody,
  );
}

String? _firstNonEmpty(String? a, String? b) {
  if (a != null && a.isNotEmpty) return a;
  if (b != null && b.isNotEmpty) return b;
  return a ?? b;
}
