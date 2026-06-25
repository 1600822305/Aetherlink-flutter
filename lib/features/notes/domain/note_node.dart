import 'package:flutter/foundation.dart';

/// Sort modes for the notes browser, mirroring Cherry Studio's six options
/// (`NotesSortType`). Folders always sort before files regardless of mode.
enum NotesSortType {
  nameAsc,
  nameDesc,
  updatedDesc,
  updatedAsc,
  createdDesc,
  createdAsc;

  /// The zh-CN label shown in the sort menu.
  String get label => switch (this) {
    NotesSortType.nameAsc => '名称（A→Z）',
    NotesSortType.nameDesc => '名称（Z→A）',
    NotesSortType.updatedDesc => '修改时间（新→旧）',
    NotesSortType.updatedAsc => '修改时间（旧→新）',
    NotesSortType.createdDesc => '创建时间（新→旧）',
    NotesSortType.createdAsc => '创建时间（旧→新）',
  };

  /// Parses a persisted [NotesSortType.name], defaulting to [nameAsc].
  static NotesSortType fromStorage(String? value) =>
      NotesSortType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => NotesSortType.nameAsc,
      );
}

/// A single node in the notes tree — either a folder or a `.md` note file.
///
/// Notes are stored as real files on disk (see `NotesFileStore`); this is the
/// in-memory projection the UI renders. `relativePath` is the forward-slash
/// path from the notes root and doubles as the stable identity (e.g. for
/// starred-state lookup), mirroring Cherry Studio's `(rootPath, path)` key.
@immutable
class NoteNode {
  const NoteNode({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    required this.modifiedAt,
    required this.createdAt,
    this.isStarred = false,
    this.size,
  });

  /// The on-disk entry name (folders as-is; files keep the `.md` extension).
  final String name;

  /// Forward-slash path relative to the notes root. Stable identity.
  final String relativePath;

  final bool isDirectory;
  final DateTime modifiedAt;
  final DateTime createdAt;
  final bool isStarred;
  final int? size;

  /// The name shown in the UI — files drop the trailing `.md`.
  String get title {
    if (isDirectory) return name;
    return name.toLowerCase().endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
  }

  NoteNode copyWith({bool? isStarred}) => NoteNode(
    name: name,
    relativePath: relativePath,
    isDirectory: isDirectory,
    modifiedAt: modifiedAt,
    createdAt: createdAt,
    isStarred: isStarred ?? this.isStarred,
    size: size,
  );
}
