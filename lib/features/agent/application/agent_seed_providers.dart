import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_builtin_profiles.dart';

part 'agent_seed_providers.g.dart';

/// 一次性种子数据标记：首次启动把内置预设档案写入 drift，
/// 之后一律以库为准（删光不会重新种入）。
const String kAgentSeededKey = 'agent_seeded_v1';

/// 一次性清理标记：移除 UI 先行阶段种入的演示话题，并清掉内置
/// 档案上的假工作区绑定（ws-1/ws-2 不对应任何真实工作区）。
const String kAgentMockPurgedKey = 'agent_mock_purged_v1';

/// 首次运行时的一次性种子写入（内置预设档案）。keepAlive 保证
/// 多个 hydrate 入口共享同一次 Future，不会重复种入。
@Riverpod(keepAlive: true)
Future<void> agentSeed(Ref ref) async {
  final store = ref.read(appSettingsStoreProvider);
  final dao = ref.read(agentDaoProvider);
  if (await store.getSetting(kAgentSeededKey) != '1') {
    for (final profile in kBuiltinAgentProfiles) {
      await dao.upsertProfile(profile);
    }
    await store.saveSetting(kAgentSeededKey, '1');
  }
  await _purgeMockData(ref);
}

/// 旧版首次启动曾种入 3 条演示话题（task-1/2/3）和带假工作区
/// 绑定（ws-1/ws-2）的内置档案；这里对已种入的安装做一次性清理。
Future<void> _purgeMockData(Ref ref) async {
  final store = ref.read(appSettingsStoreProvider);
  final dao = ref.read(agentDaoProvider);
  if (await store.getSetting(kAgentMockPurgedKey) == '1') return;
  for (final id in const ['task-1', 'task-2', 'task-3']) {
    await dao.deleteTask(id);
  }
  for (final profile in await dao.getAllProfiles()) {
    if (profile.builtin &&
        (profile.workspaceId == 'ws-1' || profile.workspaceId == 'ws-2')) {
      await dao.upsertProfile(
        profile.copyWith(workspaceId: null, workspaceName: null),
      );
    }
  }
  await store.saveSetting(kAgentMockPurgedKey, '1');
}
