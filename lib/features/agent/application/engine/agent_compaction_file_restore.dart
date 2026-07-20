/// 压缩后文件恢复（压缩升级计划 ⑥，对标 CC createPostCompactFileAttachments）：
/// 压缩把早期的文件读取结果折进摘要后，模型往往要重读同一批文件。
/// 这里在压缩落库时从**被覆盖区间**提取最近的文件读取快照（取事件里
/// 已有的 resultDetail，不做磁盘 IO），随 CompactionEvent 一起存储并
/// 注入上下文视图。与 CC 的差异：CC 压缩后从磁盘重读拿新鲜内容，
/// 我们取「模型压缩前实际看到的内容」——纯函数无 IO，两侧视图天然一致。
library;

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 最多恢复的文件数（对标 CC maxFiles=5）。
const int kCompactionRestoreMaxFiles = 5;

/// 单个文件快照的字符上限（超出截断，对标 CC 单文件 token 上限）。
const int kCompactionRestoreMaxCharsPerFile = 20000;

/// 全部快照的总字符预算（对标 CC POST_COMPACT_TOKEN_BUDGET）。
const int kCompactionRestoreTotalBudgetChars = 50000;

/// 从被覆盖区间选出要随压缩恢复的文件快照：
/// - 只取成功的 `read_file` 调用且输出未被 microcompact 清除；
/// - 同一路径取最近一次读取；kept 尾部已读过的路径跳过（模型还看得见）；
/// - 按最近优先，受 [maxFiles] 与 [totalBudgetChars] 双重约束，
///   单文件超 [maxCharsPerFile] 截断。
List<CompactionRestoredFile> selectRestoredFiles({
  required List<AgentEvent> covered,
  required List<AgentEvent> kept,
  int maxFiles = kCompactionRestoreMaxFiles,
  int maxCharsPerFile = kCompactionRestoreMaxCharsPerFile,
  int totalBudgetChars = kCompactionRestoreTotalBudgetChars,
}) {
  final keptPaths = <String>{
    for (final e in kept)
      if (e is ToolCallEvent) ..._readFilePaths(e),
  };

  // 同一路径取最近一次（covered 按时间升序，后者覆盖前者）。
  final latestByPath = <String, ToolCallEvent>{};
  for (final e in covered) {
    if (e is! ToolCallEvent) continue;
    if (e.toolName != 'read_file') continue;
    if (e.state != AgentToolCallState.success) continue;
    final detail = e.resultDetail;
    if (detail == null ||
        detail.isEmpty ||
        detail == kMicroCompactClearedPlaceholder) {
      continue;
    }
    for (final path in _readFilePaths(e)) {
      if (keptPaths.contains(path)) continue;
      latestByPath[path] = e;
    }
  }

  // 最近优先（seq 降序），双重预算内截取。
  final candidates = latestByPath.entries.toList()
    ..sort((a, b) => b.value.seq.compareTo(a.value.seq));
  final restored = <CompactionRestoredFile>[];
  final usedEventIds = <String>{};
  var usedChars = 0;
  for (final entry in candidates) {
    if (restored.length >= maxFiles) break;
    // 批量读取的一条事件覆盖多个路径：快照按事件存一次即可。
    if (!usedEventIds.add(entry.value.id)) continue;
    var content = entry.value.resultDetail!;
    if (content.length > maxCharsPerFile) {
      content = '${content.substring(0, maxCharsPerFile)}\n…（已截断）';
    }
    if (usedChars + content.length > totalBudgetChars) continue;
    usedChars += content.length;
    restored.add(CompactionRestoredFile(path: entry.key, content: content));
  }
  return restored;
}

/// 从 read_file 的参数 JSON 提取路径：单文件 `path` 或批量 `files[].path`。
List<String> _readFilePaths(ToolCallEvent event) {
  if (event.toolName != 'read_file') return const [];
  final raw = event.argsDetail;
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    final paths = <String>[];
    final single = decoded['path'];
    if (single is String && single.isNotEmpty) paths.add(single);
    final files = decoded['files'];
    if (files is List) {
      for (final f in files) {
        if (f is Map<String, dynamic>) {
          final p = f['path'];
          if (p is String && p.isNotEmpty) paths.add(p);
        }
      }
    }
    return paths;
  } on FormatException {
    return const [];
  }
}
