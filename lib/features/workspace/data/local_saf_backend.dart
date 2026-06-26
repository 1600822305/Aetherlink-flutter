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
}
