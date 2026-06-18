import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/shared/domain/system_prompt_variables.dart';

part 'system_prompt_variables_controller.g.dart';

/// Storage key for the persisted 系统提示词变量注入 config (a single JSON blob,
/// mirroring how the web kept it under `settings.systemPromptVariables`).
const String kSystemPromptVariablesKey = 'systemPromptVariables';

/// Holds the 系统提示词变量注入 configuration (the original
/// `settings.systemPromptVariables`), so the 智能体提示词集合 page stays a pure view
/// and the chat send flow can read it when assembling the system prompt.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and
/// the chat send flow. Hydrated from the Drift key/value store on first build
/// and written through on every change — the port of the web
/// `dexieStorage.saveSetting` — so the configuration survives a full restart.
@Riverpod(keepAlive: true)
class SystemPromptVariablesController
    extends _$SystemPromptVariablesController {
  @override
  SystemPromptVariables build() {
    _hydrate();
    return const SystemPromptVariables();
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kSystemPromptVariablesKey);
    if (stored == null || stored.isEmpty) return;
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      state = SystemPromptVariables.fromJson(json);
    } on FormatException {
      // Corrupt value — keep the defaults.
    }
  }

  void _persist(SystemPromptVariables next) {
    state = next;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kSystemPromptVariablesKey, jsonEncode(next.toJson()));
  }

  /// Toggles 时间变量 injection.
  void setEnableTimeVariable(bool value) =>
      _persist(state.copyWith(enableTimeVariable: value));

  /// Toggles 位置变量 injection.
  void setEnableLocationVariable(bool value) =>
      _persist(state.copyWith(enableLocationVariable: value));

  /// Sets the 自定义位置 override.
  void setCustomLocation(String value) =>
      _persist(state.copyWith(customLocation: value));

  /// Toggles 操作系统变量 injection.
  void setEnableOSVariable(bool value) =>
      _persist(state.copyWith(enableOSVariable: value));
}
