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

  /// 手机存储在 guest 里的挂载点：系统根与家目录各一个（工作区根是
  /// /root，只挂在 / 下文件区看不到）。shell 的 proot 绑定与此保持一致。
  static const List<String> sdcardGuestPaths = ['/sdcard', '/root/sdcard'];

  /// guest posix 路径 → 宿主路径。拒绝 `..` 越出 rootfs。/sdcard 挂载点
  /// 映射到手机存储，让文件区与 shell 视图一致。
  Future<String> _hostPath(String guestPath) async {
    final normalized = _normalizeGuest(guestPath);
    for (final mount in sdcardGuestPaths) {
      if (normalized == mount || normalized.startsWith('$mount/')) {
        return TerminalEngineManager.sdcardHostPath +
            normalized.substring(mount.length);
      }
    }
    final rootfs = await _engine.rootfsPath();
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

  // ===== 外部变更监听（inotify） =====
  //
  // 在容器终端/智能体命令里改文件不经过本后端的写接口，[_emit] 不会
  // 触发。Linux 的 dart:io 不支持递归 watch，所以对「UI 列过的目录」逐个
  // 非递归 inotify（LRU 上限 [_kMaxWatchedDirs]，与 SSH 轮询集同口径），
  // 事件映射回 guest 路径后广播到 [watch]；`.git` 内部噪声不监听。
  static const int _kMaxWatchedDirs = 64;

  final Map<String, StreamSubscription<FileSystemEvent>> _dirWatchers = {};

  void _watchHostDir(String guestDir, String hostDir) {
    if (_basename(guestDir) == '.git' || guestDir.contains('/.git/')) return;
    final existing = _dirWatchers.remove(guestDir);
    if (existing != null) {
      _dirWatchers[guestDir] = existing; // refresh LRU position
      return;
    }
    late final StreamSubscription<FileSystemEvent> sub;
    try {
      sub = Directory(hostDir).watch().listen(
        (event) => _onHostEvent(guestDir, hostDir, event),
        onError: (Object _) {
          _dirWatchers.remove(guestDir)?.cancel();
        },
        onDone: () => _dirWatchers.remove(guestDir),
        cancelOnError: true,
      );
    } catch (_) {
      return; // 平台不支持 watch 时退化为无外部监听
    }
    _dirWatchers[guestDir] = sub;
    while (_dirWatchers.length > _kMaxWatchedDirs) {
      final oldest = _dirWatchers.keys.first;
      _dirWatchers.remove(oldest)?.cancel();
    }
  }

  void _onHostEvent(String guestDir, String hostDir, FileSystemEvent event) {
    final name = _basename(event.path);
    if (name == '.git') return; // git 内部操作频繁 touch .git，不向上吹
    final guest = _joinGuest(guestDir, name);
    switch (event) {
      case FileSystemCreateEvent():
        _emit(WorkspaceChangeKind.created, guest, parentPath: guestDir);
      case FileSystemModifyEvent(contentChanged: final changed):
        if (changed) _emit(WorkspaceChangeKind.modified, guest);
      case FileSystemDeleteEvent():
        _emit(WorkspaceChangeKind.deleted, guest);
      case FileSystemMoveEvent(destination: final dest):
        if (dest != null && dest.startsWith('$hostDir/')) {
          _emit(
            WorkspaceChangeKind.moved,
            _joinGuest(guestDir, _basename(dest)),
            fromPath: guest,
            parentPath: guestDir,
          );
        } else {
          _emit(WorkspaceChangeKind.deleted, guest);
        }
    }
  }

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async {
    final host = Directory(await _hostPath(path));
    final guestDir = _normalizeGuest(path);
    _watchHostDir(guestDir, host.path);
    final out = <WorkspaceEntry>[];
    await for (final entity in host.list(followLinks: false)) {
      final name = _basename(entity.path);
      out.add(await _toEntry(_joinGuest(guestDir, name), entity.path, name));
    }
    // 手机存储的挂载点不在 rootfs 目录里，列到挂载点父目录时单独注入。
    final sdcard = Directory(TerminalEngineManager.sdcardHostPath);
    if (sdcard.existsSync()) {
      for (final mount in sdcardGuestPaths) {
        final parent = mount.substring(0, mount.lastIndexOf('/'));
        if (guestDir == (parent.isEmpty ? '/' : parent) &&
            !out.any((e) => e.path == mount)) {
          out.add(await _toEntry(mount, sdcard.path, 'sdcard'));
        }
      }
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

  /// 受保护路径：rootfs 根与手机存储挂载点本身。对它们做删除/重命名/移动
  /// 会直接作用到手机真实文件或破坏 rootfs，挂载点内部的文件不受限。
  @override
  bool isProtectedPath(String path) {
    final normalized = _normalizeGuest(path);
    return normalized == '/' || sdcardGuestPaths.contains(normalized);
  }

  void _guardProtected(String path) {
    if (isProtectedPath(path)) {
      throw ProotBackendException(
        '受保护路径：${_normalizeGuest(path)} 是手机存储挂载点或 rootfs 根，'
        '不允许删除/重命名/移动',
      );
    }
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
  Future<String> createFileBytes(
    String parentPath,
    String name,
    List<int> bytes,
  ) async {
    final guest = _joinGuest(_normalizeGuest(parentPath), name);
    final file = File(await _hostPath(guest));
    if (await file.exists()) {
      throw ProotBackendException('文件已存在：$guest');
    }
    await file.writeAsBytes(bytes, flush: true);
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
    _guardProtected(path);
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
    _guardProtected(path);
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
    _guardProtected(sourcePath);
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
    final isDir = FileSystemEntity.isDirectorySync(fromHost);
    try {
      if (isDir) {
        await Directory(fromHost).rename(toHost);
      } else {
        await File(fromHost).rename(toHost);
      }
    } on FileSystemException {
      // rename 不能跨文件系统（如共享存储 <-> 应用私有目录），降级为复制+删除。
      if (isDir) {
        await _copyTree(fromHost, toHost);
        await Directory(fromHost).delete(recursive: true);
      } else {
        await File(fromHost).copy(toHost);
        await File(fromHost).delete();
      }
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
    // 手机存储默认自动挂载（存在即绑）；权限变化后缓存按状态重建。
    final mountSdcard =
        Directory(TerminalEngineManager.sdcardHostPath).existsSync();
    final cached = _builder;
    if (cached != null && cached.extraBinds.isNotEmpty == mountSdcard) {
      return cached;
    }
    await _engine.ensureInstalled();
    final libDir = await _runner.nativeLibDir();
    final loader32 = File('$libDir/libproot_loader32.so');
    final builder = ProotCommandBuilder(
      prootPath: '$libDir/libproot.so',
      loaderPath: '$libDir/libproot_loader.so',
      loader32Path: loader32.existsSync() ? loader32.path : null,
      rootfsPath: await _engine.rootfsPath(),
      tmpDirPath: await _engine.tmpDirPath(),
      extraBinds: [
        if (mountSdcard)
          for (final mount in sdcardGuestPaths)
            '${TerminalEngineManager.sdcardHostPath}:$mount',
      ],
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
    void Function(String chunk)? onOutput,
  }) async {
    final builder = await _commandBuilder();
    final result = await _runner.run(
      builder.build(
        command: ['/bin/sh', '-lc', command],
        workingDirectory: workingDirectory,
      ),
      timeout: timeout,
      cancelSignal: cancelSignal,
      onOutput: onOutput,
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
  Future<WorkspaceProcessSession> startProcess(
    String command, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final builder = await _commandBuilder();
    final env = environment ?? const <String, String>{};
    // 环境变量经 `env` 前缀注入 guest 侧（builder 的 environment 是 host
    // 侧 proot 进程的），值单引号包裹防止注入。
    final envPrefix = env.isEmpty
        ? ''
        : 'env ${env.entries.map((e) => '${e.key}=${_shellQuoteEnv(e.value)}').join(' ')} ';
    try {
      final session = await _runner.startProcess(
        builder.build(
          command: ['/bin/sh', '-lc', '$envPrefix$command'],
          workingDirectory: workingDirectory,
        ),
      );
      return _ProotProcessSession(session);
    } on TerminalEngineMissingException {
      rethrow;
    } catch (e) {
      throw ProotBackendException('启动进程失败 · $e');
    }
  }

  static String _shellQuoteEnv(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

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

/// [WorkspaceProcessSession] 适配：包一层 PRoot 的无 PTY 子进程会话。
class _ProotProcessSession implements WorkspaceProcessSession {
  _ProotProcessSession(this._session);

  final ProotProcessSession _session;

  @override
  Stream<List<int>> get stdout => _session.stdout;

  @override
  Stream<List<int>> get stderr => _session.stderr;

  @override
  void write(List<int> data) => _session.write(data);

  @override
  Future<void> get done => _session.done;

  @override
  int? get exitCode => _session.exitCode;

  @override
  Future<void> close() => _session.kill();
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
