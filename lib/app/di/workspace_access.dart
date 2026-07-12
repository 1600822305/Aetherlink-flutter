import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

part 'workspace_access.g.dart';

/// App-level composition seam exposing the「最近打开」workspace list to other
/// features（import-boundary Rule：feature 之间不得直接 import 对方的
/// application——智能体的新建话题弹层要选工作区，经由这里取）。
@Riverpod(keepAlive: true)
List<Workspace> recentWorkspacesView(Ref ref) =>
    ref.watch(workspaceStoreProvider).value ?? const <Workspace>[];
