import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/data/proot_local_backend.dart';

part 'terminal_env_access.g.dart';

/// App 级组合接缝：把「关闭全部内置终端（PRoot）池化会话」暴露给
/// terminal feature（import-boundary Rule 3：feature 间不得直接 import
/// 对方的 application/data——清理内置终端环境前经由这里关会话）。
@Riverpod(keepAlive: true)
Future<void> Function() prootSessionsCloser(Ref ref) {
  return () => ref
      .read(workspaceSessionPoolManagerProvider)
      .closeBackends((b) => b is ProotLocalBackend);
}
