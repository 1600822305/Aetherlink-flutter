import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';

/// A migratable data category in a backup.
///
/// Mirrors the database tables / setting sections the importer can write into.
/// Used both for the pre-restore checklist (what the user can choose to import)
/// and for the post-restore reconciliation report (源/目标 对数校验).
enum BackupCategory {
  topics,
  messages,
  messageBlocks,
  assistants,
  providers,
  groups,
  settings,
  memories,
}

extension BackupCategoryX on BackupCategory {
  /// Categories this one directly depends on. In overwrite restores a child
  /// whose parent isn't also restored would reference a record that no longer
  /// exists (orphan), so the checklist keeps these linked.
  ///
  /// Chain: messageBlocks → messages → topics.
  Set<BackupCategory> get directDependencies {
    switch (this) {
      case BackupCategory.messages:
        return {BackupCategory.topics};
      case BackupCategory.messageBlocks:
        return {BackupCategory.messages};
      case BackupCategory.topics:
      case BackupCategory.assistants:
      case BackupCategory.providers:
      case BackupCategory.groups:
      case BackupCategory.settings:
      case BackupCategory.memories:
        return const {};
    }
  }

  /// Transitive closure of [directDependencies] (parents this category needs).
  Set<BackupCategory> get requiredAncestors {
    final result = <BackupCategory>{};
    final queue = [...directDependencies];
    while (queue.isNotEmpty) {
      final c = queue.removeLast();
      if (result.add(c)) queue.addAll(c.directDependencies);
    }
    return result;
  }

  /// Categories that depend (transitively) on this one — its descendants.
  Set<BackupCategory> get dependentDescendants => BackupCategory.values
      .where((c) => c.requiredAncestors.contains(this))
      .toSet();

  /// Human-readable label shown in the selection checklist and result report.
  String get label {
    switch (this) {
      case BackupCategory.topics:
        return '话题';
      case BackupCategory.messages:
        return '消息';
      case BackupCategory.messageBlocks:
        return '消息块';
      case BackupCategory.assistants:
        return '助手';
      case BackupCategory.providers:
        return '模型供应商 / 模型';
      case BackupCategory.groups:
        return '分组';
      case BackupCategory.settings:
        return '设置';
      case BackupCategory.memories:
        return '记忆';
    }
  }
}

/// Long-term memory and other data the Web app exports but Flutter has no
/// table for. Surfaced (greyed out) in the checklist so the user knows exactly
/// what will be dropped instead of silently losing it.
class UnsupportedCategory {
  /// Display name, e.g. "知识库".
  final String name;

  /// Number of records found in the backup.
  final int count;

  /// Why it can't be imported, shown as a hint.
  final String reason;

  const UnsupportedCategory({
    required this.name,
    required this.count,
    required this.reason,
  });
}

/// Result of scanning a backup file before restore.
///
/// Lists how many records of each supported category are present plus any
/// unsupported categories the backup carries. Drives the selection checklist.
class BackupScan {
  /// True for a Web-exported JSON backup, false for a Flutter ZIP backup.
  final bool isWebFormat;

  /// Manifest (ZIP) or a synthesized one (Web). May be null if unavailable.
  final BackupManifest? manifest;

  /// Per-category importable record counts. Categories with a count of 0 are
  /// still present in the map.
  final Map<BackupCategory, int> available;

  /// Categories the backup carries but Flutter cannot import.
  final List<UnsupportedCategory> unsupported;

  const BackupScan({
    required this.isWebFormat,
    this.manifest,
    required this.available,
    this.unsupported = const [],
  });

  /// Categories with at least one importable record, in enum order.
  List<BackupCategory> get presentCategories => BackupCategory.values
      .where((c) => (available[c] ?? 0) > 0)
      .toList(growable: false);

  int countOf(BackupCategory c) => available[c] ?? 0;

  /// Total importable records across all supported categories.
  int get totalRecords =>
      available.values.fold(0, (sum, v) => sum + v);
}

/// The user's restore choices: which categories to import and the conflict
/// strategy. A null selection elsewhere means "import everything".
class RestoreSelection {
  final Set<BackupCategory> categories;
  final RestoreMode mode;

  const RestoreSelection({
    required this.categories,
    this.mode = RestoreMode.overwrite,
  });

  /// Selects every supported category present in [scan].
  factory RestoreSelection.all(
    BackupScan scan, {
    RestoreMode mode = RestoreMode.overwrite,
  }) {
    return RestoreSelection(
      categories: scan.presentCategories.toSet(),
      mode: mode,
    );
  }

  bool includes(BackupCategory c) => categories.contains(c);

  bool get isEmpty => categories.isEmpty;
}

/// Streaming progress emitted while a single category is being written, so the
/// UI can show a live per-category progress bar during large restores.
class RestoreProgress {
  final BackupCategory category;
  final int done;
  final int total;

  const RestoreProgress(this.category, this.done, this.total);

  double get fraction => total == 0 ? 1.0 : done / total;
}

/// Per-category reconciliation stats produced by a restore.
///
/// [source] is how many records the backup carried for the category; [target]
/// is how many were actually written. [reconciled] is the 对数校验 check: the
/// write count should cover everything that wasn't intentionally skipped.
class CategoryStat {
  final int source;
  final int succeeded;
  final int skipped;
  final int failed;

  const CategoryStat({
    this.source = 0,
    this.succeeded = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  int get target => succeeded;

  bool get reconciled => failed == 0 && target >= source - skipped;
}
