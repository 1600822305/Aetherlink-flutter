import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';

void main() {
  group('buildSentinelInput', () {
    test('wraps the command in a brace group with a trailing sentinel', () {
      final input = buildSentinelInput('ls -la', 'abc');
      expect(input, startsWith('{\nls -la\n}; printf'));
      expect(input, contains('__AETHER_DONE_abc_%s__'));
      expect(input, endsWith('"\$?"\n'));
    });

    test('keeps multi-line commands intact inside the group', () {
      final input = buildSentinelInput('cd /tmp\necho hi\n', 'n1');
      expect(input, startsWith('{\ncd /tmp\necho hi\n}; printf'));
    });

    test('splitStderr redirects stderr and replays it between markers', () {
      final input = buildSentinelInput('make', 'e1', splitStderr: true);
      expect(input, startsWith('{\nmake\n} 2>"/tmp/.aether_stderr_e1"'));
      expect(input, contains('__AETHER_ERR_e1__'));
      expect(input, contains('cat "/tmp/.aether_stderr_e1"'));
      expect(input, contains('rm -f "/tmp/.aether_stderr_e1"'));
      expect(input, endsWith('"\$__aec"\n'));
    });

    test('sentinel shares the command line (stdin-reading commands cannot '
        'swallow it as input)', () {
      final input = buildSentinelInput('cat > notes.txt', 'x1');
      // 哨兵必须在 `}` 同一行，由 shell 解析器一次读完；不能单独成行，
      // 否则会被 cat 当 stdin 写进文件。
      final lines = input.trimRight().split('\n');
      expect(lines.last, startsWith('}; printf'));
    });
  });

  group('matchSentinel', () {
    test('returns null while the command is still running', () {
      expect(matchSentinel('partial output...', 'abc'), isNull);
    });

    test('extracts output and exit code', () {
      final match = matchSentinel(
        'hello\nworld\n\n__AETHER_DONE_abc_0__\n',
        'abc',
      );
      expect(match, isNotNull);
      expect(match!.exitCode, 0);
      expect(match.output, 'hello\nworld');
    });

    test('parses non-zero and negative exit codes', () {
      expect(matchSentinel('__AETHER_DONE_x_127__', 'x')!.exitCode, 127);
      expect(matchSentinel('__AETHER_DONE_x_-9__', 'x')!.exitCode, -9);
    });

    test('ignores the echoed printf line (no real exit code)', () {
      // PTY 回显的是 printf 原文：哨兵字面量后面跟的是 %s__，不是数字。
      const echoed =
          "printf '\\n__AETHER_DONE_abc_%s__\\n' \"\$?\"\nrunning...";
      expect(matchSentinel(echoed, 'abc'), isNull);
    });

    test('does not match a different nonce', () {
      expect(matchSentinel('__AETHER_DONE_other_0__', 'abc'), isNull);
    });

    test('with command strips echoed input / sentinel / prompt lines', () {
      const raw =
          'echo "set OK"\r\n'
          "printf '\\n__AETHER_DONE_abc_%s__\\n' \"\$?\"\r\n"
          'set OK\r\n'
          '# \r\n'
          '__AETHER_DONE_abc_0__\r\n';
      final match = matchSentinel(raw, 'abc', command: 'echo "set OK"');
      expect(match!.exitCode, 0);
      expect(match.output.trim(), 'set OK');
    });

    test('strips echoed lines even with a colored PS1 prompt prefix', () {
      const raw =
          '\x1b[1;32m[demo]\x1b[0m:\x1b[1;34m/root\x1b[0m # ls\r\n'
          'a.txt\r\n'
          '\x1b[1;32m[demo]\x1b[0m:\x1b[1;34m/root\x1b[0m # \r\n'
          '__AETHER_DONE_n1_0__\r\n';
      final match = matchSentinel(raw, 'n1', command: 'ls');
      expect(match!.output.trim(), 'a.txt');
    });

    test('keeps real output that merely resembles a prompt', () {
      const raw = 'value: 42\r\n__AETHER_DONE_n2_0__\r\n';
      final match = matchSentinel(raw, 'n2', command: 'get-value');
      expect(match!.output.trim(), 'value: 42');
    });

    test('splitStderr: splits stdout / stderr around the ERR marker', () {
      const raw =
          'building...\r\n'
          '__AETHER_ERR_e1__\r\n'
          'warning: deprecated API\r\n'
          '\r\n__AETHER_DONE_e1_2__\r\n';
      final match = matchSentinel(raw, 'e1');
      expect(match!.exitCode, 2);
      expect(match.output.trim(), 'building...');
      expect(match.stderr, 'warning: deprecated API');
    });

    test('without ERR marker stderr is null (merged stream)', () {
      final match = matchSentinel('out\n__AETHER_DONE_x_0__', 'x');
      expect(match!.stderr, isNull);
    });
  });

  group('stripSessionEcho', () {
    test('strips multi-line command echoes', () {
      const cmd = 'cd /tmp\necho hi';
      const head = 'cd /tmp\r\necho hi\r\nhi\r\n';
      expect(stripSessionEcho(head, cmd, 'x').trim(), 'hi');
    });

    test('strips brace-group echoes with PS2 continuation prompts', () {
      const cmd = 'echo hi';
      const head =
          '{\r\n'
          '> echo hi\r\n'
          '> }; printf \'\\n__AETHER_DONE_x_%s__\\n\' "\$?"\r\n'
          'hi\r\n';
      expect(stripSessionEcho(head, cmd, 'x').trim(), 'hi');
    });
  });

  group('SentinelDisplayFilter', () {
    test('drops sentinel result and echoed printf lines, keeps output', () {
      final filter = SentinelDisplayFilter();
      final visible = filter.feed(
        '# echo hi\r\n'
        "printf '\\n__AETHER_DONE_abc_%s__\\n' \"\$?\"\r\n"
        'hi\r\n'
        '\r\n'
        '__AETHER_DONE_abc_0__\r\n'
        '# ',
      );
      expect(visible, '# echo hi\r\nhi\r\n\r\n# ');
    });

    test('handles a sentinel line split across chunks', () {
      final filter = SentinelDisplayFilter();
      final a = filter.feed('ok\r\n__AETHER_');
      final b = filter.feed('DONE_abc_0__\r\n# ');
      expect(a + b, 'ok\r\n# ');
    });

    test('passes through incomplete non-sentinel tails (prompt) at once', () {
      final filter = SentinelDisplayFilter();
      expect(filter.feed('hello\r\n# '), 'hello\r\n# ');
    });
  });

  group('buildProotGreeting', () {
    test('escapes single quotes in name and root', () {
      final greeting = buildProotGreeting(name: "it's", root: '/root');
      expect(greeting, contains(r"'\''"));
      expect(greeting, contains('clear'));
    });
  });

  group('buildExportCommand', () {
    test('empty map returns empty string', () {
      expect(buildExportCommand(const {}), isEmpty);
    });

    test('exports variables single-quoted, newline-terminated', () {
      expect(
        buildExportCommand(const {
          'WORKSPACE_ROOT': '/root/projects/demo',
          'WORKSPACE_NAME': 'demo',
        }),
        "export WORKSPACE_ROOT='/root/projects/demo' WORKSPACE_NAME='demo'\n",
      );
    });

    test('escapes embedded single quotes', () {
      expect(
        buildExportCommand(const {'WORKSPACE_NAME': "it's"}),
        "export WORKSPACE_NAME='it'\\''s'\n",
      );
    });
  });

  group('buildSessionEnvSetup（L2 语言级隔离，设计稿 §4 P5）', () {
    test('empty map returns empty string', () {
      expect(buildSessionEnvSetup(const {}), isEmpty);
    });

    test('without HOME behaves like buildExportCommand', () {
      expect(
        buildSessionEnvSetup(const {'WORKSPACE_NAME': 'demo'}),
        "export WORKSPACE_NAME='demo'\n",
      );
    });

    test('with HOME prepends mkdir -p for the isolated home dir', () {
      expect(
        buildSessionEnvSetup(const {
          'HOME': '/root/projects/demo/.home',
          'WORKSPACE_NAME': 'demo',
        }),
        "mkdir -p '/root/projects/demo/.home'\n"
        "export HOME='/root/projects/demo/.home' WORKSPACE_NAME='demo'\n",
      );
    });
  });

  group('looksLikeInteractivePrompt（卡交互检测）', () {
    test('y/n 确认与 yes/no 提示命中', () {
      expect(
        looksLikeInteractivePrompt('Do you want to continue? [Y/n]'),
        isTrue,
      );
      expect(looksLikeInteractivePrompt('Overwrite file? (y/n)'), isTrue);
      expect(
        looksLikeInteractivePrompt(
          'Are you sure you want to continue connecting (yes/no)',
        ),
        isTrue,
      );
    });

    test('密码 / 用户名 / token 输入提示命中', () {
      expect(
        looksLikeInteractivePrompt("Password for 'https://github.com':"),
        isTrue,
      );
      expect(looksLikeInteractivePrompt('Enter passphrase for key: '), isTrue);
      expect(looksLikeInteractivePrompt('Username:'), isTrue);
    });

    test('中文交互提示与行尾问号命中', () {
      expect(looksLikeInteractivePrompt('请输入要删除的分支名'), isTrue);
      expect(looksLikeInteractivePrompt('是否继续安装？'), isTrue);
      expect(
        looksLikeInteractivePrompt('Which package manager do you use?'),
        isTrue,
      );
    });

    test('带 ANSI 颜色的提示剥掉后命中', () {
      expect(
        looksLikeInteractivePrompt('\x1b[1;32mproceed?\x1b[0m [y/N]'),
        isTrue,
      );
    });

    test('普通输出 / 空输出不命中', () {
      expect(looksLikeInteractivePrompt('Compiling core module...'), isFalse);
      expect(looksLikeInteractivePrompt('Downloaded 42 packages'), isFalse);
      expect(looksLikeInteractivePrompt(''), isFalse);
      expect(looksLikeInteractivePrompt('\n\n  \n'), isFalse);
    });

    test('取最后一个非空行判定（前面的历史问句不算数）', () {
      expect(
        looksLikeInteractivePrompt('continue? [y/N]\ny\ninstalling deps...'),
        isFalse,
      );
    });

    test('REPL 提示符与菜单选择提示命中', () {
      expect(looksLikeInteractivePrompt('>>> '), isTrue);
      expect(looksLikeInteractivePrompt('... '), isTrue);
      expect(looksLikeInteractivePrompt('Enter your choice [1-3]:'), isTrue);
      expect(looksLikeInteractivePrompt('Select an option: '), isTrue);
      expect(looksLikeInteractivePrompt('--More--'), isTrue);
      expect(looksLikeInteractivePrompt('(END)'), isTrue);
    });

    test('按键继续 / 带默认值提示 / Enter …: 命中', () {
      expect(looksLikeInteractivePrompt('Press ENTER to continue'), isTrue);
      expect(looksLikeInteractivePrompt('Hit any key to abort'), isTrue);
      expect(looksLikeInteractivePrompt('Project name [my-app]:'), isTrue);
      expect(looksLikeInteractivePrompt('Port (8080): '), isTrue);
      expect(looksLikeInteractivePrompt('Enter the target branch: '), isTrue);
      expect(looksLikeInteractivePrompt('build finished in 3s'), isFalse);
      expect(looksLikeInteractivePrompt('[INFO] compiled 12 files'), isFalse);
    });
  });

  group('kAgentNonInteractiveEnv（非交互环境兜底）', () {
    test('覆盖 git 凭据/编辑器、pager 与 apt 前端', () {
      expect(kAgentNonInteractiveEnv['GIT_TERMINAL_PROMPT'], '0');
      expect(kAgentNonInteractiveEnv['GIT_EDITOR'], 'true');
      expect(kAgentNonInteractiveEnv['GIT_PAGER'], 'cat');
      expect(kAgentNonInteractiveEnv['PAGER'], 'cat');
      expect(kAgentNonInteractiveEnv['DEBIAN_FRONTEND'], 'noninteractive');
    });
  });
}
