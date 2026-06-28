// RemoteSshBackend — the **only** file in the app allowed to import
// `package:dartssh2/dartssh2.dart` (设计文档 §2 / §11 isolation rule, mirroring
// the SAF plugin rule). UI / chat / agent code depends on the
// `WorkspaceBackend` abstraction, never on dartssh2 directly, so swapping the
// SSH library keeps its blast radius at this one file. A guard test
// (test/architecture/ssh_import_boundary_test.dart) enforces this.
//
// **SSH-1: read-only browse.** Lazily opens (and reuses) one SSHClient + SFTP
// channel per connection, verifies the host key TOFU-style, and implements the
// read surface (listDir / readFile / readFileBytes / getFileInfo / verifyAccess
// + readFileRange / getLineCount via the shared workspace_text_ops). Writes /
// edits / exec stay UnsupportedError (inherited) until SSH-2 / SSH-3.

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

  // Forward-compatible in-app change bus (same contract as LocalSafBackend).
  // SSH-2 mutations will `_emit` here. Broadcast so late subscribers don't error.
  final StreamController<WorkspaceChangeEvent> _changes =
      StreamController<WorkspaceChangeEvent>.broadcast();

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
