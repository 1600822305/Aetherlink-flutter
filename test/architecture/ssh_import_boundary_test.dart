import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the SSH backend's plugin-isolation rule from
/// `docs/SSH工作区后端-设计文档.md` §2 / §11 (mirroring the SAF rule in
/// `docs/本地SAF工作区插件-方法规格.md` §1):
///
///   **Only `lib/features/workspace/data/remote_ssh_backend.dart` may import
///   `package:dartssh2/...`.**
///
/// Every other UI / chat / agent file depends on the `WorkspaceBackend`
/// abstraction, never on dartssh2 directly, so swapping the SSH library keeps
/// its blast radius at that one file. This is the same "fail the build on
/// violation" guard used by `import_boundaries_test.dart`, scoped to dartssh2.
void main() {
  const allowedFile = 'lib/features/workspace/data/remote_ssh_backend.dart';
  final dartssh2Import = RegExp(
    '''^\\s*import\\s+['"]package:dartssh2/''',
    multiLine: true,
  );

  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  final offenders = <String>[];
  for (final file in dartFiles) {
    final libPath = file.path.replaceAll(r'\', '/');
    if (libPath == allowedFile) continue;
    if (dartssh2Import.hasMatch(file.readAsStringSync())) {
      offenders.add(libPath);
    }
  }

  test('only remote_ssh_backend.dart imports package:dartssh2', () {
    expect(
      dartFiles,
      isNotEmpty,
      reason: 'no Dart files were scanned under lib/ — check the test setup',
    );
    expect(
      offenders,
      isEmpty,
      reason: 'dartssh2 must stay isolated to $allowedFile, but it is also '
          'imported by:\n${offenders.join('\n')}',
    );
  });
}
