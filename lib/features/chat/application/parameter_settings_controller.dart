import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor.dart';

part 'parameter_settings_controller.g.dart';

/// Storage key for the persisted parameter settings (a single JSON blob).
const String kParameterSettingsKey = 'parameterSettings';

/// Manages the user's parameter configuration — values, enabled flags and
/// custom parameters. Mirrors the web `ParameterSyncService` with Riverpod
/// reactive state + Drift key/value persistence.
@Riverpod(keepAlive: true)
class ParameterSettingsController extends _$ParameterSettingsController
    with JsonKvNotifier<ParameterSettings>
    implements ParameterDelegate {
  @override
  ChatRepository get kvStore => ref.read(chatRepositoryProvider);

  @override
  String get storageKey => kParameterSettingsKey;

  @override
  ParameterSettings fromStored(Map<String, dynamic> json) =>
      ParameterSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(ParameterSettings value) => value.toJson();

  @override
  ParameterSettings build() => hydrate(const ParameterSettings());

  // ── Value setters ─────────────────────────────────────────────────────────

  /// Sets the value for a single parameter [key].
  void setParameterValue(String key, Object? value) {
    final next = Map<String, dynamic>.of(state.values);
    next[key] = value;
    persist(state.copyWith(values: next));
  }

  /// Sets the enabled flag for a single parameter [key].
  void setParameterEnabled(String key, bool enabled) {
    final next = Map<String, bool>.of(state.enabledFlags);
    next[key] = enabled;
    persist(state.copyWith(enabledFlags: next));
  }

  /// Adds a custom parameter.
  void addCustomParameter(Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(state.customParameters)
      ..add(param);
    persist(state.copyWith(customParameters: next));
  }

  /// Removes a custom parameter by index.
  void removeCustomParameter(int index) {
    final next = List<Map<String, dynamic>>.of(state.customParameters);
    if (index >= 0 && index < next.length) {
      next.removeAt(index);
      persist(state.copyWith(customParameters: next));
    }
  }

  /// Updates a custom parameter at [index].
  void updateCustomParameter(int index, Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(state.customParameters);
    if (index >= 0 && index < next.length) {
      next[index] = param;
      persist(state.copyWith(customParameters: next));
    }
  }

  /// Resets all parameter values and enabled flags to defaults (clears stored
  /// overrides so metadata defaults take effect).
  void resetAll() {
    persist(const ParameterSettings());
  }
}
