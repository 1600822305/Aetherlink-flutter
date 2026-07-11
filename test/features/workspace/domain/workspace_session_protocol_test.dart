import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';

void main() {
  group('buildSentinelInput', () {
    test('appends printf sentinel after the command', () {
      final input = buildSentinelInput('ls -la', 'abc');
      expect(input, startsWith('ls -la\n'));
      expect(input, contains('__AETHER_DONE_abc_%s__'));
      expect(input, endsWith('"\$?"\n'));
    });

    test('keeps multi-line commands intact', () {
      final input = buildSentinelInput('cd /tmp\necho hi\n', 'n1');
      expect(input, startsWith('cd /tmp\necho hi\n'));
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
      const raw = 'echo "set OK"\r\n'
          "printf '\\n__AETHER_DONE_abc_%s__\\n' \"\$?\"\r\n"
          'set OK\r\n'
          '# \r\n'
          '__AETHER_DONE_abc_0__\r\n';
      final match = matchSentinel(raw, 'abc', command: 'echo "set OK"');
      expect(match!.exitCode, 0);
      expect(match.output.trim(), 'set OK');
    });

    test('strips echoed lines even with a colored PS1 prompt prefix', () {
      const raw = '\x1b[1;32m[demo]\x1b[0m:\x1b[1;34m/root\x1b[0m # ls\r\n'
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
  });

  group('stripSessionEcho', () {
    test('strips multi-line command echoes', () {
      const cmd = 'cd /tmp\necho hi';
      const head = 'cd /tmp\r\necho hi\r\nhi\r\n';
      expect(stripSessionEcho(head, cmd, 'x').trim(), 'hi');
    });
  });

  group('SentinelDisplayFilter', () {
    test('drops sentinel result and echoed printf lines, keeps output', () {
      final filter = SentinelDisplayFilter();
      final visible = filter.feed('# echo hi\r\n'
          "printf '\\n__AETHER_DONE_abc_%s__\\n' \"\$?\"\r\n"
          'hi\r\n'
          '\r\n'
          '__AETHER_DONE_abc_0__\r\n'
          '# ');
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
}
