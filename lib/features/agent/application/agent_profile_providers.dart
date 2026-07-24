import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_builtin_profiles.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_seed_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';

part 'agent_profile_providers.g.dart';

/// last-active 持久化键（架构稿 §三：agent 模式重启 → 恢复上次所在的
/// 智能体）。
const String kLastActiveAgentProfileKey = 'agent_last_profile';

/// 智能体档案列表（drift 持久化）：冷启动从库 hydrate，增删改写穿。
@Riverpod(keepAlive: true)
class AgentProfiles extends _$AgentProfiles {
  @override
  List<AgentProfile> build() {
    _hydrate();
    return const [];
  }

  Future<void> _hydrate() async {
    await ref.read(agentSeedProvider.future);
    final fromDb = await ref.read(agentDaoProvider).getAllProfiles();
    // hydrate 窗口内用户已增/改的档案优先，不被整表读回结果覆盖。
    final existing = state;
    state = [
      for (final p in fromDb)
        existing.where((e) => e.id == p.id).firstOrNull ?? p,
      for (final e in existing)
        if (!fromDb.any((p) => p.id == e.id)) e,
    ];
  }

  /// 新增或按 id 覆盖一个档案（编辑页保存），等待落库完成。
  Future<void> upsert(AgentProfile profile) async {
    final index = state.indexWhere((p) => p.id == profile.id);
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) profile else state[i],
      if (index < 0) profile,
    ];
    await ref.read(agentDaoProvider).upsertProfile(profile);
  }

  Future<void> remove(String profileId) async {
    state = [
      for (final p in state)
        if (p.id != profileId) p,
    ];
    await ref.read(agentDaoProvider).deleteProfile(profileId);
  }
}

/// 当前选中的智能体档案 id；冷启动从 KV 恢复，切换写穿。
@Riverpod(keepAlive: true)
class SelectedAgentProfileId extends _$SelectedAgentProfileId {
  @override
  String build() {
    _hydrate();
    return kBuiltinAgentProfiles.first.id;
  }

  bool _userSelected = false;

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kLastActiveAgentProfileKey);
    if (_userSelected || stored == null || stored.isEmpty) return;
    // 不在这里验存在性（档案列表可能尚未 hydrate 完）；UI 侧用
    // firstOrNull 回退，档案已删时自动落到第一个/空态。
    state = stored;
  }

  void select(String id) {
    _userSelected = true;
    state = id;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kLastActiveAgentProfileKey, id);
  }
}
