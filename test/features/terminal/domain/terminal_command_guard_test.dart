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

  group('isHighRiskCommand（预授权不可覆盖的高危档）', () {
    test('提权/换根、黑名单命中、递归强删 → true', () {
      expect(isHighRiskCommand('sudo apk add curl'), isTrue);
      expect(isHighRiskCommand('su -'), isTrue);
      expect(isHighRiskCommand('proot -0 sh'), isTrue);
      expect(isHighRiskCommand('rm -rf /'), isTrue);
      expect(isHighRiskCommand('rm -rf build'), isTrue);
      expect(isHighRiskCommand('rm --recursive --force node_modules'), isTrue);
      expect(isHighRiskCommand('dd if=/dev/zero of=/dev/sda'), isTrue);
    });

    test('普通写/执行命令与越界路径 → false', () {
      expect(isHighRiskCommand('npm install'), isFalse);
      expect(isHighRiskCommand('git commit -m x'), isFalse);
      expect(isHighRiskCommand('cat /etc/passwd'), isFalse);
      expect(isHighRiskCommand('cd ..'), isFalse);
      expect(isHighRiskCommand('rm file.txt'), isFalse);
      expect(isHighRiskCommand('echo hi > a.txt'), isFalse);
    });
  });

  group('evaluateCommandRisk（双作用域设计稿 §3.2）', () {
    const root = '/root/projects/demo';
    CommandRisk risk(String cmd) => evaluateCommandRisk(cmd, root: root);

    test('root 内只读命令 → safeInRoot', () {
      expect(risk('ls -la'), CommandRisk.safeInRoot);
      expect(risk('cat src/main.dart'), CommandRisk.safeInRoot);
      expect(risk('grep -rn TODO lib | head -20'), CommandRisk.safeInRoot);
      expect(risk('cat $root/pubspec.yaml'), CommandRisk.safeInRoot);
      expect(risk('pwd && ls'), CommandRisk.safeInRoot);
    });

    test('root 内写操作 → needsApproval', () {
      expect(risk('rm -rf build'), CommandRisk.needsApproval);
      expect(risk('npm install'), CommandRisk.needsApproval);
      expect(risk('echo hi > a.txt'), CommandRisk.needsApproval);
      expect(risk('git commit -m x'), CommandRisk.needsApproval);
    });

    test('白名单命令携带写/执行旗标 → needsApproval（find -delete 漏洞）', () {
      expect(risk('find . -name "*.log" -delete'), CommandRisk.needsApproval);
      expect(risk('find . -exec rm {} +'), CommandRisk.needsApproval);
      expect(risk('find . -ok rm {} +'), CommandRisk.needsApproval);
      expect(risk('sort -o out.txt in.txt'), CommandRisk.needsApproval);
      expect(risk('find . -name "*.dart"'), CommandRisk.safeInRoot);
    });

    test('绝对路径越出 root → escapesRoot', () {
      expect(risk('cat /etc/passwd'), CommandRisk.escapesRoot);
      expect(risk('ls /root'), CommandRisk.escapesRoot);
      expect(risk('cp a.txt /sdcard/'), CommandRisk.escapesRoot);
    });

    test('~ / \$HOME / cd 上溯 → escapesRoot', () {
      expect(risk('cat ~/.ssh/id_rsa'), CommandRisk.escapesRoot);
      expect(risk(r'ls $HOME'), CommandRisk.escapesRoot);
      expect(risk('cd ..'), CommandRisk.escapesRoot);
      expect(risk('cd'), CommandRisk.escapesRoot);
      expect(risk('cat ../other/secret.txt'), CommandRisk.escapesRoot);
    });

    test('提权 / 换根 → escapesRoot', () {
      expect(risk('sudo apk add curl'), CommandRisk.escapesRoot);
      expect(risk('su -'), CommandRisk.escapesRoot);
    });

    test('/dev/null 不算越界', () {
      expect(risk('grep -r foo . 2>/dev/null'), CommandRisk.needsApproval);
    });

    test('root=/（全机）时绝对路径不越界', () {
      expect(
        evaluateCommandRisk('cat /etc/passwd', root: '/'),
        CommandRisk.safeInRoot,
      );
    });
  });
}
