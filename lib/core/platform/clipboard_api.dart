/// Reads from and writes to the system clipboard.
///
/// Implemented with Flutter's built-in `Clipboard` (zero plugins) under
/// `impl/`. The interface still exists so the UI never couples directly to
/// `flutter/services` and tests can substitute a fake (ADR-0007).
abstract interface class ClipboardApi {
  Future<void> copyText(String text);

  /// Returns the current plain-text clipboard contents, or null if empty.
  Future<String?> readText();
}
