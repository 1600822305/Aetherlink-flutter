// Pure, widget-free policy for "how should the editor open this file?".
//
// Kept free of Flutter imports so the decision (and the binary sniff) is easy
// to reason about and unit-test. The editor reads a file's size + a small
// header probe and asks [classifyOpen]; everything UI-facing (placeholders,
// banners) is derived from the returned [FileOpenKind].

import 'dart:convert';

import 'editor_limits.dart';

/// How a file should be presented, decided from its size and a header probe.
enum FileOpenKind {
  /// Small text file: load whole and (on a writable backend) allow editing.
  editable,

  /// Large-but-allowed text file: load a read-only ranged preview only.
  rangedReadOnly,

  /// Detected as binary (NUL byte or invalid UTF-8): show a placeholder, the
  /// content never enters the text field.
  binary,

  /// Over the hard size cap: refused outright, not even read.
  tooLarge,
}

/// Decides how to open a file from its [size] and a [head] probe (the first
/// [kHeaderProbeBytes] bytes, or fewer for short files).
///
/// Order matters: the size cap is checked first (so we never sniff a huge
/// file), then binary detection (so a small `.so`/`.dex` is caught), then the
/// editable-vs-preview size split.
FileOpenKind classifyOpen({required int size, required List<int> head}) {
  if (size > kMaxOpenBytes) return FileOpenKind.tooLarge;
  if (looksBinary(head)) return FileOpenKind.binary;
  if (size > kEditableMaxBytes) return FileOpenKind.rangedReadOnly;
  return FileOpenKind.editable;
}

/// Content-based binary heuristic over a file's leading [head] bytes:
///
///  * any NUL (`0x00`) byte → binary (text files never contain NUL); or
///  * the bytes don't strictly decode as UTF-8.
///
/// Because [head] is only a prefix, a multi-byte UTF-8 sequence may be cut off
/// at the boundary; an invalid sequence in the last 3 bytes is therefore
/// tolerated rather than misreported as binary.
bool looksBinary(List<int> head) {
  if (head.isEmpty) return false;
  for (final b in head) {
    if (b == 0) return true;
  }
  try {
    const Utf8Decoder(allowMalformed: false).convert(head);
    return false;
  } on FormatException catch (e) {
    final offset = e.offset;
    // A bad byte right at the end is most likely a truncated trailing
    // multi-byte char (we only read a prefix), not real binary data.
    if (offset != null && offset >= head.length - 3) return false;
    return true;
  }
}
