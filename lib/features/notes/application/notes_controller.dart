import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/notes/data/notes_file_store.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';

part 'notes_controller.g.dart';

/// Persisted-preference keys (single Drift KV store, no schema change).
const String kNotesSortTypeKey = 'notes.sortType';
const String kNotesStarredPathsKey = 'notes.starredPaths';
const String kNotesStoragePathKey = 'notes.storagePath';

/// The user-chosen notes storage directory (absolute path), or `null` for the
/// default app-documents location. Persisted in the KV store; reactive so the
/// file store + browser rebuild when it changes.
@Riverpod(keepAlive: true)
class NotesStoragePath extends _$NotesStoragePath {
  ChatRepository get _store => ref.read(appSettingsStoreProvider);

  @override
  String? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final value = await _store.getSetting(kNotesStoragePathKey);
    if (value != null && value.isNotEmpty) state = value;
  }

  /// Sets (or clears, when null/empty) the custom storage directory.
  Future<void> setPath(String? path) async {
    final next = (path != null && path.trim().isNotEmpty) ? path.trim() : null;
    state = next;
    await _store.saveSetting(kNotesStoragePathKey, next ?? '');
  }
}

/// The filesystem-backed notes store. Rebuilt when the storage path changes.
@Riverpod(keepAlive: true)
NotesFileStore notesFileStore(Ref ref) =>
    NotesFileStore(customRoot: ref.watch(notesStoragePathProvider));

/// Immutable view-model for the notes browser.
@immutable
class NotesState {
  const NotesState({
    this.currentPath = '',
    this.items = const <NoteNode>[],
    this.sort = NotesSortType.nameAsc,
    this.loading = true,
    this.starred = const <String>{},
  });

  /// Current folder, forward-slash relative path (`''` = root).
  final String currentPath;

  /// Folders + notes in [currentPath], already sorted and star-merged.
  final List<NoteNode> items;
  final NotesSortType sort;
  final bool loading;

  /// Starred note relative paths.
  final Set<String> starred;

  bool get isRoot => currentPath.isEmpty;

  /// Breadcrumb segments from root to [currentPath]: (label, path) pairs.
  List<({String label, String path})> get breadcrumbs {
    final crumbs = <({String label, String path})>[(label: '笔记', path: '')];
    if (currentPath.isEmpty) return crumbs;
    final parts = currentPath.split('/');
    var acc = '';
    for (final part in parts) {
      acc = acc.isEmpty ? part : '$acc/$part';
      crumbs.add((label: part, path: acc));
    }
    return crumbs;
  }

  NotesState copyWith({
    String? currentPath,
    List<NoteNode>? items,
    NotesSortType? sort,
    bool? loading,
    Set<String>? starred,
  }) => NotesState(
    currentPath: currentPath ?? this.currentPath,
    items: items ?? this.items,
    sort: sort ?? this.sort,
    loading: loading ?? this.loading,
    starred: starred ?? this.starred,
  );
}

/// Drives the notes browser: folder navigation, sorting, starring and CRUD.
///
/// Kept alive so the browsing position survives opening/closing the editor.
@Riverpod(keepAlive: true)
class NotesController extends _$NotesController {
  ChatRepository get _store => ref.read(appSettingsStoreProvider);
  NotesFileStore get _files => ref.read(notesFileStoreProvider);

  @override
  NotesState build() {
    // Rebuild + reload from the root when the storage directory changes.
    ref.watch(notesFileStoreProvider);
    _hydrate();
    return const NotesState();
  }

  Future<void> _hydrate() async {
    final sort = NotesSortType.fromStorage(
      await _store.getSetting(kNotesSortTypeKey),
    );
    final starred = _decodeStarred(
      await _store.getSetting(kNotesStarredPathsKey),
    );
    state = state.copyWith(sort: sort, starred: starred);
    await _load(state.currentPath);
  }

  Set<String> _decodeStarred(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>{};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } on FormatException {
      return const <String>{};
    }
  }

  Future<void> _load(String path) async {
    state = state.copyWith(loading: true);
    final raw = await _files.list(path);
    final merged = [
      for (final node in raw)
        node.copyWith(isStarred: state.starred.contains(node.relativePath)),
    ]..sort(_compare);
    state = state.copyWith(currentPath: path, items: merged, loading: false);
  }

  int _compare(NoteNode a, NoteNode b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return switch (state.sort) {
      NotesSortType.nameAsc =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      NotesSortType.nameDesc =>
        b.title.toLowerCase().compareTo(a.title.toLowerCase()),
      NotesSortType.updatedDesc => b.modifiedAt.compareTo(a.modifiedAt),
      NotesSortType.updatedAsc => a.modifiedAt.compareTo(b.modifiedAt),
      NotesSortType.createdDesc => b.createdAt.compareTo(a.createdAt),
      NotesSortType.createdAsc => a.createdAt.compareTo(b.createdAt),
    };
  }

  /// Reloads the current folder (e.g. after returning from the editor).
  Future<void> refresh() => _load(state.currentPath);

  Future<void> enterFolder(NoteNode folder) => _load(folder.relativePath);

  Future<void> goTo(String path) => _load(path);

  Future<void> goUp() {
    if (state.currentPath.isEmpty) return Future.value();
    final parent = state.currentPath.contains('/')
        ? state.currentPath.substring(0, state.currentPath.lastIndexOf('/'))
        : '';
    return _load(parent);
  }

  Future<void> setSort(NotesSortType sort) async {
    state = state.copyWith(sort: sort, items: [...state.items]..sort(_compare));
    await _store.saveSetting(kNotesSortTypeKey, sort.name);
  }

  Future<void> toggleStar(NoteNode node) async {
    if (node.isDirectory) return;
    final next = {...state.starred};
    if (!next.add(node.relativePath)) next.remove(node.relativePath);
    final items = [
      for (final n in state.items)
        n.relativePath == node.relativePath
            ? n.copyWith(isStarred: next.contains(n.relativePath))
            : n,
    ];
    state = state.copyWith(starred: next, items: items);
    await _store.saveSetting(kNotesStarredPathsKey, jsonEncode(next.toList()));
  }

  /// Creates a note in the current folder; returns its relative path.
  Future<String> createNote(String name) async {
    final relPath = await _files.createNote(state.currentPath, name);
    await refresh();
    return relPath;
  }

  Future<void> createFolder(String name) async {
    await _files.createFolder(state.currentPath, name);
    await refresh();
  }

  /// Imports external `.md` files into the current folder; returns the count.
  Future<int> importFiles(List<String> sourcePaths) async {
    final count = await _files.importFiles(state.currentPath, sourcePaths);
    await refresh();
    return count;
  }

  /// Imports an external folder (preserving its subtree) into the current
  /// folder; returns the number of `.md` files imported.
  Future<int> importFolder(String sourceDirPath) async {
    final count = await _files.importFolder(state.currentPath, sourceDirPath);
    await refresh();
    return count;
  }

  Future<void> rename(NoteNode node, String newName) async {
    await _files.rename(node.relativePath, node.isDirectory, newName);
    await refresh();
  }

  Future<void> delete(NoteNode node) async {
    await _files.delete(node.relativePath, node.isDirectory);
    // Drop any starred entry for the deleted path.
    if (state.starred.contains(node.relativePath)) {
      final next = {...state.starred}..remove(node.relativePath);
      state = state.copyWith(starred: next);
      await _store.saveSetting(kNotesStarredPathsKey, jsonEncode(next.toList()));
    }
    await refresh();
  }
}
