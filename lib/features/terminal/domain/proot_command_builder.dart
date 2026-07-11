// PRoot 启动命令拼装（纯 Dart，可单测）。见 docs/内置终端PRoot-设计文档.md §2.1。
//
// 只负责把「rootfs 在哪、proot/loader 在哪、要跑什么」翻译成可执行的
// argv + 环境变量；不碰 Process / 平台通道（那是 data 层
// proot_process_runner.dart 的事）。

/// 一次 PRoot 调用的完整描述：可执行文件、参数与宿主环境变量。
class ProotCommand {
  const ProotCommand({
    required this.executable,
    required this.arguments,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;

  /// 宿主侧环境变量（PROOT_TMP_DIR / PROOT_LOADER 等），guest 侧环境
  /// 由 argv 里的 `/usr/bin/env -i` 段控制。
  final Map<String, String> environment;
}

/// guest 内的默认 PATH / HOME 等（Alpine 布局）。
const List<String> kProotGuestEnv = [
  'HOME=/root',
  'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
  'TERM=xterm-256color',
  'LANG=C.UTF-8',
  'TMPDIR=/tmp',
];

class ProotCommandBuilder {
  const ProotCommandBuilder({
    required this.prootPath,
    required this.loaderPath,
    this.loader32Path,
    required this.rootfsPath,
    required this.tmpDirPath,
    this.extraBinds = const [],
  });

  /// jniLibs 里的 libproot.so 绝对路径。
  final String prootPath;

  /// jniLibs 里的 libproot_loader.so 绝对路径（PROOT_LOADER）。
  final String loaderPath;

  /// 64 位设备上运行 32 位二进制所需的 loader；32 位设备为 null。
  final String? loader32Path;

  /// 已解压落盘的 rootfs 目录。
  final String rootfsPath;

  /// PRoot 的临时目录（SELinux 禁止用 /tmp，必须是应用私有目录）。
  final String tmpDirPath;

  /// 附加绑定挂载（`宿主路径:guest路径`），如手机存储
  /// `/storage/emulated/0:/sdcard`。
  final List<String> extraBinds;

  /// 组装在 rootfs 里执行 [command] 的完整调用。[workingDirectory] 是 guest
  /// 侧路径（缺省 /root）。
  ProotCommand build({
    List<String> command = const ['/bin/sh', '-l'],
    String? workingDirectory,
  }) {
    return ProotCommand(
      executable: prootPath,
      arguments: [
        '--kill-on-exit',
        // Android 私有目录（f2fs/SELinux）不允许 link(2)，dpkg 备份
        // status-old / 替换文件时的硬链接会 EPERM；Termux 版 proot 的
        // link2symlink 扩展把 link() 模拟成符号链接，包管理器才能工作。
        '--link2symlink',
        '-r', rootfsPath,
        // 伪 root（uid 0）：apk add 等包管理操作需要。真实权限仍是应用 uid，
        // rootfs 外的系统一律碰不到。
        '-0',
        '-w', workingDirectory == null || workingDirectory.isEmpty
            ? '/root'
            : workingDirectory,
        '-b', '/dev',
        '-b', '/proc',
        '-b', '/sys',
        for (final bind in extraBinds) ...['-b', bind],
        '/usr/bin/env', '-i',
        ...kProotGuestEnv,
        ...command,
      ],
      environment: {
        'PROOT_TMP_DIR': tmpDirPath,
        'PROOT_LOADER': loaderPath,
        if (loader32Path != null) 'PROOT_LOADER_32': loader32Path!,
      },
    );
  }
}
