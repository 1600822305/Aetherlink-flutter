import 'package:aetherlink_flutter/features/agent/domain/shell_command_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitShellSegments', () {
    test('按连接符与换行拆分', () {
      expect(
        splitShellSegments('cd src && ls -la; cat a.txt | grep foo').toList(),
        ['cd src', 'ls -la', 'cat a.txt', 'grep foo'],
      );
    });
  });

  group('shellCommandPrefix', () {
    test('词典命中取指定 token 数', () {
      expect(shellCommandPrefix('git status'), ['git', 'status']);
      expect(shellCommandPrefix('npm run dev'), ['npm', 'run', 'dev']);
      expect(shellCommandPrefix('flutter pub get'), ['flutter', 'pub', 'get']);
    });

    test('无命中默认取首词', () {
      expect(shellCommandPrefix('mytool build --fast'), ['mytool']);
    });

    test('旗标不计入 token', () {
      expect(shellCommandPrefix('ls -la /tmp'), ['ls']);
      expect(shellCommandPrefix('git --no-pager log'), ['git', 'log']);
    });

    test('跳过前导环境变量赋值', () {
      expect(shellCommandPrefix('FOO=1 BAR=2 npm run dev'),
          ['npm', 'run', 'dev']);
    });

    test('arity 超过实际 token 数时全取', () {
      expect(shellCommandPrefix('npm run'), ['npm', 'run']);
    });
  });

  group('terminalPermissionPatterns', () {
    test('每个子命令一条规范化 pattern', () {
      expect(
        terminalPermissionPatterns('git  status &&  npm   install'),
        ['git status', 'npm install'],
      );
    });

    test('命令替换退化为整条原文', () {
      expect(
        terminalPermissionPatterns(r'cat $(find / -name id_rsa)'),
        [r'cat $(find / -name id_rsa)'],
      );
      expect(terminalPermissionPatterns('echo `whoami`').length, 1);
    });

    test('eval 视为注入', () {
      expect(terminalPermissionPatterns(r'eval "$CMD"').length, 1);
    });

    test('空命令返回空', () {
      expect(terminalPermissionPatterns('   '), isEmpty);
    });
  });

  group('terminalAlwaysPatterns', () {
    test('生成命令头 + * 的授权建议并去重', () {
      expect(
        terminalAlwaysPatterns('git status && git diff && npm run dev'),
        ['git status *', 'git diff *', 'npm run dev *'],
      );
      expect(
        terminalAlwaysPatterns('ls -la && ls src'),
        ['ls *'],
      );
    });

    test('注入特征时不给宽泛建议', () {
      expect(terminalAlwaysPatterns(r'ls $(pwd)'), isEmpty);
    });
  });
}
