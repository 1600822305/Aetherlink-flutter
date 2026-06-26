// Parses the `apply_diff` payload (SEARCH/REPLACE or unified) into a
// renderable [LineDiff], mirroring the formats accepted by the SAF backend's
// DiffApplier (packages/aetherlink_saf/.../core/DiffApplier.kt).

import 'package:aetherlink_flutter/shared/utils/line_diff.dart';

const _markSearch = '<<<<<<< SEARCH';
const _markSep = '=======';
const _markReplace = '>>>>>>> REPLACE';

/// Parses a SEARCH/REPLACE [diff] into a [LineDiff]. Each block is diffed
/// independently (so unchanged lines inside a block render as context), and a
/// gap marker is inserted between blocks.
LineDiff parseSearchReplaceDiff(String diff) {
  final lines = diff.split('\n');
  final out = <DiffLine>[];
  var added = 0;
  var removed = 0;
  var blockCount = 0;

  var i = 0;
  while (i < lines.length) {
    if (lines[i].trimRight() != _markSearch) {
      i++;
      continue;
    }
    i++;
    final search = <String>[];
    var sawSep = false;
    while (i < lines.length) {
      if (lines[i].trimRight() == _markSep) {
        sawSep = true;
        i++;
        break;
      }
      search.add(lines[i]);
      i++;
    }
    if (!sawSep) break;
    final replace = <String>[];
    var sawEnd = false;
    while (i < lines.length) {
      if (lines[i].trimRight() == _markReplace) {
        sawEnd = true;
        i++;
        break;
      }
      replace.add(lines[i]);
      i++;
    }
    if (!sawEnd) break;

    if (blockCount > 0) out.add(const DiffLine(DiffLineType.context, '⋯'));
    blockCount++;

    final blockDiff =
        computeLineDiff(search.join('\n'), replace.join('\n'));
    out.addAll(blockDiff.lines);
    added += blockDiff.added;
    removed += blockDiff.removed;
  }

  return LineDiff(lines: out, added: added, removed: removed);
}

/// Parses a unified [diff] (with `@@ ... @@` hunk headers) into a [LineDiff].
LineDiff parseUnifiedDiff(String diff) {
  final out = <DiffLine>[];
  var added = 0;
  var removed = 0;
  var first = true;

  for (final raw in diff.split('\n')) {
    if (raw.startsWith('@@')) {
      if (!first) out.add(const DiffLine(DiffLineType.context, '⋯'));
      first = false;
      continue;
    }
    if (raw == '\\ No newline at end of file') continue;
    if (raw.startsWith('+')) {
      out.add(DiffLine(DiffLineType.added, raw.substring(1)));
      added++;
    } else if (raw.startsWith('-')) {
      out.add(DiffLine(DiffLineType.removed, raw.substring(1)));
      removed++;
    } else if (raw.startsWith(' ')) {
      out.add(DiffLine(DiffLineType.context, raw.substring(1)));
    } else if (raw.isEmpty) {
      // tolerate blank padding lines
    } else {
      out.add(DiffLine(DiffLineType.context, raw));
    }
  }

  return LineDiff(lines: out, added: added, removed: removed);
}

/// Parses [diff] according to [unified]; falls back gracefully on malformed
/// input by returning whatever was parsed.
LineDiff parseDiffPayload(String diff, {required bool unified}) =>
    unified ? parseUnifiedDiff(diff) : parseSearchReplaceDiff(diff);
