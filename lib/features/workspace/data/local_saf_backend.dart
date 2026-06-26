// LocalSafBackend — the **only** file in the app allowed to import the
// `aetherlink_saf` plugin (docs/本地SAF工作区插件-方法规格.md §1).
//
// Translates `WorkspaceBackend` calls into plugin calls and turns
// plugin-side `FileInfo` into the backend-neutral `WorkspaceEntry`.

import 'package:aetherlink_saf/aetherlink_saf.dart' as saf;

import '../domain/workspace_backend.dart';

class LocalSafBackend implements WorkspaceBackend {
  LocalSafBackend({saf.AetherlinkSaf? plugin})
      : _plugin = plugin ?? const saf.AetherlinkSaf();

  final saf.AetherlinkSaf _plugin;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        // SAF can't run shell commands.
        canExec: false,
        // SAF has no inotify equivalent (spec §3.4).
        canWatch: false,
        isRemote: false,
      );

  @override
  Future<String> echo(String value) async {
    final result = await _plugin.echo(value: value);
    return result.value;
  }

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    final result = await _plugin.listDirectory(path: path);
    return [
      for (final f in result.files)
        WorkspaceEntry(
          name: f.name,
          path: f.path,
          isDirectory: f.type == saf.FileType.directory,
          size: f.size,
          mtime: f.mtime,
          isHidden: f.isHidden,
        ),
    ];
  }

  @override
  Future<String> readFile(String path) async {
    final result = await _plugin.readFile(path: path);
    return result.content;
  }

  /// Launches the system directory picker, persists the grant, and returns
  /// the picked root as a backend-neutral [PickedDirectory] (or `null` when
  /// the user cancels). SAF-specific, so it lives on the concrete backend
  /// rather than [WorkspaceBackend] — callers get a neutral type back, no
  /// `aetherlink_saf` types leak out (spec §1 isolation rule).
  Future<PickedDirectory?> pickDirectory() async {
    final result =
        await _plugin.openSystemFilePicker(type: saf.PickerType.directory);
    if (result.cancelled || result.directories.isEmpty) return null;
    final d = result.directories.first;
    return PickedDirectory(
      name: d.name,
      root: d.path,
      displayPath: d.displayPath,
    );
  }
}

/// A directory the user picked through the system SAF picker, stripped of all
/// `aetherlink_saf` types so callers (UI / store) can build a `Workspace`
/// without importing the plugin.
///
/// [root] is the opaque `content://` URI used to address the directory;
/// [displayPath] is a human-readable hint for the UI only (never pass it back
/// to any backend method).
class PickedDirectory {
  const PickedDirectory({
    required this.name,
    required this.root,
    this.displayPath,
  });

  final String name;
  final String root;
  final String? displayPath;
}
