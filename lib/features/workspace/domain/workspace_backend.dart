// The capability-layer view of a workspace. Three implementations are
// planned (see docs/工作区与智能体模式-设计构想.md §2.3):
//
//   ① LocalSafBackend  — phone-local, Android SAF; canExec=false
//   ② TermuxBackend    — same-device Termux; canExec=true
//   ③ RemoteSshBackend — desktop / remote daemon; canExec=true, isRemote=true
//
// **Isolation rule** (docs/本地SAF工作区插件-方法规格.md §1): only
// `LocalSafBackend` is allowed to import `package:aetherlink_saf/...`.
// UI / chat / agent code depends on this file, never on the plugin directly.
// When we swap or rewrite the SAF plugin, the blast radius stays at one Dart
// file.

/// What a backend can do at runtime. UI / agent gates show or hide terminal
/// widgets, watcher subscriptions etc. based on this declaration.
class WorkspaceCapabilities {
  const WorkspaceCapabilities({
    required this.canExec,
    required this.canWatch,
    required this.isRemote,
  });

  /// Whether the backend can run shell commands (Termux / SSH yes, SAF no).
  final bool canExec;

  /// Whether the backend can stream file-change events. SAF has no
  /// inotify equivalent — always `false` on Android local.
  final bool canWatch;

  /// Whether the backend talks to another device. `true` opens up extra
  /// concerns: pairing, latency, auth tokens, etc.
  final bool isRemote;
}

/// A backend-neutral directory entry. Sourced from the plugin's `FileInfo`
/// but stripped of platform-specific fields (`permissions`, `mimeType`) so
/// the rest of the app never has to know about SAF.
class WorkspaceEntry {
  const WorkspaceEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.mtime,
    this.isHidden = false,
  });

  final String name;

  /// Opaque identifier used to address this entry. For [LocalSafBackend]
  /// this is a `content://` URI; for SSH / Termux it'll be a posix path.
  /// **Treat as opaque** — never split on `/` or otherwise parse it.
  final String path;

  final bool isDirectory;
  final int size;
  final int mtime;
  final bool isHidden;
}

/// Backend interface — every workspace capability the rest of the app talks
/// to goes through this.
///
/// Methods that aren't supported on the current backend (`exec` on SAF,
/// `watch` everywhere for now, …) throw [UnsupportedError]; upstream code
/// should gate on [capabilities] before calling them.
abstract class WorkspaceBackend {
  WorkspaceCapabilities get capabilities;

  /// Round-trips [value] through the backend's transport. Used to verify
  /// the underlying channel / connection is wired before doing real work.
  Future<String> echo(String value);

  /// Lists the entries in [path]. Throws if [path] is a file or doesn't
  /// exist.
  Future<List<WorkspaceEntry>> listDir(String path);

  /// Reads [path] as UTF-8 text. Throws when the file is too large for a
  /// whole-file read (see plugin spec §3.3, 10 MB on Android); callers
  /// must fall back to a range read in that case.
  Future<String> readFile(String path);
}
