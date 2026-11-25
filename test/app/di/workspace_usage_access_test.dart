// 工作区移除的连带解绑（app/di/workspace_usage_access.dart）：
// - workspaceUsageProvider 按 workspaceId 聚合智能体档案 / 话题 / MCP 服务器引用；
// - WorkspaceRemoval.remove / clearAll 从列表移除后清掉档案与 MCP 服务器上的
//   绑定（MCP 一并停用），话题保留原 workspaceId 作为历史；
// - 未引用被移除工作区的档案 / 服务器不受影响。
//
// 跑在真实内存 Drift 库上（与 ssh_stores_test 同一套装配）。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_usage_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_builtin_profiles.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_profile_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_seed_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';

void main() {
  Future<ProviderContainer> makeContainer() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    // 档案 / 话题都是 build 返回空表后异步 hydrate：等种子写完、内置档案读回，
    // 避免测试写入与 hydrate 合并交错。
    c.read(agentProfilesProvider);
    c.read(agentTasksProvider);
    await c.read(agentSeedProvider.future);
    for (var i = 0; i < 200; i++) {
      if (c.read(agentProfilesProvider).length >= kBuiltinAgentProfiles.length) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await c.read(workspaceStoreProvider.future);
    await c.read(mcpServersProvider.future);
    return c;
  }

  Future<Workspace> openWorkspace(ProviderContainer c, String name) =>
      c.read(workspaceStoreProvider.notifier).open(
            name: name,
            backendType: WorkspaceBackendType.localSaf,
            root: 'content://test/$name',
            displayPath: name,
          );

  AgentProfile profile(String id, String? workspaceId) => AgentProfile(
        id: id,
        name: '档案 $id',
        emoji: '🤖',
        systemPrompt: '',
        tools: const {AgentToolGroup.fileEditor},
        workspaceId: workspaceId,
        workspaceName: workspaceId == null ? null : 'ws',
      );

  AgentTask task(
    String id,
    String profileId,
    String workspaceId, {
    AgentTaskStatus status = AgentTaskStatus.done,
  }) {
    final now = DateTime(2026, 11, 26);
    return AgentTask(
      id: id,
      profileId: profileId,
      title: '话题 $id',
      workspaceId: workspaceId,
      workspaceName: 'ws',
      status: status,
      mode: AgentSessionMode.values.first,
      createdAt: now,
      updatedAt: now,
    );
  }

  McpServer stdioServer(String id, String? workspaceId) => McpServer(
        id: id,
        name: 'server-$id',
        type: McpServerType.stdio,
        isActive: true,
        command: 'npx',
        workspaceId: workspaceId,
      );

  AgentProfile? profileById(ProviderContainer c, String id) =>
      c.read(agentProfilesProvider).where((p) => p.id == id).firstOrNull;

  McpServer? serverById(ProviderContainer c, String id) =>
      (c.read(mcpServersProvider).value ?? const <McpServer>[])
          .where((s) => s.id == id)
          .firstOrNull;

  group('workspaceUsageProvider', () {
    test('按 workspaceId 聚合档案 / 话题 / MCP 服务器引用', () async {
      final c = await makeContainer();
      final a = await openWorkspace(c, 'a');
      final b = await openWorkspace(c, 'b');

      await c.read(agentProfilesProvider.notifier).upsert(profile('p1', a.id));
      await c.read(agentProfilesProvider.notifier).upsert(profile('p2', a.id));
      await c.read(agentProfilesProvider.notifier).upsert(profile('p3', b.id));
      await c.read(agentTasksProvider.notifier).apply(task('t1', 'p1', a.id));
      await c.read(agentTasksProvider.notifier).apply(
            task('t2', 'p1', a.id, status: AgentTaskStatus.running),
          );
      await c.read(mcpServersProvider.notifier).add(stdioServer('m1', a.id));

      final usage = c.read(workspaceUsageProvider);

      final ua = usage[a.id]!;
      expect(ua.profileNames, unorderedEquals(['档案 p1', '档案 p2']));
      expect(ua.mcpServerNames, ['server-m1']);
      expect(ua.taskCount, 2);
      expect(ua.activeTaskCount, 1);
      expect(ua.isEmpty, isFalse);

      final ub = usage[b.id]!;
      expect(ub.profileNames, ['档案 p3']);
      expect(ub.mcpServerNames, isEmpty);
      expect(ub.taskCount, 0);
    });

    test('未被引用的工作区不在表里', () async {
      final c = await makeContainer();
      final lonely = await openWorkspace(c, 'lonely');
      expect(c.read(workspaceUsageProvider).containsKey(lonely.id), isFalse);
    });
  });

  group('WorkspaceRemoval.remove', () {
    test('移除后解绑档案、清空并停用 MCP 服务器，话题保留原 id', () async {
      final c = await makeContainer();
      final a = await openWorkspace(c, 'a');
      final b = await openWorkspace(c, 'b');

      await c.read(agentProfilesProvider.notifier).upsert(profile('p1', a.id));
      await c.read(agentProfilesProvider.notifier).upsert(profile('p2', b.id));
      await c.read(agentTasksProvider.notifier).apply(task('t1', 'p1', a.id));
      await c.read(mcpServersProvider.notifier).add(stdioServer('m1', a.id));
      await c.read(mcpServersProvider.notifier).add(stdioServer('m2', b.id));

      await c.read(workspaceRemovalProvider).remove(a.id);

      // 工作区列表里只剩 b。
      final remaining = await c.read(workspaceStoreProvider.future);
      expect(remaining.map((w) => w.id), [b.id]);

      // 引用 a 的档案被解绑，引用 b 的不动。
      expect(profileById(c, 'p1')?.workspaceId, isNull);
      expect(profileById(c, 'p1')?.workspaceName, isNull);
      expect(profileById(c, 'p2')?.workspaceId, b.id);

      // 引用 a 的 MCP 服务器清空运行环境并停用，引用 b 的不动。
      final m1 = serverById(c, 'm1')!;
      expect(m1.workspaceId, isNull);
      expect(m1.isActive, isFalse);
      final m2 = serverById(c, 'm2')!;
      expect(m2.workspaceId, b.id);
      expect(m2.isActive, isTrue);

      // 话题是历史记录，不改写。
      final t1 =
          c.read(agentTasksProvider).where((t) => t.id == 't1').firstOrNull;
      expect(t1?.workspaceId, a.id);

      // 移除后 a 不再出现在引用表里（档案 / 服务器已解绑，只剩话题历史）。
      final ua = c.read(workspaceUsageProvider)[a.id];
      expect(ua?.profileNames ?? const <String>[], isEmpty);
      expect(ua?.mcpServerNames ?? const <String>[], isEmpty);
    });

    test('解绑写穿到库：重建容器后档案仍是未绑定', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final first = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      first.read(agentProfilesProvider);
      await first.read(agentSeedProvider.future);
      final ws = await first.read(workspaceStoreProvider.notifier).open(
            name: 'a',
            backendType: WorkspaceBackendType.localSaf,
            root: 'content://test/a',
          );
      await first.read(agentProfilesProvider.notifier).upsert(profile('p1', ws.id));
      await first.read(mcpServersProvider.future);
      await first.read(workspaceRemovalProvider).remove(ws.id);
      first.dispose();

      final second = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(second.dispose);
      second.read(agentProfilesProvider);
      AgentProfile? p1;
      for (var i = 0; i < 200 && p1 == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        p1 = second
            .read(agentProfilesProvider)
            .where((p) => p.id == 'p1')
            .firstOrNull;
      }
      expect(p1, isNotNull);
      expect(p1!.workspaceId, isNull);
    });
  });

  group('WorkspaceRemoval.clearAll', () {
    test('清空全部工作区并解绑所有引用', () async {
      final c = await makeContainer();
      final a = await openWorkspace(c, 'a');
      final b = await openWorkspace(c, 'b');

      await c.read(agentProfilesProvider.notifier).upsert(profile('p1', a.id));
      await c.read(agentProfilesProvider.notifier).upsert(profile('p2', b.id));
      await c.read(agentProfilesProvider.notifier).upsert(profile('p3', null));
      await c.read(mcpServersProvider.notifier).add(stdioServer('m1', b.id));

      await c.read(workspaceRemovalProvider).clearAll();

      expect(await c.read(workspaceStoreProvider.future), isEmpty);
      expect(profileById(c, 'p1')?.workspaceId, isNull);
      expect(profileById(c, 'p2')?.workspaceId, isNull);
      expect(profileById(c, 'p3')?.workspaceId, isNull);
      expect(serverById(c, 'm1')?.workspaceId, isNull);
      expect(serverById(c, 'm1')?.isActive, isFalse);
    });

    test('列表为空时是空操作', () async {
      final c = await makeContainer();
      await c.read(mcpServersProvider.notifier).add(stdioServer('m1', 'ws-x'));

      await c.read(workspaceRemovalProvider).clearAll();

      // 没有任何工作区被清掉，就不应触碰引用了别的 id 的服务器。
      expect(serverById(c, 'm1')?.workspaceId, 'ws-x');
      expect(serverById(c, 'm1')?.isActive, isTrue);
    });
  });
}
