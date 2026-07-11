// Alpine 镜像源与常用环境一键装的静态定义（纯 Dart，可单测）。
// 设计文档 §4 P2：apk 源选择（国内镜像）、常用环境一键装（python / node / git）。
//
// 同一个镜像 base 同时用于两处：
// · rootfs 下载直链（terminal_setup_sheet 的镜像选择）
// · rootfs 内 /etc/apk/repositories（apk add 走同一镜像）

/// 一个 Alpine 镜像站点。[baseUrl] 是 Alpine 仓库根（不带版本分支、无尾斜杠）。
class TerminalMirror {
  const TerminalMirror({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

  final String id;
  final String name;
  final String baseUrl;
}

/// 可选镜像列表；第一个是官方 CDN（默认）。
const List<TerminalMirror> kTerminalMirrors = [
  TerminalMirror(
    id: 'official',
    name: '官方 CDN',
    baseUrl: 'https://dl-cdn.alpinelinux.org/alpine',
  ),
  TerminalMirror(
    id: 'tuna',
    name: '清华 TUNA',
    baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/alpine',
  ),
  TerminalMirror(
    id: 'aliyun',
    name: '阿里云',
    baseUrl: 'https://mirrors.aliyun.com/alpine',
  ),
  TerminalMirror(
    id: 'ustc',
    name: '中科大',
    baseUrl: 'https://mirrors.ustc.edu.cn/alpine',
  ),
];

/// `3.22.2` → 分支目录 `v3.22`。
String alpineBranch(String version) =>
    'v${version.split('.').take(2).join('.')}';

/// [mirror] 下某版本/架构的 minirootfs 下载直链。
Uri rootfsUrlFor(TerminalMirror mirror, String version, String arch) =>
    Uri.parse(
      '${mirror.baseUrl}/${alpineBranch(version)}/releases/$arch/'
      'alpine-minirootfs-$version-$arch.tar.gz',
    );

/// [mirror] 对应的 /etc/apk/repositories 内容（main + community）。
String apkRepositoriesFor(TerminalMirror mirror, String version) {
  final branch = alpineBranch(version);
  return '${mirror.baseUrl}/$branch/main\n'
      '${mirror.baseUrl}/$branch/community\n';
}

/// pip 可选镜像（index-url）；第一个是官方（默认）。
const List<TerminalMirror> kPipMirrors = [
  TerminalMirror(
    id: 'official',
    name: '官方 PyPI',
    baseUrl: 'https://pypi.org/simple',
  ),
  TerminalMirror(
    id: 'tuna',
    name: '清华 TUNA',
    baseUrl: 'https://pypi.tuna.tsinghua.edu.cn/simple',
  ),
  TerminalMirror(
    id: 'aliyun',
    name: '阿里云',
    baseUrl: 'https://mirrors.aliyun.com/pypi/simple/',
  ),
  TerminalMirror(
    id: 'ustc',
    name: '中科大',
    baseUrl: 'https://pypi.mirrors.ustc.edu.cn/simple/',
  ),
];

/// npm 可选镜像（registry）；第一个是官方（默认）。
const List<TerminalMirror> kNpmMirrors = [
  TerminalMirror(
    id: 'official',
    name: '官方 npm',
    baseUrl: 'https://registry.npmjs.org/',
  ),
  TerminalMirror(
    id: 'npmmirror',
    name: '淘宝 npmmirror',
    baseUrl: 'https://registry.npmmirror.com/',
  ),
  TerminalMirror(
    id: 'tencent',
    name: '腾讯云',
    baseUrl: 'https://mirrors.cloud.tencent.com/npm/',
  ),
  TerminalMirror(
    id: 'huawei',
    name: '华为云',
    baseUrl: 'https://repo.huaweicloud.com/repository/npm/',
  ),
];

/// 把 pip index-url 持久化写进 rootfs 的命令（~/.config/pip/pip.conf）。
String pipMirrorCommand(TerminalMirror mirror) =>
    'mkdir -p ~/.config/pip && '
    "printf '[global]\\nindex-url = %s\\n' '${mirror.baseUrl}'"
    ' > ~/.config/pip/pip.conf';

/// 把 npm registry 持久化写进 rootfs 的命令。
String npmMirrorCommand(TerminalMirror mirror) =>
    'npm config set registry ${mirror.baseUrl}';

/// 常用环境一键装：在交互式终端里回放的 apk 命令。
class TerminalQuickInstall {
  const TerminalQuickInstall({
    required this.id,
    required this.label,
    required this.description,
    required this.command,
  });

  final String id;
  final String label;
  final String description;
  final String command;
}

const List<TerminalQuickInstall> kTerminalQuickInstalls = [
  TerminalQuickInstall(
    id: 'python',
    label: 'Python',
    description: 'python3 + pip',
    command: 'apk add python3 py3-pip',
  ),
  TerminalQuickInstall(
    id: 'node',
    label: 'Node.js',
    description: 'nodejs + npm',
    command: 'apk add nodejs npm',
  ),
  TerminalQuickInstall(
    id: 'git',
    label: 'Git',
    description: 'git + openssh 客户端',
    command: 'apk add git openssh-client',
  ),
  TerminalQuickInstall(
    id: 'build',
    label: '构建工具',
    description: 'gcc / make / musl-dev',
    command: 'apk add build-base',
  ),
];
