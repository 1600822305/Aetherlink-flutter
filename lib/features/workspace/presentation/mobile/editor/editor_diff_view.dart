// 外部修改冲突的 diff 视图：按行对比「当前编辑内容」与「磁盘最新内容」，
// 底部动作条选择重新加载磁盘版或保留本地编辑。
//
// 行 diff 是纯逻辑（common prefix/suffix 裁剪 + 中段 LCS，超大中段退化为
// 整块替换以保证 O(n) 内存可控），与 UI 分离，可单测/复用。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum DiffLineKind { context, removed, added, skip }

/// One row of the diff view. [removed] rows exist only in the local buffer,
/// [added] rows only on disk; [skip] is a collapsed unchanged region.
class DiffLine {
  const DiffLine(this.kind, this.text, {this.oldLine, this.newLine});

  final DiffLineKind kind;
  final String text;

  /// 1-based line numbers in the local buffer / the disk content.
  final int? oldLine;
  final int? newLine;
}

/// LCS-based line diff of [oldText] (local buffer) → [newText] (disk), with
/// unchanged runs collapsed to [context] lines around each change. When the
/// changed middle exceeds [maxLcsCells] LCS cells it degrades to one whole
/// remove-block + add-block (still correct, just less minimal).
List<DiffLine> computeLineDiff(
  String oldText,
  String newText, {
  int context = 2,
  int maxLcsCells = 4000000,
}) {
  final a = oldText.split('\n');
  final b = newText.split('\n');

  // Trim the common prefix / suffix so LCS only sees the changed middle.
  var pre = 0;
  while (pre < a.length && pre < b.length && a[pre] == b[pre]) {
    pre++;
  }
  var suf = 0;
  while (suf < a.length - pre &&
      suf < b.length - pre &&
      a[a.length - 1 - suf] == b[b.length - 1 - suf]) {
    suf++;
  }
  final aMid = a.sublist(pre, a.length - suf);
  final bMid = b.sublist(pre, b.length - suf);

  // Raw ops over the middle: -1 removed, +1 added, 0 equal.
  final ops = <(int, String)>[];
  if (aMid.isEmpty && bMid.isEmpty) {
    // texts identical
  } else if (aMid.length * bMid.length > maxLcsCells ||
      aMid.isEmpty ||
      bMid.isEmpty) {
    for (final l in aMid) {
      ops.add((-1, l));
    }
    for (final l in bMid) {
      ops.add((1, l));
    }
  } else {
    ops.addAll(_lcsOps(aMid, bMid));
  }

  // Assemble: leading context from the prefix, the middle ops, trailing
  // context from the suffix, collapsing long unchanged runs.
  final rows = <DiffLine>[];
  var oldLine = 1;
  var newLine = 1;

  void emitEqualRun(List<String> lines, {required bool leading, required bool trailing}) {
    if (lines.isEmpty) return;
    final head = leading ? 0 : context;
    final tail = trailing ? 0 : context;
    if (lines.length <= head + tail + 1) {
      for (final l in lines) {
        rows.add(DiffLine(DiffLineKind.context, l,
            oldLine: oldLine, newLine: newLine));
        oldLine++;
        newLine++;
      }
      return;
    }
    for (var i = 0; i < lines.length; i++) {
      final nearHead = !leading && i < context;
      final nearTail = !trailing && i >= lines.length - context;
      if (nearHead || nearTail) {
        rows.add(DiffLine(DiffLineKind.context, lines[i],
            oldLine: oldLine, newLine: newLine));
      } else if (rows.isEmpty || rows.last.kind != DiffLineKind.skip) {
        rows.add(const DiffLine(DiffLineKind.skip, ''));
      }
      oldLine++;
      newLine++;
    }
  }

  emitEqualRun(a.sublist(0, pre), leading: true, trailing: false);

  var equalRun = <String>[];
  void flushEqual({required bool trailing}) {
    emitEqualRun(equalRun, leading: false, trailing: trailing);
    equalRun = <String>[];
  }

  for (final (op, line) in ops) {
    if (op == 0) {
      equalRun.add(line);
      continue;
    }
    flushEqual(trailing: false);
    if (op < 0) {
      rows.add(DiffLine(DiffLineKind.removed, line, oldLine: oldLine));
      oldLine++;
    } else {
      rows.add(DiffLine(DiffLineKind.added, line, newLine: newLine));
      newLine++;
    }
  }
  flushEqual(trailing: suf == 0);

  emitEqualRun(a.sublist(a.length - suf), leading: false, trailing: true);
  return rows;
}

// Standard LCS DP over the (already trimmed) middle, backtracked into ops.
List<(int, String)> _lcsOps(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  final ops = <(int, String)>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      ops.add((0, a[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      ops.add((-1, a[i]));
      i++;
    } else {
      ops.add((1, b[j]));
      j++;
    }
  }
  while (i < n) {
    ops.add((-1, a[i]));
    i++;
  }
  while (j < m) {
    ops.add((1, b[j]));
    j++;
  }
  return ops;
}

/// What the user chose in the conflict diff sheet.
enum DiffResolution { reloadDisk, keepMine }

/// Full-height bottom sheet showing the line diff between the unsaved local
/// buffer ([local], red `-` rows) and the latest disk content ([disk], green
/// `+` rows). Resolves to a [DiffResolution], or null when simply closed.
Future<DiffResolution?> showConflictDiffSheet(
  BuildContext context, {
  required String fileName,
  required String local,
  required String disk,
}) {
  return showModalBottomSheet<DiffResolution>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ConflictDiffSheet(
      fileName: fileName,
      local: local,
      disk: disk,
    ),
  );
}

class _ConflictDiffSheet extends StatelessWidget {
  const _ConflictDiffSheet({
    required this.fileName,
    required this.local,
    required this.disk,
  });

  final String fileName;
  final String local;
  final String disk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = computeLineDiff(local, disk);
    final changes = rows
        .where((r) =>
            r.kind == DiffLineKind.added || r.kind == DiffLineKind.removed)
        .length;
    final numStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Icon(LucideIcons.fileDiff,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '红色 - 为你的未保存编辑，绿色 + 为磁盘新内容（共 $changes 处差异行）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      '两个版本内容一致',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) =>
                        _diffRow(theme, rows[i], numStyle),
                  ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(DiffResolution.keepMine),
                    child: const Text('保留我的编辑'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(DiffResolution.reloadDisk),
                    child: const Text('加载磁盘版本'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diffRow(ThemeData theme, DiffLine row, TextStyle numStyle) {
    if (row.kind == DiffLineKind.skip) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Text('⋯', style: numStyle),
      );
    }
    final (bg, fg, sign) = switch (row.kind) {
      DiffLineKind.removed => (
          theme.colorScheme.errorContainer.withValues(alpha: 0.45),
          theme.colorScheme.onErrorContainer,
          '-',
        ),
      DiffLineKind.added => (
          Colors.green.withValues(alpha: 0.18),
          theme.colorScheme.onSurface,
          '+',
        ),
      _ => (Colors.transparent, theme.colorScheme.onSurfaceVariant, ' '),
    };
    final lineNo = row.kind == DiffLineKind.added ? row.newLine : row.oldLine;
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text('$lineNo', style: numStyle, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
          Text(sign,
              style: numStyle.copyWith(color: fg, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              row.text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
