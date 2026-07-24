// 内置终端可选发行版（纯 Dart，可单测）。设计文档 §5/§6：Alpine（默认，
// musl，~3MB）之外提供 Ubuntu Base（glibc，~30MB）应对 musl 不兼容的场景
// （如个别 Python 轮子）。
//
// 与 terminal_mirrors.dart 的关系：镜像站点（官方/清华/阿里云/中科大）按
// id 复用，这里负责把「发行版 × 镜像 × 架构」翻译成 rootfs 直链、软件源
// 配置与一键装命令。

import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

enum TerminalDistro {
  alpine,
  ubuntu;

  static TerminalDistro fromName(String? name) {
    for (final d in TerminalDistro.values) {
      if (d.name == name) return d;
    }
    return TerminalDistro.alpine;
  }
}

/// Ubuntu Base 版本（升级时同步查镜像站 release 目录里的文件名）。
const String kUbuntuVersion = '24.04.3';

/// [kUbuntuVersion] 对应的系列代号（apt 源用）。
const String kUbuntuSeries = 'noble';

/// `24.04.3` → release 目录段 `24.04`。
String ubuntuRelease(String version) => version.split('.').take(2).join('.');

/// 各镜像站的 ubuntu-base 发布目录根（cdimage 镜像）。
const Map<String, String> _kUbuntuCdimageBases = {
  'official': 'https://cdimage.ubuntu.com/ubuntu-base/releases',
  'tuna': 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases',
  'aliyun': 'https://mirrors.aliyun.com/ubuntu-cdimage/ubuntu-base/releases',
  'ustc': 'https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases',
};

/// 各镜像站的 apt 源根。arm64/armhf 走 ubuntu-ports，amd64 走主档案库。
const Map<String, String> _kUbuntuPortsBases = {
  'official': 'http://ports.ubuntu.com/ubuntu-ports',
  'tuna': 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports',
  'aliyun': 'https://mirrors.aliyun.com/ubuntu-ports',
  'ustc': 'https://mirrors.ustc.edu.cn/ubuntu-ports',
};
const Map<String, String> _kUbuntuArchiveBases = {
  'official': 'http://archive.ubuntu.com/ubuntu',
  'tuna': 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu',
  'aliyun': 'https://mirrors.aliyun.com/ubuntu',
  'ustc': 'https://mirrors.ustc.edu.cn/ubuntu',
};

/// [mirror] 下 Ubuntu Base 某版本/架构（`arm64`/`armhf`/`amd64`）的直链。
Uri ubuntuRootfsUrlFor(TerminalMirror mirror, String version, String arch) {
  final base = _kUbuntuCdimageBases[mirror.id] ?? _kUbuntuCdimageBases['official']!;
  return Uri.parse(
    '$base/${ubuntuRelease(version)}/release/'
    'ubuntu-base-$version-base-$arch.tar.gz',
  );
}

/// [mirror] 对应的 /etc/apt/sources.list 内容（noble + updates + security）。
String aptSourcesFor(TerminalMirror mirror, String arch) =>
    aptSourcesForSeries(mirror, kUbuntuSeries, arch);

/// 某架构下的 Ubuntu apt 镜像列表（baseUrl 是真实生效的 apt 源根，
/// 供远程环境页展示；内置终端复用 [kTerminalMirrors] 另行映射）。
List<TerminalMirror> ubuntuAptMirrorsFor(String arch) {
  final bases = arch == 'amd64' ? _kUbuntuArchiveBases : _kUbuntuPortsBases;
  const names = {
    'official': '官方',
    'tuna': '清华 TUNA',
    'aliyun': '阿里云',
    'ustc': '中科大',
  };
  return [
    for (final entry in bases.entries)
      TerminalMirror(
        id: entry.key,
        name: names[entry.key] ?? entry.key,
        baseUrl: entry.value,
      ),
  ];
}

/// 任意系列代号（noble / jammy …）的 sources.list 内容——远程 Ubuntu
/// 环境的系列来自探测结果，不一定等于内置终端的 [kUbuntuSeries]。
String aptSourcesForSeries(TerminalMirror mirror, String series, String arch) {
  final bases = arch == 'amd64' ? _kUbuntuArchiveBases : _kUbuntuPortsBases;
  // 自定义源（id 不在内置表里）直接用其 baseUrl 作为 apt 仓库根。
  final base = bases[mirror.id] ?? mirror.baseUrl;
  const components = 'main restricted universe multiverse';
  return 'deb $base $series $components\n'
      'deb $base $series-updates $components\n'
      'deb $base $series-security $components\n';
}

/// 各发行版的常用环境一键装命令。
List<TerminalQuickInstall> quickInstallsFor(TerminalDistro distro) {
  switch (distro) {
    case TerminalDistro.alpine:
      return kTerminalQuickInstalls;
    case TerminalDistro.ubuntu:
      return const [
        TerminalQuickInstall(
          id: 'python',
          label: 'Python',
          description: 'python3 + pip',
          command: 'apt-get update && apt-get install -y python3 python3-pip',
        ),
        TerminalQuickInstall(
          id: 'node',
          label: 'Node.js',
          // noble 官方源的 nodejs 停在 18.x；走 NodeSource 装 22 LTS
          // （glibc rootfs 下官方二进制可直接跑），npm 随包自带。
          description: 'Node.js 22 LTS + npm（NodeSource 源）',
          command: 'apt-get update && '
              'apt-get install -y curl ca-certificates && '
              'curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && '
              'apt-get install -y nodejs',
        ),
        TerminalQuickInstall(
          id: 'git',
          label: 'Git',
          description: 'git + openssh 客户端',
          command: 'apt-get update && apt-get install -y git openssh-client',
        ),
        TerminalQuickInstall(
          id: 'build',
          label: '构建工具',
          description: 'gcc / make（build-essential）',
          command: 'apt-get update && apt-get install -y build-essential',
        ),
      ];
  }
}

/// 切换软件源后在终端里回放的刷新命令。
String refreshIndexCommandFor(TerminalDistro distro) => switch (distro) {
      TerminalDistro.alpine => 'apk update',
      TerminalDistro.ubuntu => 'apt-get update',
    };
