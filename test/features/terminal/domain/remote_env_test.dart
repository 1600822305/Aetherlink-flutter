import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/terminal/domain/remote_env.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_env_presets.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

void main() {
  group('parseRemoteEnvProbe', () {
    test('Termux 环境优先于 apt-get（Termux 里也有 apt）', () {
      final env = parseRemoteEnvProbe(
        'ENV_TERMUX\nPM apt-get\nOS_ID \nARCH aarch64\n',
      );
      expect(env.isTermux, isTrue);
      expect(env.packageManager, RemotePackageManager.termuxPkg);
      expect(env.isRoot, isFalse);
    });

    test('Alpine root 环境', () {
      final env = parseRemoteEnvProbe(
        'PM apk\nIS_ROOT\nOS_ID alpine\nOS_CODENAME \n',
      );
      expect(env.packageManager, RemotePackageManager.apk);
      expect(env.isRoot, isTrue);
      expect(env.hasSudo, isFalse);
      expect(env.sudoPrefix, isEmpty);
    });

    test('Ubuntu 非 root + sudo', () {
      final env = parseRemoteEnvProbe(
        'PM apt-get\nHAS_SUDO\nOS_ID ubuntu\nOS_CODENAME noble\nARCH arm64\n',
      );
      expect(env.packageManager, RemotePackageManager.apt);
      expect(env.osId, 'ubuntu');
      expect(env.osCodename, 'noble');
      expect(env.arch, 'arm64');
      expect(env.sudoPrefix, 'sudo ');
    });

    test('未识别环境', () {
      final env = parseRemoteEnvProbe('');
      expect(env.packageManager, RemotePackageManager.none);
      expect(remoteInstallSupported(env), isFalse);
      expect(remoteSystemMirrorsFor(env), isEmpty);
    });

    test('dnf 环境：检测可用但不生成安装命令', () {
      final env = parseRemoteEnvProbe('PM dnf\nOS_ID fedora\n');
      expect(env.packageManager, RemotePackageManager.dnf);
      expect(remoteInstallSupported(env), isFalse);
      expect(remoteInstallCommandFor(env, const []), isNull);
    });
  });

  group('remoteInstallCommandFor', () {
    const pkg = TerminalEnvPackage(
      id: 'git',
      name: 'Git',
      description: '',
      checkCommand: 'command -v git',
      packageName: 'git',
    );

    test('Termux 用 pkg install', () {
      final env = parseRemoteEnvProbe('ENV_TERMUX\nPM apt-get\n');
      expect(remoteInstallCommandFor(env, const [pkg]), 'pkg install -y git');
    });

    test('Alpine 非 root 带 sudo 前缀', () {
      final env = parseRemoteEnvProbe('PM apk\nHAS_SUDO\n');
      expect(remoteInstallCommandFor(env, const [pkg]), 'sudo apk add git');
    });

    test('Ubuntu root 不带 sudo', () {
      final env = parseRemoteEnvProbe(
        'PM apt-get\nIS_ROOT\nOS_ID ubuntu\nOS_CODENAME noble\n',
      );
      expect(
        remoteInstallCommandFor(env, const [pkg]),
        'apt-get update && apt-get install -y git',
      );
    });

    test('空列表返回 null', () {
      final env = parseRemoteEnvProbe('PM apk\n');
      expect(remoteInstallCommandFor(env, const []), isNull);
    });
  });

  group('remoteEnvCategoriesFor', () {
    test('Termux 包名按 Termux 仓库适配', () {
      final env = parseRemoteEnvProbe('ENV_TERMUX\n');
      final packages = [
        for (final c in remoteEnvCategoriesFor(env)) ...c.packages,
      ];
      final byId = {for (final p in packages) p.id: p.packageName};
      expect(byId['python3'], 'python');
      expect(byId['go'], 'golang');
      expect(byId['ssh'], 'openssh');
    });

    test('apk 环境复用 Alpine 表', () {
      final env = parseRemoteEnvProbe('PM apk\n');
      final packages = [
        for (final c in remoteEnvCategoriesFor(env)) ...c.packages,
      ];
      final byId = {for (final p in packages) p.id: p.packageName};
      expect(byId['pip'], 'py3-pip');
      expect(byId['build'], 'build-base');
    });
  });

  group('remoteSystemMirrorCommand', () {
    test('Termux 写 \$PREFIX/etc/apt/sources.list', () {
      final env = parseRemoteEnvProbe('ENV_TERMUX\n');
      final cmd = remoteSystemMirrorCommand(env, kTermuxMirrors[1])!;
      expect(cmd, contains(r'$PREFIX/etc/apt/sources.list'));
      expect(cmd, contains('mirrors.tuna.tsinghua.edu.cn/termux'));
      expect(cmd, contains('apt update'));
      expect(cmd, isNot(contains('sudo')));
    });

    test('Alpine 非 root 经 sudo 写 /etc/apk/repositories', () {
      final env = parseRemoteEnvProbe('PM apk\nHAS_SUDO\n');
      final cmd = remoteSystemMirrorCommand(env, kTerminalMirrors[1])!;
      expect(cmd, startsWith('sudo sh -c'));
      expect(cmd, contains('/etc/apk/repositories'));
      expect(cmd, contains('mirrors.tuna.tsinghua.edu.cn/alpine'));
      expect(cmd, contains('sudo apk update'));
    });

    test('Ubuntu 用探测到的 codename / arch 生成 sources.list', () {
      final env = parseRemoteEnvProbe(
        'PM apt-get\nIS_ROOT\nOS_ID ubuntu\nOS_CODENAME jammy\nARCH arm64\n',
      );
      final cmd = remoteSystemMirrorCommand(env, kTerminalMirrors[1])!;
      expect(cmd, contains('jammy'));
      expect(cmd, contains('ubuntu-ports'));
      expect(cmd, contains('/etc/apt/sources.list'));
      expect(cmd, contains('ubuntu.sources'));
      expect(cmd, isNot(contains('sudo')));
    });

    test('Ubuntu 镜像列表 baseUrl 是真实 apt 源根（区分 archive/ports）', () {
      final arm = parseRemoteEnvProbe(
        'PM apt-get\nOS_ID ubuntu\nOS_CODENAME noble\nARCH arm64\n',
      );
      expect(
        remoteSystemMirrorsFor(arm).map((m) => m.baseUrl),
        everyElement(contains('ubuntu-ports')),
      );
      final amd = parseRemoteEnvProbe(
        'PM apt-get\nOS_ID ubuntu\nOS_CODENAME noble\nARCH amd64\n',
      );
      expect(
        remoteSystemMirrorsFor(amd).map((m) => m.baseUrl),
        everyElement(isNot(contains('ports'))),
      );
    });

    test('Ubuntu 探测不到 codename 时不提供系统源', () {
      final env = parseRemoteEnvProbe('PM apt-get\nOS_ID ubuntu\n');
      expect(remoteSystemMirrorsFor(env), isEmpty);
    });

    test('Debian（非 ubuntu 的 apt 系）不生成系统源命令', () {
      final env = parseRemoteEnvProbe(
        'PM apt-get\nOS_ID debian\nOS_CODENAME bookworm\n',
      );
      expect(remoteSystemMirrorCommand(env, kTerminalMirrors[1]), isNull);
      expect(remoteSystemMirrorsFor(env), isEmpty);
    });
  });
}
