// Session-scoped read-state registry for the `@aether/file-editor` tools —
// the port of Claude Code's `readFileState`.
//
// Records, per (session, resolved path), the file metadata (mtime + size) and
// the requested range of the last successful `read_file`. Two consumers:
//
// - `read_file` 去重：同会话、同路径、同范围且文件未变化（mtime + size 均相同）
//   的重复读取返回一个轻量「文件未变化」存根，不重发全文，省上下文 token；
// - `edit`/`write` 陈旧检测：本会话读过的文件若在读取后被外部修改
//   （mtime 变化），拒绝基于过期认知的改动，要求先重读。
//
// 会话键取聊天话题 / 智能体任务 ID；未知来源用空串共享一个兜底会话。
// mtime 在部分后端（如 SAF）精度有限，所以去重同时要求 size 相同，
// mtime 为 0（后端不提供）时两种机制都直接跳过。

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a session knows about a file from its last `read_file`.
class FileReadRecord {
  const FileReadRecord({
    required this.mtime,
    required this.size,
    this.startLine,
    this.endLine,
    this.withLineNumbers = true,
    this.dedupEligible = true,
    this.contentHash,
  });

  final int mtime;
  final int size;

  /// The requested range of the recorded read (null = whole file).
  final int? startLine;
  final int? endLine;
  final bool withLineNumbers;

  /// sha256 of the full content this session last saw for the file（整文件
  /// 读取或本会话写入时记录；范围读取为 null）。陈旧检测在 mtime 变化时用它
  /// 做内容比对兜底——云同步/杀软等只动 mtime 不动内容的场景不误拦。
  final String? contentHash;

  /// Whether this record represents only a partial view of the file
  /// (a range read rather than the whole content).
  bool get isPartialView => startLine != null || endLine != null;

  /// False after this session itself wrote the file: the mtime is fresh (so
  /// the staleness guard stays quiet) but the previously-returned content is
  /// no longer what's on disk, so a re-read must return the real content.
  final bool dedupEligible;
}

/// Whether a `read_file` call may be answered with a「文件未变化」stub instead
/// of the full content: the exact same request was already served to this
/// session and the file hasn't changed since.
bool isDuplicateRead(
  FileReadRecord? record, {
  required int mtime,
  required int size,
  int? startLine,
  int? endLine,
  bool withLineNumbers = true,
}) =>
    record != null &&
    record.dedupEligible &&
    mtime != 0 &&
    record.mtime == mtime &&
    record.size == size &&
    record.startLine == startLine &&
    record.endLine == endLine &&
    record.withLineNumbers == withLineNumbers;

/// Whether a mutation must be refused because the file changed after this
/// session last read it (an external edit — user, formatter, another agent).
/// Files never read this session are not blocked here — the read-first
/// guard in the write handlers covers that case with a clearer error.
///
/// [currentContentHash]（当前磁盘内容的 sha256，可选）提供内容比对兜底：
/// mtime 变了但内容 hash 与记录一致时不算陈旧（云同步/杀软只碰 mtime）。
bool isStaleForEdit(
  FileReadRecord? record, {
  required int mtime,
  String? currentContentHash,
}) =>
    record != null &&
    record.mtime != 0 &&
    mtime != 0 &&
    record.mtime != mtime &&
    (record.contentHash == null ||
        currentContentHash == null ||
        record.contentHash != currentContentHash);

/// In-memory, app-lifetime store of [FileReadRecord]s, LRU-capped per session
/// and across sessions so long-running apps can't grow it unboundedly.
class FileReadStateStore {
  static const int kMaxPathsPerSession = 500;
  static const int kMaxSessions = 64;

  // Insertion order doubles as LRU order (re-insert on touch).
  final Map<String, Map<String, FileReadRecord>> _sessions = {};

  FileReadRecord? lookup(String session, String path) =>
      _sessions[session]?[path];

  void record(String session, String path, FileReadRecord record) {
    final files = _sessions.remove(session) ?? <String, FileReadRecord>{};
    _sessions[session] = files;
    if (_sessions.length > kMaxSessions) {
      _sessions.remove(_sessions.keys.first);
    }
    files.remove(path);
    files[path] = record;
    if (files.length > kMaxPathsPerSession) {
      files.remove(files.keys.first);
    }
  }

  /// Updates a file's metadata after this session itself wrote it: keeps the
  /// staleness guard in sync with the new mtime while disqualifying the old
  /// content from read-dedup. Records even when the session never read the
  /// file — a file this session created/wrote counts as "known", so the
  /// read-first guard won't force a redundant re-read before the next edit.
  /// [contentHash]（刚写入内容的 sha256）供陈旧检测的内容比对兜底。
  void refreshAfterWrite(
    String session,
    String path, {
    required int mtime,
    required int size,
    String? contentHash,
  }) {
    final existing = lookup(session, path);
    record(
      session,
      path,
      FileReadRecord(
        mtime: mtime,
        size: size,
        startLine: existing?.startLine,
        endLine: existing?.endLine,
        withLineNumbers: existing?.withLineNumbers ?? true,
        dedupEligible: false,
        contentHash: contentHash ?? existing?.contentHash,
      ),
    );
  }
}

/// App-lifetime singleton store (state must survive provider rebuilds within
/// a chat turn, so this is intentionally not auto-disposed).
final fileReadStateProvider =
    Provider<FileReadStateStore>((_) => FileReadStateStore());
