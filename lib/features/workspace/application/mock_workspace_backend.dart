import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A fake [WorkspaceBackend] backed by a hard-coded in-memory tree. Used to
/// build and review the file-tree UI before the real Android SAF plugin
/// (`aetherlink_saf`) exists. It returns a plausible Flutter project layout so
/// expand/collapse, icons and indentation can be exercised.
///
/// Replace with the real SAF / Termux / SSH backend later — the file-tree UI
/// depends only on [WorkspaceBackend], so nothing in the UI changes.
class MockWorkspaceBackend implements WorkspaceBackend {
  @override
  bool get supportsTerminal => false;

  @override
  Future<List<FileEntry>> listDir(String path) async {
    // Simulate IO latency so loading states are visible.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final children = _tree[path];
    if (children == null) return const [];
    return children;
  }

  @override
  Future<String> readFile(String path) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _files[path] ?? '// $path\n// (mock content)\n';
  }

  // Directory path -> its immediate children. The root is keyed by ''.
  static const Map<String, List<FileEntry>> _tree = {
    '': [
      FileEntry(name: 'lib', path: 'lib', isDirectory: true),
      FileEntry(name: 'test', path: 'test', isDirectory: true),
      FileEntry(name: 'assets', path: 'assets', isDirectory: true),
      FileEntry(
        name: 'pubspec.yaml',
        path: 'pubspec.yaml',
        isDirectory: false,
        size: 2480,
      ),
      FileEntry(
        name: 'README.md',
        path: 'README.md',
        isDirectory: false,
        size: 1536,
      ),
      FileEntry(
        name: '.gitignore',
        path: '.gitignore',
        isDirectory: false,
        size: 412,
      ),
    ],
    'lib': [
      FileEntry(name: 'features', path: 'lib/features', isDirectory: true),
      FileEntry(name: 'core', path: 'lib/core', isDirectory: true),
      FileEntry(
        name: 'main.dart',
        path: 'lib/main.dart',
        isDirectory: false,
        size: 824,
      ),
    ],
    'lib/features': [
      FileEntry(name: 'chat', path: 'lib/features/chat', isDirectory: true),
      FileEntry(
        name: 'workspace',
        path: 'lib/features/workspace',
        isDirectory: true,
      ),
    ],
    'lib/features/chat': [
      FileEntry(
        name: 'chat_page.dart',
        path: 'lib/features/chat/chat_page.dart',
        isDirectory: false,
        size: 6120,
      ),
    ],
    'lib/features/workspace': [
      FileEntry(
        name: 'workspace_page.dart',
        path: 'lib/features/workspace/workspace_page.dart',
        isDirectory: false,
        size: 9300,
      ),
    ],
    'lib/core': [
      FileEntry(
        name: 'utils.dart',
        path: 'lib/core/utils.dart',
        isDirectory: false,
        size: 512,
      ),
    ],
    'test': [
      FileEntry(
        name: 'widget_test.dart',
        path: 'test/widget_test.dart',
        isDirectory: false,
        size: 640,
      ),
    ],
    'assets': [
      FileEntry(name: 'icons', path: 'assets/icons', isDirectory: true),
      FileEntry(
        name: 'logo.png',
        path: 'assets/logo.png',
        isDirectory: false,
        size: 20480,
      ),
    ],
    'assets/icons': [
      FileEntry(
        name: 'app_icon.svg',
        path: 'assets/icons/app_icon.svg',
        isDirectory: false,
        size: 3072,
      ),
    ],
  };

  static const Map<String, String> _files = {
    'lib/main.dart':
        "import 'package:flutter/material.dart';\n\nvoid main() {\n  runApp(const App());\n}\n",
    'README.md': '# Aetherlink\n\n这是一个示例工作区(mock 数据)。\n',
  };
}
