import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

void main() {
  const tuna = TerminalMirror(
    id: 'tuna',
    name: '清华 TUNA',
    baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/alpine',
  );

  test('alpineBranch 取主次版本', () {
    expect(alpineBranch('3.22.2'), 'v3.22');
    expect(alpineBranch('3.9.0'), 'v3.9');
  });

  test('rootfsUrlFor 拼出 minirootfs 直链', () {
    expect(
      rootfsUrlFor(tuna, '3.22.2', 'aarch64').toString(),
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/releases/aarch64/'
      'alpine-minirootfs-3.22.2-aarch64.tar.gz',
    );
  });

  test('apkRepositoriesFor 含 main 与 community', () {
    expect(
      apkRepositoriesFor(tuna, '3.22.2'),
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/main\n'
      'https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/community\n',
    );
  });

  test('镜像列表首个为官方 CDN 且 id 唯一', () {
    expect(kTerminalMirrors.first.id, 'official');
    final ids = kTerminalMirrors.map((m) => m.id).toSet();
    expect(ids.length, kTerminalMirrors.length);
  });
}
