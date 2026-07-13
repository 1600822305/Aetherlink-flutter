import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_diagnostics.dart';

void main() {
  group('diagnosticsCommandFor', () {
    test('pubspec.yaml → dart analyze', () {
      final d = diagnosticsCommandFor({'pubspec.yaml', 'lib', 'test'})!;
      expect(d.projectType, 'dart/flutter');
      expect(d.command, 'dart analyze');
    });

    test('tsconfig.json → tsc --noEmit', () {
      final d = diagnosticsCommandFor({'tsconfig.json', 'package.json'})!;
      expect(d.projectType, 'typescript');
      expect(d.command, contains('tsc --noEmit'));
    });

    test('go.mod → go vet', () {
      expect(diagnosticsCommandFor({'go.mod'})!.command, 'go vet ./...');
    });

    test('Cargo.toml → cargo check', () {
      expect(
        diagnosticsCommandFor({'Cargo.toml'})!.command,
        contains('cargo check'),
      );
    });

    test('pubspec 优先于 tsconfig（探测顺序稳定）', () {
      expect(
        diagnosticsCommandFor({'pubspec.yaml', 'tsconfig.json'})!.projectType,
        'dart/flutter',
      );
    });

    test('未识别项目返回 null', () {
      expect(diagnosticsCommandFor({'README.md', 'src'}), isNull);
    });
  });

  group('combineDiagnosticsOutput', () {
    test('合并 stdout/stderr，空段跳过', () {
      expect(combineDiagnosticsOutput('out\n', ''), 'out');
      expect(combineDiagnosticsOutput('', 'err'), 'err');
      expect(combineDiagnosticsOutput('out', 'err'), 'out\nerr');
    });

    test('超长截尾保留头部', () {
      final long = 'x' * (kMaxDiagnosticsChars + 100);
      final clipped = combineDiagnosticsOutput(long, '');
      expect(clipped.length, lessThan(long.length));
      expect(clipped, contains('…(输出过长已截断)'));
      expect(clipped.startsWith('x' * 100), isTrue);
    });
  });
}
