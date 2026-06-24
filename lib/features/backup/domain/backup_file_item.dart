/// Represents a backup file stored either locally or on a remote server.
class BackupFileItem {
  /// Absolute URI (remote) or file path (local).
  final Uri href;

  /// Human-readable file name.
  final String displayName;

  /// File size in bytes.
  final int size;

  /// Last modified time (from server or file system).
  final DateTime? lastModified;

  /// Whether this is an auto-created backup (pre-restore safety net, etc.).
  final bool isAuto;

  const BackupFileItem({
    required this.href,
    required this.displayName,
    this.size = 0,
    this.lastModified,
    this.isAuto = false,
  });

  /// Human-readable file size string.
  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
