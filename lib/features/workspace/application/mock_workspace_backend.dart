import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A fake [WorkspaceBackend] backed by a hard-coded in-memory tree. Used to
/// build and review the file-tree UI before a real backend (SAF / Termux /
/// SSH) is wired to an opened workspace. It returns a plausible Flutter
/// project layout so expand/collapse, icons and indentation can be exercised.
///
/// It implements the same [WorkspaceBackend] contract as the real backends, so
/// the file-tree UI depends only on that interface — swapping in
/// `LocalSafBackend` later changes nothing in the UI.
class MockWorkspaceBackend extends WorkspaceBackend {
  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        canExec: false,
        canWatch: false,
        isRemote: false,
      );

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    // Simulate IO latency so loading states are visible.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _tree[path] ?? const [];
  }

  @override
  Future<String> readFile(String path) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _files[path] ?? '// $path\n// (mock content)\n';
  }

  // A fixed timestamp keeps the mock deterministic (2024-01-01T00:00:00Z).
  static const int _mtime = 1704067200000;

  static WorkspaceEntry _dir(String name, String path) => WorkspaceEntry(
        name: name,
        path: path,
        isDirectory: true,
        size: 0,
        mtime: _mtime,
      );

  static WorkspaceEntry _file(String name, String path, int size) =>
      WorkspaceEntry(
        name: name,
        path: path,
        isDirectory: false,
        size: size,
        mtime: _mtime,
      );

  // Directory path -> its immediate children. The root is keyed by ''.
  static final Map<String, List<WorkspaceEntry>> _tree = {
    '': [
      _dir('lib', 'lib'),
      _dir('test', 'test'),
      _dir('assets', 'assets'),
      _file('pubspec.yaml', 'pubspec.yaml', 2480),
      _file('README.md', 'README.md', 1536),
      _file('.gitignore', '.gitignore', 412),
    ],
    'lib': [
      _dir('features', 'lib/features'),
      _dir('core', 'lib/core'),
      _file('main.dart', 'lib/main.dart', 824),
    ],
    'lib/features': [
      _dir('chat', 'lib/features/chat'),
      _dir('workspace', 'lib/features/workspace'),
    ],
    'lib/features/chat': [
      _file('chat_page.dart', 'lib/features/chat/chat_page.dart', 6120),
    ],
    'lib/features/workspace': [
      _file(
        'workspace_page.dart',
        'lib/features/workspace/workspace_page.dart',
        9300,
      ),
    ],
    'lib/core': [
      _file('utils.dart', 'lib/core/utils.dart', 512),
    ],
    'test': [
      _file('widget_test.dart', 'test/widget_test.dart', 640),
    ],
    'assets': [
      _dir('icons', 'assets/icons'),
      _file('logo.png', 'assets/logo.png', 20480),
    ],
    'assets/icons': [
      _file('app_icon.svg', 'assets/icons/app_icon.svg', 3072),
    ],
  };

  static const Map<String, String> _files = {
    'lib/main.dart':
        "import 'package:flutter/material.dart';\n\nvoid main() {\n  runApp(const App());\n}\n",
    'README.md': '# Aetherlink\n\n这是一个示例工作区(mock 数据)。\n',
  };
}
