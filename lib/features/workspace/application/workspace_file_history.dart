// 应用级文件历史（checkpoint）——「没有 Git 仓库也能回滚」的本地快照层。
//
// 写入路径（编辑器保存、@aether/file-editor 的 write/edit）在覆盖文件前把
// **旧内容**存进应用私有目录，之后可以按文件查看历史、对比、一键恢复。
// 与 Git 完全无关，任何后端（包括 SAF）都可用；Git 是额外能力而非前提。
//
// 存储布局（应用支持目录下，随工作区隔离）：
//   <base>/file_history/<workspaceId>/index.json     快照元数据列表
//   <base>/file_history/<workspaceId>/objects/<hash>  按 sha256 去重的内容
//
// 上限：单文件快照 ≤ [kFileHistoryMaxBytes]；每个文件最多保留
// [kFileHistoryMaxPerFile] 份，超出裁掉最旧的并回收孤儿对象。

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';

/// Snapshots larger than this are not recorded (历史层针对文本源码，超大
/// 文件既慢又占空间，直接跳过).
const int kFileHistoryMaxBytes = 1024 * 1024;

/// Max snapshots kept per file path; older ones are pruned.
const int kFileHistoryMaxPerFile = 30;

/// One saved version of a file. [path] is the backend's opaque entry path
/// (POSIX path or SAF `content://` URI — treated as an opaque key).
class FileHistorySnapshot {
  const FileHistorySnapshot({
    required this.path,
    required this.savedAt,
    required this.size,
    required this.source,
    required this.hash,
  });

  factory FileHistorySnapshot.fromJson(Map<String, dynamic> json) =>
      FileHistorySnapshot(
        path: (json['path'] ?? '').toString(),
        savedAt: DateTime.tryParse((json['savedAt'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        size: (json['size'] as num?)?.toInt() ?? 0,
        source: (json['source'] ?? '').toString(),
        hash: (json['hash'] ?? '').toString(),
      );

  final String path;
  final DateTime savedAt;
  final int size;

  /// What produced the overwrite this snapshot predates（编辑器保存/智能体
  /// 写入/历史恢复），展示用。
  final String source;

  /// sha256 hex of the content; doubles as the object file name.
  final String hash;

  Map<String, dynamic> toJson() => {
        'path': path,
        'savedAt': savedAt.toIso8601String(),
        'size': size,
        'source': source,
        'hash': hash,
      };
}

/// Decodes an index.json body; malformed input degrades to an empty list.
List<FileHistorySnapshot> decodeFileHistoryIndex(String body) {
  try {
    final raw = jsonDecode(body);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) FileHistorySnapshot.fromJson(item),
    ];
  } catch (_) {
    return const [];
  }
}

String encodeFileHistoryIndex(List<FileHistorySnapshot> snapshots) =>
    jsonEncode([for (final s in snapshots) s.toJson()]);

/// Prunes [snapshots] so each path keeps at most [maxPerFile] newest entries.
/// Input order is preserved for the survivors.
List<FileHistorySnapshot> pruneFileHistory(
  List<FileHistorySnapshot> snapshots, {
  int maxPerFile = kFileHistoryMaxPerFile,
}) {
  // 每个 path 保留 savedAt 最新的 maxPerFile 份。
  final byPath = <String, List<FileHistorySnapshot>>{};
  for (final s in snapshots) {
    (byPath[s.path] ??= []).add(s);
  }
  final keep = <FileHistorySnapshot>{};
  for (final group in byPath.values) {
    final sorted = [...group]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    keep.addAll(sorted.take(maxPerFile));
  }
  return [
    for (final s in snapshots)
      if (keep.contains(s)) s,
  ];
}

/// The on-disk snapshot store for one workspace. All methods are best-effort
/// safe to call concurrently within one isolate（操作经内部队列串行化）。
class WorkspaceFileHistoryStore {
  WorkspaceFileHistoryStore({required this.baseDir});

  /// `<appSupport>/file_history/<workspaceId>` — injected so tests can point
  /// it at a temp dir.
  final Directory baseDir;

  Future<void> _queue = Future.value();

  File get _indexFile => File('${baseDir.path}/index.json');
  Directory get _objectsDir => Directory('${baseDir.path}/objects');

  /// Serializes mutating ops so index read-modify-write can't interleave.
  Future<T> _locked<T>(Future<T> Function() op) {
    final run = _queue.then((_) => op());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<List<FileHistorySnapshot>> _readIndex() async {
    try {
      return decodeFileHistoryIndex(await _indexFile.readAsString());
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeIndex(List<FileHistorySnapshot> snapshots) async {
    await baseDir.create(recursive: true);
    await _indexFile.writeAsString(encodeFileHistoryIndex(snapshots));
  }

  /// Records [content] as the pre-overwrite version of [path]. No-ops when
  /// the content is oversized or identical to the path's latest snapshot.
  Future<void> record(
    String path,
    String content, {
    required String source,
  }) {
    final bytes = utf8.encode(content);
    if (bytes.length > kFileHistoryMaxBytes) return Future.value();
    final hash = sha256.convert(bytes).toString();
    return _locked(() async {
      final index = await _readIndex();
      final latest = _latestFor(index, path);
      if (latest?.hash == hash) return;

      await _objectsDir.create(recursive: true);
      final object = File('${_objectsDir.path}/$hash');
      if (!await object.exists()) await object.writeAsBytes(bytes);

      final next = pruneFileHistory([
        ...index,
        FileHistorySnapshot(
          path: path,
          savedAt: DateTime.now(),
          size: bytes.length,
          source: source,
          hash: hash,
        ),
      ]);
      await _writeIndex(next);
      await _sweepOrphans(next);
    });
  }

  /// Snapshots of [path], newest first.
  Future<List<FileHistorySnapshot>> snapshotsFor(String path) async {
    final index = await _readIndex();
    final matches = [
      for (final s in index)
        if (s.path == path) s,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return matches;
  }

  /// The stored content of [snapshot]; null when its object is missing.
  Future<String?> read(FileHistorySnapshot snapshot) async {
    try {
      return await File('${_objectsDir.path}/${snapshot.hash}')
          .readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Deletes one snapshot record (its object is swept when unreferenced).
  Future<void> remove(FileHistorySnapshot snapshot) {
    return _locked(() async {
      final index = await _readIndex();
      final next = [
        for (final s in index)
          if (!(s.path == snapshot.path &&
              s.hash == snapshot.hash &&
              s.savedAt == snapshot.savedAt))
            s,
      ];
      await _writeIndex(next);
      await _sweepOrphans(next);
    });
  }

  static FileHistorySnapshot? _latestFor(
    List<FileHistorySnapshot> index,
    String path,
  ) {
    FileHistorySnapshot? latest;
    for (final s in index) {
      if (s.path != path) continue;
      if (latest == null || s.savedAt.isAfter(latest.savedAt)) latest = s;
    }
    return latest;
  }

  /// Deletes object files no snapshot references anymore.
  Future<void> _sweepOrphans(List<FileHistorySnapshot> index) async {
    final live = {for (final s in index) s.hash};
    try {
      await for (final entity in _objectsDir.list()) {
        if (entity is! File) continue;
        final name = entity.path.substring(entity.path.lastIndexOf('/') + 1);
        if (!live.contains(name)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

/// The history store for the currently opened workspace (null when none).
/// Store instances are cheap — state lives on disk — so one per workspace
/// switch is fine.
final workspaceFileHistoryProvider =
    FutureProvider<WorkspaceFileHistoryStore?>((ref) async {
  final workspace = ref.watch(currentWorkspaceProvider);
  if (workspace == null) return null;
  final support = await getApplicationSupportDirectory();
  return WorkspaceFileHistoryStore(
    baseDir: Directory('${support.path}/file_history/${workspace.id}'),
  );
});

/// Best-effort snapshot hook for write paths: records [oldContent] as the
/// pre-overwrite version of [path]. Never throws — 历史层挂掉不能影响正常
/// 保存。[store] is `ref.read(workspaceFileHistoryProvider.future)`（Ref 与
/// WidgetRef 调用点都适用）。
Future<void> recordFileHistory(
  Future<WorkspaceFileHistoryStore?> store,
  String path,
  String oldContent, {
  required String source,
}) async {
  try {
    await (await store)?.record(path, oldContent, source: source);
  } catch (_) {}
}
