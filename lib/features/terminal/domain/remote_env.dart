// 远程工作区（SSH / Termux）环境探测与命令适配（纯 Dart，可单测）。
//
// 与内置终端的差别：内置终端的 rootfs 归 App 所有，可直接写配置文件；
// 远程环境归用户所有，这里只「探测 + 生成命令回放进终端」，让用户
// 全程看得到执行过程。探测走 WorkspaceBackend.exec 的静默通道。

import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_env_presets.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

/// 远程环境的包管理器。
enum RemotePackageManager { apk, apt, termuxPkg, dnf, pacman, zypper, none }

/// 远程环境画像：一次探测命令的解析结果。
class RemoteEnvInfo {
  const RemoteEnvInfo({
    required this.packageManager,
    this.isTermux = false,
    this.isRoot = false,
    this.hasSudo = false,
    this.osId = '',
    this.osCodename = '',
    this.arch = '',
  });

  final RemotePackageManager packageManager;

  /// 是否 Termux（`$TERMUX_VERSION` / `$PREFIX/bin/pkg`）。
  final bool isTermux;

  /// `id -u` == 0。
  final bool isRoot;

  /// 是否有 sudo 可用（非 root 时安装/写系统配置需要）。
  final bool hasSudo;

  /// /etc/os-release 的 ID（ubuntu / debian / alpine …）。
  final String osId;

  /// /etc/os-release 的 VERSION_CODENAME（noble / bookworm …）。
  final String osCodename;

  /// dpkg --print-architecture（arm64 / amd64 …，仅 apt 系有值）。
  final String arch;

  /// 非 root 且有 sudo 时给系统级命令加的前缀。
  String get sudoPrefix => !isRoot && hasSudo ? 'sudo ' : '';

  /// 环境的一句话描述（页面副标题用）。
  String get label {
    if (isTermux) return 'Termux（pkg）';
    return switch (packageManager) {
      RemotePackageManager.termuxPkg => 'Termux（pkg）',
      RemotePackageManager.apk => 'Alpine（apk）',
      RemotePackageManager.apt =>
        osId == 'ubuntu' ? 'Ubuntu（apt）' : '${osId.isEmpty ? 'Debian 系' : osId}（apt）',
      RemotePackageManager.dnf => '$osId（dnf/yum）',
      RemotePackageManager.pacman => '$osId（pacman）',
      RemotePackageManager.zypper => '$osId（zypper）',
      RemotePackageManager.none => '未识别的环境',
    };
  }
}

/// 一条探测命令拿全环境画像：包管理器、Termux、root/sudo、发行版、架构。
/// 输出为逐行标记（`PM xxx` / `ENV_TERMUX` / `IS_ROOT` / `HAS_SUDO` /
/// `OS_ID xxx` / `OS_CODENAME xxx` / `ARCH xxx`），由
/// [parseRemoteEnvProbe] 解析；结尾 `true` 保证整条命令 exit 0。
const String kRemoteEnvProbeCommand =
    r'if [ -n "$TERMUX_VERSION" ] || { [ -n "$PREFIX" ] && [ -x "$PREFIX/bin/pkg" ]; }; then echo ENV_TERMUX; fi; '
    r'for pm in apk apt-get dnf yum pacman zypper; do command -v "$pm" >/dev/null 2>&1 && echo "PM $pm"; done; '
    r'[ "$(id -u)" = 0 ] && echo IS_ROOT; '
    r'command -v sudo >/dev/null 2>&1 && echo HAS_SUDO; '
    r'if [ -r /etc/os-release ]; then . /etc/os-release; echo "OS_ID $ID"; echo "OS_CODENAME ${VERSION_CODENAME:-}"; fi; '
    r'command -v dpkg >/dev/null 2>&1 && echo "ARCH $(dpkg --print-architecture)"; '
    r'true';

/// 解析 [kRemoteEnvProbeCommand] 的输出。
RemoteEnvInfo parseRemoteEnvProbe(String stdout) {
  var isTermux = false;
  var isRoot = false;
  var hasSudo = false;
  var osId = '';
  var osCodename = '';
  var arch = '';
  final managers = <String>{};
  for (final raw in stdout.split('\n')) {
    final line = raw.trim();
    if (line == 'ENV_TERMUX') isTermux = true;
    if (line == 'IS_ROOT') isRoot = true;
    if (line == 'HAS_SUDO') hasSudo = true;
    if (line.startsWith('PM ')) managers.add(line.substring(3).trim());
    if (line.startsWith('OS_ID ')) osId = line.substring(6).trim();
    if (line.startsWith('OS_CODENAME ')) {
      osCodename = line.substring('OS_CODENAME '.length).trim();
    }
    if (line.startsWith('ARCH ')) arch = line.substring(5).trim();
  }
  final manager = isTermux
      ? RemotePackageManager.termuxPkg
      : managers.contains('apk')
          ? RemotePackageManager.apk
          : managers.contains('apt-get')
              ? RemotePackageManager.apt
              : managers.contains('dnf') || managers.contains('yum')
                  ? RemotePackageManager.dnf
                  : managers.contains('pacman')
                      ? RemotePackageManager.pacman
                      : managers.contains('zypper')
                          ? RemotePackageManager.zypper
                          : RemotePackageManager.none;
  return RemoteEnvInfo(
    packageManager: manager,
    isTermux: isTermux,
    isRoot: isRoot,
    hasSudo: hasSudo,
    osId: osId,
    osCodename: osCodename,
    arch: arch,
  );
}

/// Termux 的预设包分类（包名按 Termux 仓库适配；检测命令与内置终端
/// 共用 `command -v` 系写法，跨环境通用）。
List<TerminalEnvCategory> _termuxEnvCategories() => const [
      TerminalEnvCategory(
        id: 'python',
        name: 'Python',
        description: 'Python 3 运行时与包管理（pip 随 python 一起装）',
        packages: [
          TerminalEnvPackage(
            id: 'python3',
            name: 'Python 3',
            description: 'python3 解释器 + pip',
            checkCommand: 'command -v python3',
            packageName: 'python',
          ),
        ],
      ),
      TerminalEnvCategory(
        id: 'node',
        name: 'Node.js',
        description: 'Node.js 运行时与包管理（npm 随 nodejs 一起装）',
        packages: [
          TerminalEnvPackage(
            id: 'nodejs',
            name: 'Node.js',
            description: 'node 运行时 + npm',
            checkCommand: 'command -v node',
            packageName: 'nodejs',
          ),
        ],
      ),
      TerminalEnvCategory(
        id: 'vcs',
        name: 'Git / SSH',
        description: '版本控制与远程连接',
        packages: [
          TerminalEnvPackage(
            id: 'git',
            name: 'Git',
            description: '版本控制',
            checkCommand: 'command -v git',
            packageName: 'git',
          ),
          TerminalEnvPackage(
            id: 'ssh',
            name: 'SSH 客户端',
            description: 'ssh / scp / sshd',
            checkCommand: 'command -v ssh',
            packageName: 'openssh',
          ),
          TerminalEnvPackage(
            id: 'curl',
            name: 'curl',
            description: 'HTTP 下载工具',
            checkCommand: 'command -v curl',
            packageName: 'curl',
          ),
        ],
      ),
      TerminalEnvCategory(
        id: 'build',
        name: '构建工具',
        description: 'C/C++ 编译工具链（Termux 用 clang）',
        packages: [
          TerminalEnvPackage(
            id: 'build',
            name: 'clang + make',
            description: 'clang / make 等',
            checkCommand: 'command -v clang',
            packageName: 'clang make',
          ),
        ],
      ),
      TerminalEnvCategory(
        id: 'java',
        name: 'Java',
        description: 'OpenJDK 17',
        packages: [
          TerminalEnvPackage(
            id: 'jdk17',
            name: 'OpenJDK 17',
            description: 'Java 开发工具包',
            checkCommand: 'command -v java',
            packageName: 'openjdk-17',
          ),
        ],
      ),
      TerminalEnvCategory(
        id: 'go',
        name: 'Go',
        description: 'Go 语言工具链',
        packages: [
          TerminalEnvPackage(
            id: 'go',
            name: 'Go',
            description: 'go 编译器与工具',
            checkCommand: 'command -v go',
            packageName: 'golang',
          ),
        ],
      ),
      TerminalEnvCategory(
        id: 'rust',
        name: 'Rust',
        description: 'Rust 语言工具链',
        packages: [
          TerminalEnvPackage(
            id: 'rust',
            name: 'Rust',
            description: 'rustc + cargo',
            checkCommand: 'command -v rustc',
            packageName: 'rust',
          ),
        ],
      ),
    ];

/// dnf / pacman / zypper / 未识别环境：只做已装检测（包名未适配，
/// 不生成安装命令），复用 Ubuntu 表的检测命令即可。
List<TerminalEnvCategory> _detectOnlyCategories() =>
    envCategoriesFor(TerminalDistro.ubuntu);

/// 按远程环境返回预设包分类。
List<TerminalEnvCategory> remoteEnvCategoriesFor(RemoteEnvInfo env) {
  if (env.isTermux) return _termuxEnvCategories();
  return switch (env.packageManager) {
    RemotePackageManager.apk => envCategoriesFor(TerminalDistro.alpine),
    RemotePackageManager.apt => envCategoriesFor(TerminalDistro.ubuntu),
    _ => _detectOnlyCategories(),
  };
}

/// 是否能为该环境生成安装命令（false 时页面只做检测）。
bool remoteInstallSupported(RemoteEnvInfo env) =>
    env.isTermux ||
    env.packageManager == RemotePackageManager.apk ||
    env.packageManager == RemotePackageManager.apt;

/// 勾选包的安装命令；不支持的环境返回 null。
String? remoteInstallCommandFor(
  RemoteEnvInfo env,
  List<TerminalEnvPackage> packages,
) {
  if (packages.isEmpty) return null;
  final names = packages.map((p) => p.packageName).join(' ');
  if (env.isTermux) return 'pkg install -y $names';
  final sudo = env.sudoPrefix;
  return switch (env.packageManager) {
    RemotePackageManager.apk => '${sudo}apk add $names',
    RemotePackageManager.apt =>
      '${sudo}apt-get update && ${sudo}apt-get install -y $names',
    _ => null,
  };
}

/// Termux 主仓库镜像（sources.list 的 `deb <base> stable main`）。
const List<TerminalMirror> kTermuxMirrors = [
  TerminalMirror(
    id: 'official',
    name: '官方',
    baseUrl: 'https://packages.termux.dev/apt/termux-main',
  ),
  TerminalMirror(
    id: 'tuna',
    name: '清华 TUNA',
    baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main',
  ),
  TerminalMirror(
    id: 'aliyun',
    name: '阿里云',
    baseUrl: 'https://mirrors.aliyun.com/termux/termux-main',
  ),
  TerminalMirror(
    id: 'ustc',
    name: '中科大',
    baseUrl: 'https://mirrors.ustc.edu.cn/termux/apt/termux-main',
  ),
];

/// 按远程环境返回系统源可选镜像；不支持系统源切换时返回空表。
List<TerminalMirror> remoteSystemMirrorsFor(RemoteEnvInfo env) {
  if (env.isTermux) return kTermuxMirrors;
  return switch (env.packageManager) {
    RemotePackageManager.apk => kTerminalMirrors,
    RemotePackageManager.apt when env.osId == 'ubuntu' => kTerminalMirrors,
    _ => const [],
  };
}

/// 系统源切换命令（写配置 + 刷新索引），在终端里回放让用户看到全程；
/// 不支持的环境返回 null。
///
/// - Termux：写 `$PREFIX/etc/apt/sources.list`（无需 root）。
/// - Alpine：写 /etc/apk/repositories（分支号从 /etc/alpine-release 取）。
/// - Ubuntu：写 /etc/apt/sources.list（codename/arch 来自探测结果），
///   并把 deb822 的 ubuntu.sources 移开避免双源；Debian 等其它 apt 系
///   发行版风险高，不生成。
String? remoteSystemMirrorCommand(RemoteEnvInfo env, TerminalMirror mirror) {
  if (env.isTermux) {
    return 'mkdir -p "\$PREFIX/etc/apt" && '
        'echo "deb ${mirror.baseUrl} stable main" > "\$PREFIX/etc/apt/sources.list" && '
        'apt update';
  }
  final sudo = env.sudoPrefix;
  switch (env.packageManager) {
    case RemotePackageManager.apk:
      final base = mirror.baseUrl;
      return '${sudo}sh -c \'v=v\$(cut -d. -f1,2 /etc/alpine-release); '
          'printf "%s\\n%s\\n" "$base/\$v/main" "$base/\$v/community" '
          '> /etc/apk/repositories\' && ${sudo}apk update';
    case RemotePackageManager.apt:
      if (env.osId != 'ubuntu' || env.osCodename.isEmpty) return null;
      final sources = aptSourcesForSeries(
        mirror,
        env.osCodename,
        env.arch.isEmpty ? 'amd64' : env.arch,
      );
      final lines = sources.trimRight().split('\n');
      final printfArgs = lines.map((l) => '"$l"').join(' ');
      final fmt = List.filled(lines.length, '%s').join(r'\n');
      return '${sudo}sh -c \'[ -f /etc/apt/sources.list.d/ubuntu.sources ] && '
          'mv /etc/apt/sources.list.d/ubuntu.sources '
          '/etc/apt/sources.list.d/ubuntu.sources.bak; '
          'printf "$fmt\\n" $printfArgs > /etc/apt/sources.list\' && '
          '${sudo}apt-get update';
    default:
      return null;
  }
}
