import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/terminal/domain/proot_command_builder.dart';

void main() {
  const builder = ProotCommandBuilder(
    prootPath: '/data/app/lib/arm64/libproot.so',
    loaderPath: '/data/app/lib/arm64/libproot_loader.so',
    loader32Path: '/data/app/lib/arm64/libproot_loader32.so',
    rootfsPath: '/data/user/0/app/files/terminal/rootfs',
    tmpDirPath: '/data/user/0/app/files/terminal/tmp',
  );

  group('ProotCommandBuilder.build', () {
    test('默认组装交互式登录 shell', () {
      final cmd = builder.build();

      expect(cmd.executable, '/data/app/lib/arm64/libproot.so');
      expect(cmd.arguments.first, '--kill-on-exit');
      // dpkg 等包管理器靠硬链接做备份，Android 下必须由 proot 模拟。
      expect(cmd.arguments, contains('--link2symlink'));
      expect(cmd.arguments, containsAllInOrder([
        '-r', '/data/user/0/app/files/terminal/rootfs',
        '-0',
        '-w', '/root',
      ]));
      // /dev /proc /sys 三个挂载点。
      expect(
        cmd.arguments.where((a) => a == '-b').length,
        3,
      );
      // guest 环境经 env -i 重置后注入。
      final envIdx = cmd.arguments.indexOf('/usr/bin/env');
      expect(envIdx, isNot(-1));
      expect(cmd.arguments[envIdx + 1], '-i');
      expect(cmd.arguments, containsAll(kProotGuestEnv));
      // 缺省命令：登录 shell。
      expect(cmd.arguments.sublist(cmd.arguments.length - 2), [
        '/bin/sh',
        '-l',
      ]);
    });

    test('宿主环境变量指向 loader 与私有 tmp 目录', () {
      final cmd = builder.build();
      expect(cmd.environment, {
        'PROOT_TMP_DIR': '/data/user/0/app/files/terminal/tmp',
        'PROOT_LOADER': '/data/app/lib/arm64/libproot_loader.so',
        'PROOT_LOADER_32': '/data/app/lib/arm64/libproot_loader32.so',
      });
    });

    test('32 位设备没有 loader32 时不注入 PROOT_LOADER_32', () {
      const b32 = ProotCommandBuilder(
        prootPath: '/lib/libproot.so',
        loaderPath: '/lib/libproot_loader.so',
        rootfsPath: '/rootfs',
        tmpDirPath: '/tmp-dir',
      );
      expect(b32.build().environment.containsKey('PROOT_LOADER_32'), isFalse);
    });

    test('自定义命令与工作目录', () {
      final cmd = builder.build(
        command: ['/bin/sh', '-lc', 'apk update'],
        workingDirectory: '/root/project',
      );
      expect(cmd.arguments, containsAllInOrder(['-w', '/root/project']));
      expect(cmd.arguments.sublist(cmd.arguments.length - 3), [
        '/bin/sh',
        '-lc',
        'apk update',
      ]);
    });

    test('extraBinds 追加绑定挂载（手机存储 /sdcard）', () {
      const withSdcard = ProotCommandBuilder(
        prootPath: '/lib/libproot.so',
        loaderPath: '/lib/libproot_loader.so',
        rootfsPath: '/rootfs',
        tmpDirPath: '/tmp-dir',
        extraBinds: ['/storage/emulated/0:/sdcard'],
      );
      final cmd = withSdcard.build();
      expect(
        cmd.arguments,
        containsAllInOrder(['-b', '/storage/emulated/0:/sdcard']),
      );
      expect(cmd.arguments.where((a) => a == '-b').length, 4);
    });

    test('空工作目录回退到 /root', () {
      final cmd = builder.build(workingDirectory: '');
      expect(cmd.arguments, containsAllInOrder(['-w', '/root']));
    });
  });
}
