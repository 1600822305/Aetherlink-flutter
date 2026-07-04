// 内置终端引擎（PRoot + Alpine rootfs）安装与版本管理，对标
// PdfiumEngineManager 的「按需下载 + 直链可换 + 手动导入」骨架。
// 见 docs/内置终端PRoot-设计文档.md §2.2。
//
// rootfs 不随安装包内置（约 3~4MB 下载、解压后 ~10MB）；首次进入内置终端
// 工作区时经 terminal_setup_sheet 在这里下载安装，只装一次。

import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/terminal/data/proot_process_runner.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

/// rootfs 未安装时抛出；UI 捕获后弹 terminal_setup_sheet 引导安装。
class TerminalEngineMissingException implements Exception {
  const TerminalEngineMissingException();

  @override
  String toString() => '内置终端环境尚未安装';
}

class TerminalEngineManager {
  TerminalEngineManager._();

  static final TerminalEngineManager instance = TerminalEngineManager._();

  /// Alpine minirootfs 版本（升级时同步改 [defaultRootfsUrl] 的目录段）。
  static const String alpineVersion = '3.22.2';

  /// 当前设备对应的 Alpine 架构名；不支持的平台返回 null。
  static String? get rootfsArch => switch (Abi.current()) {
        Abi.androidArm64 => 'aarch64',
        Abi.androidArm => 'armv7',
        Abi.androidX64 => 'x86_64',
        _ => null,
      };

  /// 当前设备对应的 Ubuntu 架构名；不支持的平台返回 null。
  static String? get ubuntuArch => switch (Abi.current()) {
        Abi.androidArm64 => 'arm64',
        Abi.androidArm => 'armhf',
        Abi.androidX64 => 'amd64',
        _ => null,
      };

  /// 官方 CDN 直链（安装面板里可替换为网盘等镜像）。
  static Uri? get defaultRootfsUrl => rootfsUrlForMirror(kTerminalMirrors.first);

  /// [mirror] 下当前设备架构、[distro] 发行版的 rootfs 直链；不支持的架构
  /// 返回 null。
  static Uri? rootfsUrlForMirror(
    TerminalMirror mirror, {
    TerminalDistro distro = TerminalDistro.alpine,
  }) {
    switch (distro) {
      case TerminalDistro.alpine:
        final arch = rootfsArch;
        if (arch == null) return null;
        return rootfsUrlFor(mirror, alpineVersion, arch);
      case TerminalDistro.ubuntu:
        final arch = ubuntuArch;
        if (arch == null) return null;
        return ubuntuRootfsUrlFor(mirror, kUbuntuVersion, arch);
    }
  }

  final ProotProcessRunner _runner = const ProotProcessRunner();

  /// 引擎根目录：<应用支持目录>/terminal。
  Future<String> baseDirPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'terminal');
  }

  /// 解压落盘的 rootfs 目录（proot -r 指向这里）。
  Future<String> rootfsPath() async => p.join(await baseDirPath(), 'rootfs');

  /// PRoot 的临时目录（PROOT_TMP_DIR，SELinux 禁止用 /tmp）。
  Future<String> tmpDirPath() async {
    final path = p.join(await baseDirPath(), 'tmp');
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<String> _markerPath() async =>
      p.join(await baseDirPath(), '.setup_done');

  /// rootfs 是否已完整安装（解压完成并写入标记）。
  Future<bool> isInstalled() async => File(await _markerPath()).exists();

  /// 已安装的发行版；未安装返回 null。旧版标记只写了 Alpine 版本号（无
  /// 发行版段），视为 Alpine。
  Future<TerminalDistro?> installedDistro() async {
    final marker = File(await _markerPath());
    if (!await marker.exists()) return null;
    final content = (await marker.readAsString()).trim();
    final parts = content.split(' ');
    if (parts.length < 2) return TerminalDistro.alpine;
    return TerminalDistro.fromName(parts.first);
  }

  /// 手机存储的宿主路径（proot 绑定挂载到 guest 的 /sdcard）。
  static const String sdcardHostPath = '/storage/emulated/0';

  Future<String> _permAskedFlagPath() async =>
      p.join(await baseDirPath(), '.storage_perm_asked');

  /// 是否已经自动弹过「所有文件访问」授权（只打扰一次，拒绝后不再弹）。
  Future<bool> storagePermissionAsked() async =>
      File(await _permAskedFlagPath()).exists();

  Future<void> markStoragePermissionAsked() async {
    final flag = File(await _permAskedFlagPath());
    await flag.parent.create(recursive: true);
    await flag.writeAsString('');
  }

  /// 未安装时抛 [TerminalEngineMissingException]。
  Future<void> ensureInstalled() async {
    if (!await isInstalled()) throw const TerminalEngineMissingException();
  }

  /// 从 [url]（缺省官方 CDN）下载 rootfs 并安装，[onProgress] 报告
  /// (已收字节, 总字节，未知时为 -1)。
  Future<void> download({
    Uri? url,
    TerminalDistro distro = TerminalDistro.alpine,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final target = url ?? defaultRootfsUrl;
    if (target == null) {
      throw UnsupportedError('当前设备架构没有可用的 rootfs 预编译包');
    }
    final archivePath = p.join(await baseDirPath(), 'rootfs.tar.gz');
    await File(archivePath).parent.create(recursive: true);
    try {
      await Dio().download(
        target.toString(),
        archivePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
      await installFromFile(archivePath, distro: distro);
    } finally {
      final archive = File(archivePath);
      if (await archive.exists()) await archive.delete();
    }
  }

  /// 从本地 tar.gz 安装（手动导入：群里 / 云盘分发的 rootfs 包）。
  Future<void> installFromFile(
    String sourcePath, {
    TerminalDistro distro = TerminalDistro.alpine,
  }) async {
    final rootfs = await rootfsPath();
    // 重装：清掉旧 rootfs，避免新旧文件混杂。
    final marker = File(await _markerPath());
    if (await marker.exists()) await marker.delete();
    final rootfsDir = Directory(rootfs);
    if (await rootfsDir.exists()) await rootfsDir.delete(recursive: true);

    await _runner.extractTarGz(archivePath: sourcePath, destPath: rootfs);
    // 验证解压产物确实是对应发行版的 rootfs。
    final probe = switch (distro) {
      TerminalDistro.alpine => p.join(rootfs, 'bin', 'busybox'),
      TerminalDistro.ubuntu => p.join(rootfs, 'usr', 'bin', 'dpkg'),
    };
    if (!await File(probe).exists()) {
      await rootfsDir.delete(recursive: true);
      final name = distro == TerminalDistro.alpine ? 'Alpine' : 'Ubuntu Base';
      throw FormatException('压缩包不是有效的 $name rootfs');
    }
    // rootfs 自带的 resolv.conf 是空的（或指向 systemd 的悬空链接）；写公共
    // DNS，包管理/联网才能解析域名。
    final resolv = File(p.join(rootfs, 'etc', 'resolv.conf'));
    if (await resolv.exists()) await resolv.delete();
    await resolv.parent.create(recursive: true);
    await resolv.writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
    final version = distro == TerminalDistro.alpine
        ? alpineVersion
        : kUbuntuVersion;
    await marker.writeAsString('${distro.name} $version');
  }

  /// 把 rootfs 内的软件源切到 [mirror]：Alpine 写 /etc/apk/repositories
  /// （main + community），Ubuntu 写 /etc/apt/sources.list（并清掉 deb822 默认
  /// 源避免重复）。要求 rootfs 已安装。
  Future<void> setPackageMirror(TerminalMirror mirror) async {
    await ensureInstalled();
    final rootfs = await rootfsPath();
    final distro = await installedDistro() ?? TerminalDistro.alpine;
    switch (distro) {
      case TerminalDistro.alpine:
        final repositories =
            File(p.join(rootfs, 'etc', 'apk', 'repositories'));
        await repositories.parent.create(recursive: true);
        await repositories.writeAsString(
          apkRepositoriesFor(mirror, alpineVersion),
        );
      case TerminalDistro.ubuntu:
        final sources = File(p.join(rootfs, 'etc', 'apt', 'sources.list'));
        await sources.parent.create(recursive: true);
        await sources.writeAsString(
          aptSourcesFor(mirror, ubuntuArch ?? 'arm64'),
        );
        final deb822 = File(
          p.join(rootfs, 'etc', 'apt', 'sources.list.d', 'ubuntu.sources'),
        );
        if (await deb822.exists()) await deb822.writeAsString('');
    }
  }

  /// 卸载（清空 rootfs 与标记），设置页「释放空间」用。
  Future<void> uninstall() async {
    final base = Directory(await baseDirPath());
    if (await base.exists()) await base.delete(recursive: true);
  }
}
