// 终端环境管理页「环境 / 包」tab 的预设包定义（纯 Dart，可单测）。
// 按分类（Python / Node.js / Git·SSH / 构建工具 / Java / Go / Rust）组织，
// 每个包带「已装检测命令」与按发行版（Alpine/Ubuntu）适配的安装命令。

import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';

/// 一个可勾选安装的预设包。
class TerminalEnvPackage {
  const TerminalEnvPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.checkCommand,
    required this.packageName,
  });

  final String id;
  final String name;
  final String description;

  /// 已装检测（exit 0 视为已装），如 `command -v python3`。
  final String checkCommand;

  /// apk add / apt-get install 的包名（可含多个，空格分隔）。
  final String packageName;
}

/// 一个包分类。
class TerminalEnvCategory {
  const TerminalEnvCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.packages,
  });

  final String id;
  final String name;
  final String description;
  final List<TerminalEnvPackage> packages;
}

/// 按发行版返回预设包分类。
List<TerminalEnvCategory> envCategoriesFor(TerminalDistro distro) {
  final alpine = distro == TerminalDistro.alpine;
  return [
    TerminalEnvCategory(
      id: 'python',
      name: 'Python',
      description: 'Python 3 运行时与包管理',
      packages: [
        const TerminalEnvPackage(
          id: 'python3',
          name: 'Python 3',
          description: 'python3 解释器',
          checkCommand: 'command -v python3',
          packageName: 'python3',
        ),
        TerminalEnvPackage(
          id: 'pip',
          name: 'pip',
          description: 'Python 包管理器',
          checkCommand: 'command -v pip3 || command -v pip',
          packageName: alpine ? 'py3-pip' : 'python3-pip',
        ),
        if (!alpine)
          const TerminalEnvPackage(
            id: 'venv',
            name: 'venv',
            description: '虚拟环境支持',
            checkCommand: 'python3 -m venv --help',
            packageName: 'python3-venv',
          ),
      ],
    ),
    const TerminalEnvCategory(
      id: 'node',
      name: 'Node.js',
      description: 'Node.js 运行时与包管理',
      packages: [
        TerminalEnvPackage(
          id: 'nodejs',
          name: 'Node.js',
          description: 'node 运行时',
          checkCommand: 'command -v node',
          packageName: 'nodejs',
        ),
        TerminalEnvPackage(
          id: 'npm',
          name: 'npm',
          description: 'Node 包管理器',
          checkCommand: 'command -v npm',
          packageName: 'npm',
        ),
      ],
    ),
    const TerminalEnvCategory(
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
          description: 'ssh / scp',
          checkCommand: 'command -v ssh',
          packageName: 'openssh-client',
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
      description: 'C/C++ 编译工具链',
      packages: [
        TerminalEnvPackage(
          id: 'build',
          name: alpine ? 'build-base' : 'build-essential',
          description: 'gcc / make 等',
          checkCommand: 'command -v gcc',
          packageName: alpine ? 'build-base' : 'build-essential',
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
          packageName: alpine ? 'openjdk17' : 'openjdk-17-jdk',
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
          packageName: alpine ? 'go' : 'golang-go',
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
          packageName: alpine ? 'rust cargo' : 'rustc cargo',
        ),
      ],
    ),
  ];
}

/// 把勾选的包合成一条在终端里回放的安装命令。
String installCommandFor(
  TerminalDistro distro,
  List<TerminalEnvPackage> packages,
) {
  final names = packages.map((p) => p.packageName).join(' ');
  return switch (distro) {
    TerminalDistro.alpine => 'apk add $names',
    TerminalDistro.ubuntu => 'apt-get update && apt-get install -y $names',
  };
}

/// 把所有包的检测合成一条命令：每个已装的包输出一行 `PKG_OK <id>`。
/// 单次 proot 进程完成全部检测，避免逐包起进程。
String batchCheckCommandFor(List<TerminalEnvPackage> packages) {
  return packages
      .map((p) =>
          'if ( ${p.checkCommand} ) >/dev/null 2>&1; then echo "PKG_OK ${p.id}"; fi')
      .join('; ');
}

/// 解析 [batchCheckCommandFor] 的输出，返回已装包 id 集合。
Set<String> parseBatchCheckOutput(String stdout) {
  return stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('PKG_OK '))
      .map((line) => line.substring('PKG_OK '.length).trim())
      .where((id) => id.isNotEmpty)
      .toSet();
}
