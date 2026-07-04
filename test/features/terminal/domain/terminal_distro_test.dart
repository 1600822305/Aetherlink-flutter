import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/terminal/domain/terminal_distro.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

void main() {
  const tuna = TerminalMirror(
    id: 'tuna',
    name: '清华 TUNA',
    baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/alpine',
  );

  test('ubuntuRelease 取前两段', () {
    expect(ubuntuRelease('24.04.3'), '24.04');
  });

  test('ubuntuRootfsUrlFor 生成镜像直链', () {
    expect(
      ubuntuRootfsUrlFor(tuna, '24.04.3', 'arm64').toString(),
      'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/'
      'releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz',
    );
  });

  test('ubuntuRootfsUrlFor 未知镜像回退官方', () {
    const unknown = TerminalMirror(id: 'x', name: 'x', baseUrl: 'x');
    expect(
      ubuntuRootfsUrlFor(unknown, '24.04.3', 'arm64').toString(),
      startsWith('https://cdimage.ubuntu.com/ubuntu-base/releases/'),
    );
  });

  test('aptSourcesFor arm64 走 ubuntu-ports 且含三条源', () {
    final sources = aptSourcesFor(tuna, 'arm64');
    expect(
      sources,
      contains(
        'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports noble '
        'main restricted universe multiverse',
      ),
    );
    expect(sources, contains('noble-updates'));
    expect(sources, contains('noble-security'));
  });

  test('aptSourcesFor amd64 走主档案库', () {
    expect(
      aptSourcesFor(tuna, 'amd64'),
      contains('deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu noble '),
    );
  });

  test('quickInstallsFor 按发行版给出 apk/apt 命令', () {
    expect(
      quickInstallsFor(TerminalDistro.alpine).first.command,
      startsWith('apk add'),
    );
    expect(
      quickInstallsFor(TerminalDistro.ubuntu).first.command,
      contains('apt-get install -y'),
    );
  });

  test('refreshIndexCommandFor', () {
    expect(refreshIndexCommandFor(TerminalDistro.alpine), 'apk update');
    expect(refreshIndexCommandFor(TerminalDistro.ubuntu), 'apt-get update');
  });

  test('fromName 未知值回退 alpine', () {
    expect(TerminalDistro.fromName('ubuntu'), TerminalDistro.ubuntu);
    expect(TerminalDistro.fromName('centos'), TerminalDistro.alpine);
    expect(TerminalDistro.fromName(null), TerminalDistro.alpine);
  });
}
