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
}
