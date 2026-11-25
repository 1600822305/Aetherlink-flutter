// resolveAgentWorkspace（app/di/agent_workspace_access.dart）的绑定解析规则：
// - 绑定命中 → 返回该工作区；
// - 未绑定（null / 空串）且 allowFallback → 回退到当前工作区，再退到列表第一个；
// - 绑定了 id 但工作区已被移除 → 一律 null，不论 allowFallback
//  （避免智能体静默读写一个用户没选过的目录）；
// - allowFallback: false 时未绑定也返回 null（破坏性操作）。

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// 在 provider 里调用，拿到 resolveAgentWorkspace 需要的 Ref。
final _resolve = FutureProvider.autoDispose
    .family<String?, (String?, bool)>((ref, arg) async {
  final (workspaceId, allowFallback) = arg;
  final resolved = await resolveAgentWorkspace(
    ref,
    workspaceId,
    allowFallback: allowFallback,
  );
  return resolved?.$1.id;
});

void main() {
  late ProviderContainer c;
  late Workspace a;
  late Workspace b;

  setUp(() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    await c.read(workspaceStoreProvider.future);
    final store = c.read(workspaceStoreProvider.notifier);
    a = await store.open(
      name: 'a',
      backendType: WorkspaceBackendType.localSaf,
      root: 'content://test/a',
    );
    // b 后打开 → 排在列表第一个。
    b = await store.open(
      name: 'b',
      backendType: WorkspaceBackendType.localSaf,
      root: 'content://test/b',
    );
  });

  Future<String?> resolve(String? id, {bool allowFallback = true}) =>
      c.read(_resolve((id, allowFallback)).future);

  test('绑定命中时返回绑定的工作区', () async {
    c.read(currentWorkspaceProvider.notifier).open(b);
    expect(await resolve(a.id), a.id);
  });

  test('未绑定时回退到当前工作区', () async {
    c.read(currentWorkspaceProvider.notifier).open(a);
    expect(await resolve(null), a.id);
    expect(await resolve(''), a.id);
  });

  test('未绑定且没有当前工作区时回退到列表第一个', () async {
    expect(await resolve(null), b.id);
  });

  test('绑定的工作区已被移除时返回 null，不回退到当前工作区', () async {
    c.read(currentWorkspaceProvider.notifier).open(b);
    await c.read(workspaceStoreProvider.notifier).remove(a.id);

    expect(await resolve(a.id), isNull);
    expect(await resolve(a.id, allowFallback: false), isNull);
  });

  test('绑定了不存在的 id 时返回 null', () async {
    c.read(currentWorkspaceProvider.notifier).open(a);
    expect(await resolve('ws-gone'), isNull);
  });

  test('allowFallback: false 时未绑定也返回 null', () async {
    c.read(currentWorkspaceProvider.notifier).open(a);
    expect(await resolve(null, allowFallback: false), isNull);
  });

  test('列表为空时返回 null', () async {
    await c.read(workspaceStoreProvider.notifier).clear();
    expect(await resolve(null), isNull);
  });
}
