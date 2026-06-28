import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_history.freezed.dart';

/// The kind of change recorded in a memory's audit trail.
enum MemoryAction { add, update, delete }

/// Stable wire strings for [MemoryAction], stored in the `action` column so the
/// log is human-readable (`ADD`/`UPDATE`/`DELETE`).
extension MemoryActionWire on MemoryAction {
  String get wire => switch (this) {
    MemoryAction.add => 'ADD',
    MemoryAction.update => 'UPDATE',
    MemoryAction.delete => 'DELETE',
  };

  static MemoryAction parse(String value) => switch (value) {
    'UPDATE' => MemoryAction.update,
    'DELETE' => MemoryAction.delete,
    _ => MemoryAction.add,
  };
}

/// One audited change to a memory: when [memoryId] was created, edited (manual
/// edit / move global↔private / 再巩固 rewrite) or soft-deleted. [previousValue]
/// / [newValue] hold the content before/after (null where not applicable: ADD
/// has no previous, DELETE has no new). Backs traceability and future undo.
@freezed
abstract class MemoryHistoryEntry with _$MemoryHistoryEntry {
  const factory MemoryHistoryEntry({
    required String memoryId,
    required MemoryAction action,
    String? previousValue,
    String? newValue,

    /// Epoch milliseconds when the change happened.
    @Default(0) int createdAt,

    /// The autoincrement row id, null until the entry is persisted.
    int? id,
  }) = _MemoryHistoryEntry;
}
