// RemoteSshBackend — the **only** file in the app allowed to import
// `package:dartssh2/dartssh2.dart` (设计文档 §2 / §11 isolation rule, mirroring
// the SAF plugin rule). UI / chat / agent code depends on the
// `WorkspaceBackend` abstraction, never on dartssh2 directly, so swapping the
// SSH library keeps its blast radius at this one file. A guard test
// (test/architecture/ssh_import_boundary_test.dart) enforces this.
//
// Lazily opens (and reuses) one SSHClient + SFTP channel per connection and
// verifies the host key TOFU-style. Implements:
//   · SSH-1 reads   — listDir / readFile / readFileBytes / getFileInfo /
//     verifyAccess (+ readFileRange / getLineCount via workspace_text_ops);
//   · SSH-2 writes  — the SFTP write family + text edits (read-modify-write);
//   · SSH-3 exec    — one-shot, non-PTY `exec()` over an exec channel.
// SSH-3b (interactive PTY shell) lands next.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../domain/ssh_connection.dart';
import '../domain/workspace_backend.dart';
import '../domain/workspace_text_ops.dart' as text_ops;

/// Whole-file read cap, matching the SAF backend's 10 MB limit (plugin spec
/// §3.3): [readFile] above this throws so callers fall back to a range read.
const int kSshReadFileMaxBytes = 10 * 1024 * 1024;

const Duration _kConnectTimeout = Duration(seconds: 20);

/// Thrown by connection / read operations with a user-facing message.
class SshBackendException implements Exception {
  const SshBackendException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RemoteSshBackend extends WorkspaceBackend {
  RemoteSshBackend(
    this.connectionId, {
    required this.resolveParams,
    this.onLearnFingerprint,
  });

  /// The `SshConnection.id` this backend talks through. Multiple workspaces on
  /// the same server share one backend / transport (设计文档 §4.1).
  final String connectionId;

  /// Reads the current connection inputs at connect time.
  final Future<SshConnectParams> Function() resolveParams;

  /// Persists a fingerprint learned on first contact (TOFU). Null when the
  /// caller doesn't want to remember (e.g. the pool always has an expected one).
  final Future<void> Function(String fingerprint)? onLearnFingerprint;

  SSHClient? _client;
  SftpClient? _sftp;
  bool _alive = false;
  Future<SftpClient>? _connecting;

  // In-app change bus (same contract as LocalSafBackend): every mutation made
  // through this backend is emitted so the tree / editor refresh live.
  // Broadcast so late subscribers don't error.
  final StreamController<WorkspaceChangeEvent> _changes =
      StreamController<WorkspaceChangeEvent>.broadcast();

  void _emit(
    WorkspaceChangeKind kind,
    String path, {
    String? fromPath,
    String? parentPath,
  }) {
    if (!_changes.hasListener) return;
    _changes.add(
      WorkspaceChangeEvent(
        kind: kind,
        path: path,
        fromPath: fromPath,
        parentPath: parentPath,
      ),
    );
  }

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        canExec: true,
        canWatch: true,
        isRemote: true,
      );

  @override
  Stream<WorkspaceChangeEvent> watch() => _changes.stream;

  // ===== connection lifecycle =====

  Future<SftpClient> _sftpClient() async {
    final existing = _sftp;
    if (existing != null && _alive) return existing;
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<SftpClient> _connect() async {
    final params = await resolveParams();
    final identities = _loadIdentities(params);

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        params.host,
        params.port,
        timeout: _kConnectTimeout,
      );
    } catch (e) {
      throw SshBackendException('无法连接 ${params.host}:${params.port} · $e');
    }

    final client = SSHClient(
      socket,
      username: params.username,
      identities: identities,
      onPasswordRequest: params.authType == SshAuthType.password
          ? () => params.password
          : null,
      onVerifyHostKey: (type, fingerprint) =>
          _verifyHostKey(params.expectedFingerprint, fingerprint),
    );
    try {
      await client.authenticated;
    } catch (e) {
      client.close();
      throw SshBackendException('认证失败 · $e');
    }

    final sftp = await client.sftp();
    _client = client;
    _sftp = sftp;
    _alive = true;
    unawaited(_markDeadWhenDone(client));
    return sftp;
  }

  Future<void> _markDeadWhenDone(SSHClient client) async {
    try {
      await client.done;
    } catch (_) {
      // Connection dropped with an error — still mark dead so we reconnect.
    }
    _alive = false;
  }

  FutureOr<bool> _verifyHostKey(String? expected, Uint8List fingerprint) {
    final actual = _fingerprintString(fingerprint);
    if (expected == null || expected.isEmpty) {
      // First contact: trust and remember (TOFU).
      final learn = onLearnFingerprint;
      if (learn != null) unawaited(learn(actual));
      return true;
    }
    return actual == expected;
  }

  static List<SSHKeyPair>? _loadIdentities(SshConnectParams params) {
    if (params.authType != SshAuthType.privateKey) return null;
    final pem = params.privateKeyPem ?? '';
    try {
      return SSHKeyPair.fromPem(pem, params.passphrase);
    } catch (e) {
      throw const SshBackendException('私钥解析失败：密码错误或密钥格式不受支持');
    }
  }

  // dartssh2 hands us the OpenSSH SHA256 fingerprint as UTF-8 bytes of
  // "SHA256:<base64>"; decode straight back to that string for storage/compare.
  static String _fingerprintString(Uint8List fingerprint) {
    try {
      return utf8.decode(fingerprint);
    } catch (_) {
      return fingerprint
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(':');
    }
  }

  // ===== reads =====

  @override
  Future<String> echo(String value) async {
    // Round-trips through the SFTP channel by confirming it's live.
    await _sftpClient();
    return value;
  }

  @override
  Future<bool> verifyAccess(String path) async {
    try {
      final sftp = await _sftpClient();
      await sftp.stat(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    final sftp = await _sftpClient();
    final names = await sftp.listdir(path);
    final out = <WorkspaceEntry>[];
    for (final n in names) {
      if (n.filename == '.' || n.filename == '..') continue;
      out.add(_toEntry(_join(path, n.filename), n.filename, n.attr));
    }
    return out;
  }

  @override
  Future<String> readFile(String path) async {
    final sftp = await _sftpClient();
    final attrs = await sftp.stat(path);
    final size = attrs.size ?? 0;
    if (size > kSshReadFileMaxBytes) {
      throw SshBackendException(
        '文件过大（$size 字节），超过 $kSshReadFileMaxBytes 上限，请按行范围读取',
      );
    }
    return _readWhole(sftp, path);
  }

  @override
  Future<WorkspaceFileRange> readFileRange(
    String path,
    int startLine,
    int endLine,
  ) async {
    final sftp = await _sftpClient();
    return text_ops.readFileRange(
      await _readWhole(sftp, path),
      startLine,
      endLine,
    );
  }

  @override
  Future<int> getLineCount(String path) async {
    final sftp = await _sftpClient();
    return text_ops.countLines(await _readWhole(sftp, path));
  }

  @override
  Future<WorkspaceEntry> getFileInfo(String path) async {
    final sftp = await _sftpClient();
    final attrs = await sftp.stat(path);
    return _toEntry(path, _basename(path), attrs);
  }

  @override
  Future<List<int>> readFileBytes(
    String path, {
    int offset = 0,
    int? length,
  }) async {
    final sftp = await _sftpClient();
    final file = await sftp.open(path);
    try {
      return await file.readBytes(offset: offset, length: length);
    } finally {
      await file.close();
    }
  }

  Future<String> _readWhole(SftpClient sftp, String path) async {
    final file = await sftp.open(path);
    try {
      final bytes = await file.readBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await file.close();
    }
  }

  WorkspaceEntry _toEntry(String path, String name, SftpFileAttrs a) =>
      WorkspaceEntry(
        name: name,
        path: path,
        isDirectory: a.isDirectory,
        size: a.size ?? 0,
        // SFTP mtime is seconds since epoch; WorkspaceEntry.mtime is ms (SAF).
        mtime: (a.modifyTime ?? 0) * 1000,
        isHidden: name.startsWith('.'),
      );

  /// Joins a posix [parent] dir with a child [name]. The backend owns SSH path
  /// construction (consumers still treat the result as opaque).
  static String _join(String parent, String name) {
    if (parent.isEmpty) return name;
    if (parent == '/') return '/$name';
    return parent.endsWith('/') ? '$parent$name' : '$parent/$name';
  }

  static String _basename(String path) {
    var p = path;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    final i = p.lastIndexOf('/');
    return i < 0 ? p : p.substring(i + 1);
  }

  static String _dirname(String path) {
    var p = path;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    final i = p.lastIndexOf('/');
    if (i < 0) return '.';
    if (i == 0) return '/';
    return p.substring(0, i);
  }

  // ===== mutations =====

  @override
  Future<void> writeFile(String path, String content, {bool append = false}) async {
    final sftp = await _sftpClient();
    final mode = append
        ? SftpFileOpenMode.write | SftpFileOpenMode.create | SftpFileOpenMode.append
        : SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate;
    final file = await sftp.open(path, mode: mode);
    try {
      await file.writeBytes(Uint8List.fromList(utf8.encode(content)));
    } finally {
      await file.close();
    }
    _emit(WorkspaceChangeKind.modified, path);
  }

  @override
  Future<String> createFile(
    String parentPath,
    String name, {
    String? content,
  }) async {
    final sftp = await _sftpClient();
    final path = _join(parentPath, name);
    final file = await sftp.open(
      path,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.exclusive,
    );
    try {
      if (content != null && content.isNotEmpty) {
        await file.writeBytes(Uint8List.fromList(utf8.encode(content)));
      }
    } finally {
      await file.close();
    }
    _emit(WorkspaceChangeKind.created, path, parentPath: parentPath);
    return path;
  }

  @override
  Future<String> createDirectory(
    String parentPath,
    String name, {
    bool recursive = false,
  }) async {
    final sftp = await _sftpClient();
    final path = _join(parentPath, name);
    if (!recursive) {
      await sftp.mkdir(path);
    } else {
      // Create each missing ancestor in turn; ignore "already exists" failures.
      final segments = path.split('/');
      var current = path.startsWith('/') ? '' : '.';
      for (final seg in segments) {
        if (seg.isEmpty) continue;
        current = current.isEmpty ? '/$seg' : _join(current, seg);
        try {
          await sftp.mkdir(current);
        } catch (_) {
          // Most likely already exists — keep going.
        }
      }
    }
    _emit(WorkspaceChangeKind.created, path, parentPath: parentPath);
    return path;
  }

  @override
  Future<void> delete(
    String path, {
    bool isDirectory = false,
    bool recursive = false,
  }) async {
    final sftp = await _sftpClient();
    if (!isDirectory) {
      await sftp.remove(path);
    } else if (!recursive) {
      await sftp.rmdir(path);
    } else {
      await _deleteTree(sftp, path);
    }
    _emit(WorkspaceChangeKind.deleted, path);
  }

  Future<void> _deleteTree(SftpClient sftp, String dir) async {
    for (final n in await sftp.listdir(dir)) {
      if (n.filename == '.' || n.filename == '..') continue;
      final child = _join(dir, n.filename);
      if (n.attr.isDirectory) {
        await _deleteTree(sftp, child);
      } else {
        await sftp.remove(child);
      }
    }
    await sftp.rmdir(dir);
  }

  @override
  Future<String> rename(String path, String newName) async {
    final sftp = await _sftpClient();
    final newPath = _join(_dirname(path), newName);
    await sftp.rename(path, newPath);
    _emit(WorkspaceChangeKind.moved, newPath, fromPath: path);
    return newPath;
  }

  @override
  Future<String> move(String sourcePath, String destinationParent) async {
    final sftp = await _sftpClient();
    final newPath = _join(destinationParent, _basename(sourcePath));
    await sftp.rename(sourcePath, newPath);
    _emit(
      WorkspaceChangeKind.moved,
      newPath,
      fromPath: sourcePath,
      parentPath: destinationParent,
    );
    return newPath;
  }

  @override
  Future<String> copy(
    String sourcePath,
    String destinationParent, {
    String? newName,
    bool overwrite = false,
  }) async {
    final sftp = await _sftpClient();
    final destPath = _join(destinationParent, newName ?? _basename(sourcePath));
    final srcAttrs = await sftp.stat(sourcePath);
    if (srcAttrs.isDirectory) {
      await _copyTree(sftp, sourcePath, destPath, overwrite);
    } else {
      await _copyFile(sftp, sourcePath, destPath, overwrite);
    }
    _emit(WorkspaceChangeKind.created, destPath, parentPath: destinationParent);
    return destPath;
  }

  Future<void> _copyFile(
    SftpClient sftp,
    String src,
    String dest,
    bool overwrite,
  ) async {
    final input = await sftp.open(src);
    Uint8List bytes;
    try {
      bytes = await input.readBytes();
    } finally {
      await input.close();
    }
    final mode = SftpFileOpenMode.write |
        SftpFileOpenMode.create |
        (overwrite ? SftpFileOpenMode.truncate : SftpFileOpenMode.exclusive);
    final output = await sftp.open(dest, mode: mode);
    try {
      await output.writeBytes(bytes);
    } finally {
      await output.close();
    }
  }

  Future<void> _copyTree(
    SftpClient sftp,
    String src,
    String dest,
    bool overwrite,
  ) async {
    try {
      await sftp.mkdir(dest);
    } catch (_) {
      if (!overwrite) rethrow;
    }
    for (final n in await sftp.listdir(src)) {
      if (n.filename == '.' || n.filename == '..') continue;
      final childSrc = _join(src, n.filename);
      final childDest = _join(dest, n.filename);
      if (n.attr.isDirectory) {
        await _copyTree(sftp, childSrc, childDest, overwrite);
      } else {
        await _copyFile(sftp, childSrc, childDest, overwrite);
      }
    }
  }

  // ===== text edits (read-modify-write via the shared text ops) =====

  @override
  Future<void> insertContent(String path, int line, String content) async {
    final sftp = await _sftpClient();
    final updated = text_ops.insertContent(
      await _readWhole(sftp, path),
      line,
      content,
    );
    await _overwrite(sftp, path, updated);
    _emit(WorkspaceChangeKind.modified, path);
  }

  @override
  Future<int> replaceInFile(
    String path,
    String search,
    String replace, {
    bool isRegex = false,
    bool replaceAll = true,
    bool caseSensitive = true,
  }) async {
    final sftp = await _sftpClient();
    final result = text_ops.replaceInFile(
      await _readWhole(sftp, path),
      search,
      replace,
      isRegex: isRegex,
      replaceAll: replaceAll,
      caseSensitive: caseSensitive,
    );
    if (result.replacements > 0) {
      await _overwrite(sftp, path, result.newContent);
      _emit(WorkspaceChangeKind.modified, path);
    }
    return result.replacements;
  }

  @override
  Future<WorkspaceDiffResult> applyDiff(
    String path,
    String diff, {
    WorkspaceDiffFormat format = WorkspaceDiffFormat.searchReplace,
    bool createBackup = false,
    String? expectedRangeHash,
    int? rangeStartLine,
    int? rangeEndLine,
  }) async {
    final sftp = await _sftpClient();
    final original = await _readWhole(sftp, path);
    final outcome = text_ops.applyDiff(
      original,
      diff,
      format: format,
      expectedRangeHash: expectedRangeHash,
      rangeStartLine: rangeStartLine,
      rangeEndLine: rangeEndLine,
    );
    if (!outcome.success || outcome.newContent == null) {
      return const WorkspaceDiffResult(
        success: false,
        linesChanged: 0,
        linesAdded: 0,
        linesDeleted: 0,
      );
    }
    String? backupPath;
    if (createBackup) {
      backupPath = '$path.bak';
      await _overwrite(sftp, backupPath, original);
    }
    await _overwrite(sftp, path, outcome.newContent!);
    _emit(WorkspaceChangeKind.modified, path);
    return WorkspaceDiffResult(
      success: true,
      linesChanged: outcome.linesChanged,
      linesAdded: outcome.linesAdded,
      linesDeleted: outcome.linesDeleted,
      backupPath: backupPath,
    );
  }

  Future<void> _overwrite(SftpClient sftp, String path, String content) async {
    final file = await sftp.open(
      path,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(Uint8List.fromList(utf8.encode(content)));
    } finally {
      await file.close();
    }
  }

  // ===== search (client-side SFTP traversal; exec-backed grep lands in SSH-3) =====

  @override
  Future<List<WorkspaceEntry>> searchFiles(
    String directory,
    String query, {
    WorkspaceSearchType searchType = WorkspaceSearchType.name,
    List<String> fileTypes = const [],
    int maxResults = 200,
    bool recursive = true,
    bool useRegex = false,
  }) async {
    final sftp = await _sftpClient();
    final results = <WorkspaceEntry>[];
    final nameMatcher = useRegex
        ? RegExp(query, caseSensitive: false)
        : RegExp(RegExp.escape(query), caseSensitive: false);
    bool nameHit(String name) => useRegex || query.isEmpty
        ? nameMatcher.hasMatch(name)
        : name.toLowerCase().contains(query.toLowerCase());

    Future<void> walk(String dir) async {
      if (results.length >= maxResults) return;
      List<SftpName> entries;
      try {
        entries = await sftp.listdir(dir);
      } catch (_) {
        return; // unreadable dir — skip
      }
      for (final n in entries) {
        if (results.length >= maxResults) return;
        if (n.filename == '.' || n.filename == '..') continue;
        final path = _join(dir, n.filename);
        final isDir = n.attr.isDirectory;
        // [fileTypes] (extension filter) only constrains files, never dirs (we
        // still recurse into them).
        final typeOk = fileTypes.isEmpty ||
            isDir ||
            fileTypes.any(
              (t) => n.filename.toLowerCase().endsWith(t.toLowerCase()),
            );

        var matched = false;
        if (searchType == WorkspaceSearchType.name ||
            searchType == WorkspaceSearchType.both) {
          matched = typeOk && nameHit(n.filename);
        }
        if (!matched &&
            !isDir &&
            typeOk &&
            (searchType == WorkspaceSearchType.content ||
                searchType == WorkspaceSearchType.both)) {
          matched = await _contentMatch(sftp, path, nameMatcher);
        }
        if (matched) results.add(_toEntry(path, n.filename, n.attr));
        if (isDir && recursive) await walk(path);
      }
    }

    await walk(directory);
    return results;
  }

  Future<bool> _contentMatch(
    SftpClient sftp,
    String path,
    RegExp matcher,
  ) async {
    try {
      final attrs = await sftp.stat(path);
      if ((attrs.size ?? 0) > kSshReadFileMaxBytes) return false;
      final content = await _readWhole(sftp, path);
      return matcher.hasMatch(content);
    } catch (_) {
      return false;
    }
  }

  // ===== command execution (SSH-3) =====

  @override
  Future<WorkspaceExecResult> exec(
    String command,
    {String? workingDirectory, Duration? timeout}) async {
    final client = await _sshClient();
    // Run under the requested cwd via `cd` (dartssh2 has no per-exec cwd); the
    // path is single-quoted so spaces / specials don't break out. The command
    // itself is the caller's responsibility (it's HITL-gated upstream).
    final full = (workingDirectory != null && workingDirectory.isNotEmpty)
        ? 'cd ${_shellQuote(workingDirectory)} && $command'
        : command;

    final SSHSession session;
    try {
      session = await client.execute(full);
    } catch (e) {
      throw SshBackendException('命令执行失败 · $e');
    }

    final out = BytesBuilder(copy: false);
    final err = BytesBuilder(copy: false);
    final outSub = session.stdout.listen(out.add);
    final errSub = session.stderr.listen(err.add);

    var timedOut = false;
    try {
      if (timeout != null) {
        await session.done.timeout(timeout, onTimeout: () {
          timedOut = true;
          session.kill(SSHSignal.KILL);
        });
      } else {
        await session.done;
      }
    } finally {
      await outSub.cancel();
      await errSub.cancel();
    }

    return WorkspaceExecResult(
      stdout: utf8.decode(out.takeBytes(), allowMalformed: true),
      stderr: utf8.decode(err.takeBytes(), allowMalformed: true),
      exitCode: session.exitCode ?? -1,
      timedOut: timedOut,
    );
  }

  @override
  Future<WorkspaceShellSession> startShell({
    int columns = 80,
    int rows = 24,
    String? workingDirectory,
  }) async {
    final client = await _sshClient();
    final SSHSession session;
    try {
      session = await client.shell(
        pty: SSHPtyConfig(width: columns, height: rows),
      );
    } catch (e) {
      throw SshBackendException('打开终端失败 · $e');
    }
    if (workingDirectory != null && workingDirectory.isNotEmpty) {
      // cd into the workspace root before handing the prompt to the user.
      session.write(
        Uint8List.fromList(utf8.encode('cd ${_shellQuote(workingDirectory)}\n')),
      );
    }
    return _SshShellSession(session);
  }

  /// Ensures the transport is up (reusing the same lazy connect as SFTP) and
  /// returns the live [SSHClient] for opening exec / shell channels.
  Future<SSHClient> _sshClient() async {
    await _sftpClient();
    final client = _client;
    if (client == null) throw const SshBackendException('SSH 未连接');
    return client;
  }

  // POSIX single-quote escaping: wrap in '…' and replace embedded ' with '\''.
  static String _shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

  /// Tears down the transport and the change bus (provider teardown). Safe to
  /// call when never connected.
  Future<void> dispose() async {
    _sftp?.close();
    _sftp = null;
    _client?.close();
    _client = null;
    _alive = false;
    await _changes.close();
  }

  /// One-shot connection test for the connection form: dials the host, runs
  /// auth, optionally stats [rootToStat], and reports the observed host-key
  /// fingerprint (for TOFU). Never throws — failures come back as
  /// [SshProbeResult.ok] = false with a message.
  static Future<SshProbeResult> probe(
    SshConnectParams params, {
    String? rootToStat,
  }) async {
    String? captured;
    SSHClient? client;
    SftpClient? sftp;
    try {
      final identities = _loadIdentities(params);
      final socket = await SSHSocket.connect(
        params.host,
        params.port,
        timeout: _kConnectTimeout,
      );
      client = SSHClient(
        socket,
        username: params.username,
        identities: identities,
        onPasswordRequest: params.authType == SshAuthType.password
            ? () => params.password
            : null,
        onVerifyHostKey: (type, fingerprint) {
          captured = _fingerprintString(fingerprint);
          final expected = params.expectedFingerprint;
          if (expected == null || expected.isEmpty) return true;
          return captured == expected;
        },
      );
      await client.authenticated;
      sftp = await client.sftp();
      if (rootToStat != null && rootToStat.isNotEmpty) {
        await sftp.stat(rootToStat);
      }
      return SshProbeResult(ok: true, fingerprint: captured);
    } on SshBackendException catch (e) {
      return SshProbeResult(ok: false, fingerprint: captured, error: e.message);
    } catch (e) {
      return SshProbeResult(
        ok: false,
        fingerprint: captured,
        error: e.toString(),
      );
    } finally {
      sftp?.close();
      client?.close();
    }
  }
}

/// Backend-neutral wrapper over a dartssh2 [SSHSession] opened as a PTY shell
/// (设计文档 §8.2). Merges stdout + stderr into one broadcast byte stream and
/// maps write / resize / close onto the session. Keeps dartssh2 out of the UI.
class _SshShellSession implements WorkspaceShellSession {
  _SshShellSession(this._session) {
    _outSub = _session.stdout.listen(_out.add, onError: (_) {});
    _errSub = _session.stderr.listen(_out.add, onError: (_) {});
    // Close the output stream once the remote shell exits.
    _session.done.whenComplete(() {
      if (!_out.isClosed) _out.close();
    });
  }

  final SSHSession _session;
  final StreamController<List<int>> _out =
      StreamController<List<int>>.broadcast();
  StreamSubscription<Uint8List>? _outSub;
  StreamSubscription<Uint8List>? _errSub;

  @override
  Stream<List<int>> get output => _out.stream;

  @override
  void write(List<int> data) => _session.write(Uint8List.fromList(data));

  @override
  void resize(int columns, int rows) =>
      _session.resizeTerminal(columns, rows);

  @override
  Future<void> get done => _session.done;

  @override
  int? get exitCode => _session.exitCode;

  @override
  Future<void> close() async {
    await _outSub?.cancel();
    await _errSub?.cancel();
    _session.close();
    if (!_out.isClosed) await _out.close();
  }
}
