// 内置终端（PRoot + Alpine rootfs）工作区后端。见 docs/内置终端PRoot-设计文档.md。
//
// · 文件族：rootfs 就是应用私有目录下的普通目录，直接用 dart:io 操作宿主路径；
//   对上层暴露的 path 一律是 guest 侧 posix 路径（如 /root/a.txt），host↔guest
//   映射只存在于本文件内部。
// · 执行族：exec 走无 PTY 的一次性 proot 进程；startShell 走插件的 forkpty
//   通道（交互式）。两者都经 ProotProcessRunner（data 层单文件隔离）。
// · rootfs 未安装时执行族抛 TerminalEngineMissingException，UI 捕获后弹
//   terminal_setup_sheet 引导安装。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/data/proot_process_runner.dart';
import 'package:aetherlink_flutter/features/terminal/domain/proot_command_builder.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_text_ops.dart'
    as text_ops;

/// 与 SSH 一致的整读上限：更大的文件必须按行范围读取。
const int kProotReadFileMaxBytes = 10 * 1024 * 1024;

class ProotBackendException implements Exception {
  const ProotBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProotLocalBackend extends WorkspaceBackend {
  ProotLocalBackend({
    TerminalEngineManager? engineManager,
    ProotProcessRunner? runner,
  })  : _engine = engineManager ?? TerminalEngineManager.instance,
        _runner = runner ?? const ProotProcessRunner();

  final TerminalEngineManager _engine;
  final ProotProcessRunner _runner;

  final StreamController<WorkspaceChangeEvent> _changes =
      StreamController<WorkspaceChangeEvent>.broadcast();

  ProotCommandBuilder? _builder;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        canExec: true,
        canWatch: true,
        isRemote: false,
      );

  // ===== guest / host 路径映射 =====

  /// guest posix 路径 → rootfs 下的宿主路径。拒绝 `..` 越出 rootfs。
  Future<String> _hostPath(String guestPath) async {
    final rootfs = await _engine.rootfsPath();
    final normalized = _normalizeGuest(guestPath);
    return normalized == '/' ? rootfs : '$rootfs$normalized';
  }

  static String _normalizeGuest(String guestPath) {
    final segments = <String>[];
    for (final seg in guestPath.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (segments.isEmpty) {
          throw const ProotBackendException('路径越出 rootfs 根');
        }
        segments.removeLast();
        continue;
      }
      segments.add(seg);
    }
    return '/${segments.join('/')}';
  }

  // ===== reads =====

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<bool> verifyAccess(String path) async {
    if (!await _engine.isInstalled()) return false;
    final host = await _hostPath(path);
    return FileSystemEntity.typeSync(host) != FileSystemEntityType.notFound;
  }

  @override
  Stream<WorkspaceChangeEvent> watch() => _changes.stream;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    final host = Directory(await _hostPath(path));
    final guestDir = _normalizeGuest(path);
    final out = <WorkspaceEntry>[];
    await for (final entity in host.list(followLinks: false)) {
      final name = _basename(entity.path);
      out.add(await _toEntry(_joinGuest(guestDir, name), entity.path, name));
    }
    return out;
  }

  @override
  Future<String> readFile(String path) async {
    final file = File(await _hostPath(path));
    final size = await file.length();
    if (size > kProotReadFileMaxBytes) {
      throw ProotBackendException(
        '文件过大（$size 字节），超过 $kProotReadFileMaxBytes 上限，请按行范围读取',
      );
    }
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }

  @override
  Future<WorkspaceFileRange> readFileRange(
    String path,
    int startLine,
    int endLine,
  ) async =>
      text_ops.readFileRange(await _readWhole(path), startLine, endLine);

  @override
  Future<int> getLineCount(String path) async =>
      text_ops.countLines(await _readWhole(path));

  @override
  Future<WorkspaceEntry> getFileInfo(String path) async {
    final host = await _hostPath(path);
    if (FileSystemEntity.typeSync(host) == FileSystemEntityType.notFound) {
      throw ProotBackendException('文件不存在：$path');
    }
    final name = _basename(_normalizeGuest(path));
    return _toEntry(_normalizeGuest(path), host, name.isEmpty ? '/' : name);
  }

  @override
  Future<List<int>> readFileBytes(
    String path, {
    int offset = 0,
    int? length,
  }) async {
    final file = File(await _hostPath(path));
    final raf = await file.open();
    try {
      await raf.setPosition(offset);
      final len = length ?? (await file.length() - offset);
      return await raf.read(len < 0 ? 0 : len);
    } finally {
      await raf.close();
    }
  }

  Future<String> _readWhole(String path) async {
    final bytes = await File(await _hostPath(path)).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<WorkspaceEntry> _toEntry(
    String guestPath,
    String hostPath,
    String name,
  ) async {
    // 符号链接按目标分类（悬空链接按文件处理），与 SSH 后端一致。
    var stat = await FileStat.stat(hostPath);
    if (stat.type == FileSystemEntityType.notFound ||
        stat.type == FileSystemEntityType.link) {
      stat = FileStat.statSync(hostPath);
    }
    return WorkspaceEntry(
      name: name,
      path: guestPath,
      isDirectory: stat.type == FileSystemEntityType.directory,
      size: stat.size < 0 ? 0 : stat.size,
      mtime: stat.modified.millisecondsSinceEpoch,
      isHidden: name.startsWith('.'),
    );
  }

  static String _joinGuest(String parent, String name) =>
      parent == '/' ? '/$name' : '$parent/$name';

  static String _basename(String path) {
    var s = path;
    while (s.length > 1 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    final i = s.lastIndexOf('/');
    return i < 0 ? s : s.substring(i + 1);
  }

  static String _dirnameGuest(String guestPath) {
    final normalized = _normalizeGuest(guestPath);
    final i = normalized.lastIndexOf('/');
    return i <= 0 ? '/' : normalized.substring(0, i);
  }

  // ===== mutations =====

  @override
  Future<void> writeFile(String path, String content, {bool append = false}) async {
    final file = File(await _hostPath(path));
    await file.writeAsString(
      content,
      mode: append ? FileMode.append : FileMode.write,
    );
    _emit(WorkspaceChangeKind.modified, _normalizeGuest(path));
  }

  @override
  Future<String> createFile(
    String parentPath,
    String name, {
    String? content,
  }) async {
    final guest = _joinGuest(_normalizeGuest(parentPath), name);
    final file = File(await _hostPath(guest));
    if (await file.exists()) {
      throw ProotBackendException('文件已存在：$guest');
    }
    await file.writeAsString(content ?? '');
    _emit(
      WorkspaceChangeKind.created,
      guest,
      parentPath: _normalizeGuest(parentPath),
    );
    return guest;
  }

  @override
  Future<String> createDirectory(
    String parentPath,
    String name, {
    bool recursive = false,
  }) async {
    final guest = _joinGuest(_normalizeGuest(parentPath), name);
    await Directory(await _hostPath(guest)).create(recursive: recursive);
    _emit(
      WorkspaceChangeKind.created,
      guest,
      parentPath: _normalizeGuest(parentPath),
    );
    return guest;
  }

  @override
  Future<void> delete(
    String path, {
    bool isDirectory = false,
    bool recursive = false,
  }) async {
    final host = await _hostPath(path);
    if (isDirectory) {
      await Directory(host).delete(recursive: recursive);
    } else {
      await File(host).delete();
    }
    _emit(WorkspaceChangeKind.deleted, _normalizeGuest(path));
  }

  @override
  Future<String> rename(String path, String newName) async {
    final newGuest = _joinGuest(_dirnameGuest(path), newName);
    await _rename(path, newGuest);
    _emit(
      WorkspaceChangeKind.moved,
      newGuest,
      fromPath: _normalizeGuest(path),
    );
    return newGuest;
  }

  @override
  Future<String> move(String sourcePath, String destinationParent) async {
    final newGuest = _joinGuest(
      _normalizeGuest(destinationParent),
      _basename(_normalizeGuest(sourcePath)),
    );
    await _rename(sourcePath, newGuest);
    _emit(
      WorkspaceChangeKind.moved,
      newGuest,
      fromPath: _normalizeGuest(sourcePath),
      parentPath: _normalizeGuest(destinationParent),
    );
    return newGuest;
  }

  Future<void> _rename(String fromGuest, String toGuest) async {
    final fromHost = await _hostPath(fromGuest);
    final toHost = await _hostPath(toGuest);
    if (FileSystemEntity.isDirectorySync(fromHost)) {
      await Directory(fromHost).rename(toHost);
    } else {
      await File(fromHost).rename(toHost);
    }
  }

  @override
  Future<String> copy(
    String sourcePath,
    String destinationParent, {
    String? newName,
    bool overwrite = false,
  }) async {
    final destGuest = _joinGuest(
      _normalizeGuest(destinationParent),
      newName ?? _basename(_normalizeGuest(sourcePath)),
    );
    final srcHost = await _hostPath(sourcePath);
    final destHost = await _hostPath(destGuest);
    if (!overwrite &&
        FileSystemEntity.typeSync(destHost) != FileSystemEntityType.notFound) {
      throw ProotBackendException('目标已存在：$destGuest');
    }
    if (FileSystemEntity.isDirectorySync(srcHost)) {
      await _copyTree(srcHost, destHost);
    } else {
      await File(srcHost).copy(destHost);
    }
    _emit(
      WorkspaceChangeKind.created,
      destGuest,
      parentPath: _normalizeGuest(destinationParent),
    );
    return destGuest;
  }

  Future<void> _copyTree(String src, String dest) async {
    await Directory(dest).create(recursive: true);
    await for (final entity in Directory(src).list(followLinks: false)) {
      final name = _basename(entity.path);
      final childDest = '$dest/$name';
      if (entity is Directory) {
        await _copyTree(entity.path, childDest);
      } else if (entity is File) {
        await entity.copy(childDest);
      } else if (entity is Link) {
        await Link(childDest).create(await entity.target());
      }
    }
  }

  // ===== text edits（与 SSH 一致，走共享 text ops 的读改写） =====

  @override
  Future<void> insertContent(String path, int line, String content) async {
    final updated = text_ops.insertContent(await _readWhole(path), line, content);
    await File(await _hostPath(path)).writeAsString(updated);
    _emit(WorkspaceChangeKind.modified, _normalizeGuest(path));
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
    final result = text_ops.replaceInFile(
      await _readWhole(path),
      search,
      replace,
      isRegex: isRegex,
      replaceAll: replaceAll,
      caseSensitive: caseSensitive,
    );
    if (result.replacements > 0) {
      await File(await _hostPath(path)).writeAsString(result.newContent);
      _emit(WorkspaceChangeKind.modified, _normalizeGuest(path));
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
    final original = await _readWhole(path);
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
      backupPath = '${_normalizeGuest(path)}.bak';
      await File(await _hostPath(backupPath)).writeAsString(original);
    }
    await File(await _hostPath(path)).writeAsString(outcome.newContent!);
    _emit(WorkspaceChangeKind.modified, _normalizeGuest(path));
    return WorkspaceDiffResult(
      success: true,
      linesChanged: outcome.linesChanged,
      linesAdded: outcome.linesAdded,
      linesDeleted: outcome.linesDeleted,
      backupPath: backupPath,
    );
  }

  // ===== search（宿主目录树的客户端遍历，与 SSH 同策略） =====

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
    final results = <WorkspaceEntry>[];
    final nameMatcher = useRegex
        ? RegExp(query, caseSensitive: false)
        : RegExp(RegExp.escape(query), caseSensitive: false);
    bool nameHit(String name) => useRegex || query.isEmpty
        ? nameMatcher.hasMatch(name)
        : name.toLowerCase().contains(query.toLowerCase());

    Future<void> walk(String guestDir) async {
      if (results.length >= maxResults) return;
      final List<FileSystemEntity> entries;
      try {
        entries = await Directory(await _hostPath(guestDir))
            .list(followLinks: false)
            .toList();
      } catch (_) {
        return; // 目录不可读 — 跳过
      }
      for (final entity in entries) {
        if (results.length >= maxResults) return;
        final name = _basename(entity.path);
        final guestPath = _joinGuest(_normalizeGuest(guestDir), name);
        final isDir = entity is Directory;
        final typeOk = fileTypes.isEmpty ||
            isDir ||
            fileTypes.any((t) => name.toLowerCase().endsWith(t.toLowerCase()));

        var matched = false;
        if (searchType == WorkspaceSearchType.name ||
            searchType == WorkspaceSearchType.both) {
          matched = typeOk && nameHit(name);
        }
        if (!matched &&
            entity is File &&
            typeOk &&
            (searchType == WorkspaceSearchType.content ||
                searchType == WorkspaceSearchType.both)) {
          matched = await _contentMatch(entity, nameMatcher);
        }
        if (matched) {
          results.add(await _toEntry(guestPath, entity.path, name));
        }
        if (isDir && recursive) await walk(guestPath);
      }
    }

    await walk(directory);
    return results;
  }

  Future<bool> _contentMatch(File file, RegExp matcher) async {
    try {
      if (await file.length() > kProotReadFileMaxBytes) return false;
      final content = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      return matcher.hasMatch(content);
    } catch (_) {
      return false;
    }
  }

  // ===== command execution =====

  Future<ProotCommandBuilder> _commandBuilder() async {
    final cached = _builder;
    if (cached != null) return cached;
    await _engine.ensureInstalled();
    final libDir = await _runner.nativeLibDir();
    final loader32 = File('$libDir/libproot_loader32.so');
    final builder = ProotCommandBuilder(
      prootPath: '$libDir/libproot.so',
      loaderPath: '$libDir/libproot_loader.so',
      loader32Path: loader32.existsSync() ? loader32.path : null,
      rootfsPath: await _engine.rootfsPath(),
      tmpDirPath: await _engine.tmpDirPath(),
    );
    _builder = builder;
    return builder;
  }

  @override
  Future<WorkspaceExecResult> exec(
    String command, {
    String? workingDirectory,
    Duration? timeout,
    Future<void>? cancelSignal,
  }) async {
    final builder = await _commandBuilder();
    final result = await _runner.run(
      builder.build(
        command: ['/bin/sh', '-lc', command],
        workingDirectory: workingDirectory,
      ),
      timeout: timeout,
      cancelSignal: cancelSignal,
    );
    return WorkspaceExecResult(
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
      timedOut: result.timedOut,
      canceled: result.canceled,
    );
  }

  @override
  Future<WorkspaceShellSession> startShell({
    int columns = 80,
    int rows = 24,
    String? workingDirectory,
  }) async {
    final builder = await _commandBuilder();
    try {
      final session = await _runner.startPty(
        builder.build(workingDirectory: workingDirectory),
        columns: columns,
        rows: rows,
      );
      return _ProotShellSession(session);
    } on TerminalEngineMissingException {
      rethrow;
    } catch (e) {
      throw ProotBackendException('打开终端失败 · $e');
    }
  }

  void _emit(
    WorkspaceChangeKind kind,
    String path, {
    String? fromPath,
    String? parentPath,
  }) {
    if (_changes.isClosed) return;
    _changes.add(WorkspaceChangeEvent(
      kind: kind,
      path: path,
      fromPath: fromPath,
      parentPath: parentPath,
    ));
  }
}

/// [WorkspaceShellSession] 适配：包一层 PRoot 的 PTY 会话。
class _ProotShellSession implements WorkspaceShellSession {
  _ProotShellSession(this._session);

  final ProotPtySession _session;

  @override
  Stream<List<int>> get output => _session.output;

  @override
  void write(List<int> data) => _session.write(data);

  @override
  void resize(int columns, int rows) => _session.resize(columns, rows);

  @override
  Future<void> get done => _session.done;

  @override
  int? get exitCode => _session.exitCode;

  @override
  Future<void> close() => _session.kill();
}
