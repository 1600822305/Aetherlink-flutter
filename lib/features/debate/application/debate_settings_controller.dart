import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_models.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';

part 'debate_settings_controller.g.dart';

/// Storage key for the AI 辩论 settings JSON blob.
const String kDebateSettingsKey = 'aiDebateSettings';

/// Holds the AI 辩论 configuration（角色、轮数、场景快照等）。
/// 设置页负责编辑；开始面板与引擎读取纯 [DebateSettings] 值。
@Riverpod(keepAlive: true)
class DebateSettingsController extends _$DebateSettingsController
    with JsonKvNotifier<DebateSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kDebateSettingsKey;

  @override
  DebateSettings fromStored(Map<String, dynamic> json) =>
      DebateSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(DebateSettings value) => value.toJson();

  @override
  DebateSettings build() => hydrate(const DebateSettings());

  void setMaxRounds(int value) =>
      persist(state.copyWith(maxRounds: value.clamp(1, 20)));

  void setTurnGapSeconds(int value) =>
      persist(state.copyWith(turnGapSeconds: value.clamp(0, 10)));

  void setHistoryWindow(int value) =>
      persist(state.copyWith(historyWindow: value.clamp(2, 20)));

  void setMaxCharsPerTurn(int value) =>
      persist(state.copyWith(maxCharsPerTurn: value.clamp(50, 1000)));

  void setModeratorEnabled(bool value) =>
      persist(state.copyWith(moderatorEnabled: value));

  void setSummaryEnabled(bool value) =>
      persist(state.copyWith(summaryEnabled: value));

  void setVerdictEnabled(bool value) =>
      persist(state.copyWith(verdictEnabled: value));

  void setTtsEnabled(bool value) =>
      persist(state.copyWith(ttsEnabled: value));

  void upsertRole(DebateRole role) {
    final roles = [...state.roles];
    final index = roles.indexWhere((r) => r.id == role.id);
    if (index >= 0) {
      roles[index] = role;
    } else {
      roles.add(role);
    }
    persist(state.copyWith(roles: roles));
  }

  void removeRole(String roleId) => persist(
    state.copyWith(roles: [
      for (final r in state.roles)
        if (r.id != roleId) r,
    ]),
  );

  /// 一键场景：整组替换当前角色。
  void replaceRoles(List<DebateRole> roles) =>
      persist(state.copyWith(roles: roles));

  /// 把当前配置保存为命名场景快照。
  void saveScene({required String name, String description = ''}) {
    final scene = DebateScene(
      id: generateId('debate_scene'),
      name: name,
      description: description,
      roles: state.roles,
      maxRounds: state.maxRounds,
      moderatorEnabled: state.moderatorEnabled,
      summaryEnabled: state.summaryEnabled,
    );
    persist(state.copyWith(scenes: [...state.scenes, scene]));
  }

  /// 加载场景快照，覆盖当前角色与关键参数。
  void loadScene(String sceneId) {
    final scene = state.scenes.where((s) => s.id == sceneId).firstOrNull;
    if (scene == null) return;
    persist(
      state.copyWith(
        roles: scene.roles,
        maxRounds: scene.maxRounds,
        moderatorEnabled: scene.moderatorEnabled,
        summaryEnabled: scene.summaryEnabled,
      ),
    );
  }

  void removeScene(String sceneId) => persist(
    state.copyWith(scenes: [
      for (final s in state.scenes)
        if (s.id != sceneId) s,
    ]),
  );
}
