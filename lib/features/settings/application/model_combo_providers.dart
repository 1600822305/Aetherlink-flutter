import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'model_combo_providers.g.dart';

/// The virtual provider id used for all model combos.
const String kModelComboProviderId = 'model-combo';

/// A virtual [ModelProvider] whose [Model] list is synthesized from the enabled
/// [ModelComboConfig] entries. The model selector can include this alongside
/// real providers so the user can pick a combo as their current model.
@riverpod
ModelProvider? comboVirtualProvider(Ref ref) {
  final comboState = ref.watch(modelComboControllerProvider);
  final enabledCombos = comboState.combos.where((c) => c.enabled).toList();
  if (enabledCombos.isEmpty) return null;

  return ModelProvider(
    id: kModelComboProviderId,
    name: '模型组合',
    avatar: '🔗',
    color: '#7c4dff',
    isEnabled: true,
    isSystem: true,
    models: [
      for (final combo in enabledCombos)
        Model(
          id: combo.id,
          name: combo.name,
          provider: kModelComboProviderId,
          description: combo.description.isEmpty
              ? _strategyLabel(combo.strategy)
              : combo.description,
          enabled: true,
        ),
    ],
  );
}

/// All model providers including the virtual combo provider (if any combos are
/// enabled). Use this instead of [appModelProvidersProvider] when the combo
/// virtual models should appear in the list.
@riverpod
Future<List<ModelProvider>> allProvidersWithCombos(Ref ref) async {
  final providers = await ref.watch(appModelProvidersProvider.future);
  final combo = ref.watch(comboVirtualProviderProvider);
  if (combo == null) return providers;
  return [combo, ...providers];
}

/// Looks up the [ModelComboConfig] for a model id, or `null` if the model id
/// does not refer to a combo.
@riverpod
ModelComboConfig? comboConfigForModel(Ref ref, String modelId) {
  final comboState = ref.watch(modelComboControllerProvider);
  for (final combo in comboState.combos) {
    if (combo.id == modelId) return combo;
  }
  return null;
}

String _strategyLabel(ModelComboStrategy strategy) => switch (strategy) {
  ModelComboStrategy.sequential => '思考+生成',
  ModelComboStrategy.comparison => '模型对比',
};
