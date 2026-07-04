import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/terminal/domain/terminal_command_guard.dart';

void main() {
  test('拦截递归删除根目录 / 家目录', () {
    expect(blockedCommandReason('rm -rf /'), isNotNull);
    expect(blockedCommandReason('rm -fr /*'), isNotNull);
    expect(blockedCommandReason('rm -rf ~'), isNotNull);
    expect(blockedCommandReason(r'rm -rf $HOME'), isNotNull);
    expect(blockedCommandReason('rm -rf /root'), isNotNull);
    expect(blockedCommandReason('sudo rm --recursive --force /'), isNotNull);
  });

  test('放行普通 rm', () {
    expect(blockedCommandReason('rm -rf ./build'), isNull);
    expect(blockedCommandReason('rm -rf /tmp/cache'), isNull);
    expect(blockedCommandReason('rm file.txt'), isNull);
  });

  test('拦截格式化与写块设备', () {
    expect(blockedCommandReason('mkfs.ext4 /dev/sda1'), isNotNull);
    expect(blockedCommandReason('dd if=/dev/zero of=/dev/sda'), isNotNull);
    expect(blockedCommandReason('echo x > /dev/sda'), isNotNull);
  });

  test('放行普通 dd', () {
    expect(
      blockedCommandReason('dd if=/dev/urandom of=out.bin bs=1M count=1'),
      isNull,
    );
  });

  test('拦截 fork 炸弹与递归改根权限', () {
    expect(blockedCommandReason(':(){ :|:& };:'), isNotNull);
    expect(blockedCommandReason('chmod -R 777 /'), isNotNull);
  });

  test('放行日常命令', () {
    expect(blockedCommandReason('apk add python3'), isNull);
    expect(blockedCommandReason('ls -la /'), isNull);
    expect(blockedCommandReason('chmod 755 script.sh'), isNull);
  });
}
