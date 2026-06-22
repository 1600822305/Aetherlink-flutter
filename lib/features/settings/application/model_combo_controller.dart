import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';

part 'model_combo_controller.g.dart';

const String kModelComboSettingKey = 'modelCombos';

@Riverpod(keepAlive: true)
class ModelComboController extends _$ModelComboController
    with JsonKvNotifier<ModelComboState> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kModelComboSettingKey;

  @override
  ModelComboState fromStored(Map<String, dynamic> json) =>
      ModelComboState.fromJson(json);

  @override
  Map<String, dynamic> toStored(ModelComboState value) => value.toJson();

  @override
  ModelComboState build() => hydrate(const ModelComboState());

  void addCombo(ModelComboConfig combo) {
    persist(state.copyWith(combos: [...state.combos, combo]));
  }

  void updateCombo(ModelComboConfig combo) {
    final updated = state.combos.map((c) => c.id == combo.id ? combo : c);
    persist(state.copyWith(combos: updated.toList()));
  }

  void deleteCombo(String id) {
    persist(
      state.copyWith(combos: state.combos.where((c) => c.id != id).toList()),
    );
  }

  void toggleComboEnabled(String id) {
    final updated = state.combos.map((c) {
      if (c.id != id) return c;
      return c.copyWith(enabled: !c.enabled);
    });
    persist(state.copyWith(combos: updated.toList()));
  }

  void selectCombo(String comboId) {
    persist(state.copyWith(selectedComboId: comboId));
  }

  void clearComboSelection() {
    persist(state.copyWith(selectedComboId: null));
  }

  void setSmartRouting(bool value) {
    persist(state.copyWith(enableSmartRouting: value));
  }

  void setRoutingModelId(String? id) {
    persist(state.copyWith(routingModelId: id));
  }
}
