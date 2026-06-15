/// Shares text and files through the OS share sheet.
///
/// Implemented with `share_plus` under `impl/`. The interface stays pure Dart
/// so callers and tests depend on the abstraction only (ADR-0007).
abstract interface class ShareApi {
  Future<void> shareText(String text, {String? subject});

  /// Shares one or more files identified by absolute path.
  Future<void> shareFiles(List<String> paths, {String? text, String? subject});
}
