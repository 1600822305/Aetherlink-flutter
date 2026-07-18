import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/permission_request.dart';

void main() {
  group('fileEditorPermissionPatterns', () {
    test('collects path arguments', () {
      expect(
        fileEditorPermissionPatterns({
          'path': '/ws/src/main.dart',
          'content': 'x',
        }),
        ['/ws/src/main.dart'],
      );
      expect(
        fileEditorPermissionPatterns({
          'source_path': '/ws/a.txt',
          'destination_path': '/ws/b.txt',
        }),
        ['/ws/a.txt', '/ws/b.txt'],
      );
    });

    test('deduplicates and skips empty values', () {
      expect(
        fileEditorPermissionPatterns({
          'path': '/ws/a.txt',
          'source_path': '/ws/a.txt',
          'destination_path': '  ',
        }),
        ['/ws/a.txt'],
      );
    });

    test('falls back to * when no path argument present', () {
      expect(fileEditorPermissionPatterns({'name': 'x'}), ['*']);
    });
  });

  group('terminalCommandText', () {
    test('terminal_execute reads command', () {
      expect(
        terminalCommandText('terminal_execute', {'command': 'git status'}),
        'git status',
      );
    });

    test('terminal_session reads input', () {
      expect(
        terminalCommandText('terminal_session', {'input': 'npm run dev'}),
        'npm run dev',
      );
    });

    test('returns null for non-command calls or empty text', () {
      expect(terminalCommandText('terminal_execute', {'command': '  '}), null);
      expect(terminalCommandText('read_file', {'path': '/a'}), null);
    });
  });
}
