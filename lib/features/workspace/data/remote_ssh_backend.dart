// RemoteSshBackend — the **only** file in the app allowed to import
// `package:dartssh2/dartssh2.dart` (设计文档 §2 / §11 isolation rule, mirroring
// the SAF plugin rule). UI / chat / agent code depends on the
// `WorkspaceBackend` abstraction, never on dartssh2 directly, so swapping the
// SSH library keeps its blast radius at this one file. A guard test
// (test/architecture/ssh_import_boundary_test.dart) enforces this.
//
// **SSH-0 status: unconnected skeleton.** This wires the backend into
// `workspaceBackendProvider` so the `ssh` branch no longer throws on lookup,
// but no transport is established yet — every IO call fails with a clear
// "not connected" [StateError]. The real connection lifecycle (lazy connect,
// host-key TOFU, connection pooling by `connectionId`) and the SFTP read path
// land in SSH-1; writes / text-ops in SSH-2; `exec` in SSH-3 (设计文档 §13).

import 'dart:async';

import 'package:dartssh2/dartssh2.dart';

import '../domain/workspace_backend.dart';

class RemoteSshBackend extends WorkspaceBackend {
  RemoteSshBackend(this.connectionId);

  /// The `SshConnection.id` this backend talks through. Multiple workspaces on
  /// the same server share one backend / transport (设计文档 §4.1).
  final String connectionId;

  // Held for the SSH-1 connection lifecycle; null until a transport is
  // established. Declared now so the dartssh2 import has a real referent (and
  // the isolation seam is exercised by the guard test).
  SSHClient? _client;
  SftpClient? _sftp;

  // Forward-compatible in-app change bus (same contract as LocalSafBackend).
  // SSH-2 mutations will `_emit` here; SSH-4 may add a real remote feed
  // (inotify / polling). Broadcast so late subscribers don't error.
  final StreamController<WorkspaceChangeEvent> _changes =
      StreamController<WorkspaceChangeEvent>.broadcast();

  Never _notConnected(String op) => throw StateError(
        'RemoteSshBackend.$op: SSH transport is not connected yet '
        '(SSH-0 skeleton, connectionId=$connectionId).',
      );

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        // SSH can run shell commands (wired in SSH-3).
        canExec: true,
        // In-app mutations are reported through [watch] (and SSH-4 may add a
        // real remote feed); see WorkspaceCapabilities.canWatch.
        canWatch: true,
        isRemote: true,
      );

  @override
  Stream<WorkspaceChangeEvent> watch() => _changes.stream;

  @override
  Future<String> echo(String value) async => _notConnected('echo');

  @override
  Future<bool> verifyAccess(String path) async => false;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async =>
      _notConnected('listDir');

  @override
  Future<String> readFile(String path) async => _notConnected('readFile');

  /// Tears down the transport and the change bus. Called when the backend is
  /// disposed (provider teardown). Safe to call when never connected.
  Future<void> dispose() async {
    _sftp?.close();
    _sftp = null;
    _client?.close();
    _client = null;
    await _changes.close();
  }
}
