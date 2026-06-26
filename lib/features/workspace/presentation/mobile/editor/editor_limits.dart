// Centralized size / line thresholds for the file editor.
//
// These were previously scattered as private constants inside the editor
// widgets. Collecting them here keeps the "what can we safely open?" policy
// auditable in one place — and lets [classifyOpen] (file_open_policy.dart) and
// the widgets share the exact same numbers.

/// Hard ceiling: files larger than this are refused outright (a placeholder is
/// shown and **no** bytes are read into the editor).
const int kMaxOpenBytes = 20 * 1024 * 1024;

/// At or below this size a text file opens whole and is editable. Between this
/// and [kMaxOpenBytes] it opens as a read-only ranged preview (first
/// [kPreviewLines] lines) so a multi-megabyte file never lands in the field in
/// full.
const int kEditableMaxBytes = 2 * 1024 * 1024;

/// How many leading bytes we sniff to decide text-vs-binary. Small enough to
/// stay instant, large enough to catch a NUL / invalid UTF-8 early.
const int kHeaderProbeBytes = 8 * 1024;

/// Read-only preview length (in lines) for large-but-allowed files.
const int kPreviewLines = 5000;

/// Lines longer than this flip the text area into a soft-wrap fallback, so a
/// single pathologically long line (e.g. minified JS, a one-line JSON blob)
/// can't trigger an enormous non-wrapping layout pass that freezes the UI.
const int kMaxLineLength = 5000;
