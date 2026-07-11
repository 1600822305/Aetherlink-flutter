// 在 rootfs 里静默执行一条命令并拿到输出（无 PTY、不进终端界面）。
// 供环境管理页做「包已装检测」等只读探测；与 workspace 的
// ProotLocalBackend.exec 同一条 proot 通道，但不依赖 workspace 层。

import 'dart:io';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/data/proot_process_runner.dart';
import 'package:aetherlink_flutter/features/terminal/domain/proot_command_builder.dart';

class TerminalSilentExec {
  const TerminalSilentExec();

  /// 执行 [command]（`/bin/sh -lc`），返回执行结果；rootfs 未安装时抛
  /// [TerminalEngineMissingException]。
  Future<ProotExecResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final engine = TerminalEngineManager.instance;
    await engine.ensureInstalled();
    const runner = ProotProcessRunner();
    final libDir = await runner.nativeLibDir();
    final loader32 = File('$libDir/libproot_loader32.so');
    final builder = ProotCommandBuilder(
      prootPath: '$libDir/libproot.so',
      loaderPath: '$libDir/libproot_loader.so',
      loader32Path: loader32.existsSync() ? loader32.path : null,
      rootfsPath: await engine.rootfsPath(),
      tmpDirPath: await engine.tmpDirPath(),
    );
    return runner.run(
      builder.build(command: ['/bin/sh', '-lc', command]),
      timeout: timeout,
    );
  }
}
