import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_search_result.dart';

part 'notes_search_controller.g.dart';

/// View-model for the notes full-text search bar.
@immutable
class NotesSearchState {
  const NotesSearchState({
    this.active = false,
    this.keyword = '',
    this.loading = false,
    this.results = const <NoteSearchResult>[],
  });

  /// Whether the search bar is shown (replaces the folder listing once a
  /// keyword is entered).
  final bool active;
  final String keyword;
  final bool loading;
  final List<NoteSearchResult> results;

  bool get hasQuery => keyword.trim().isNotEmpty;

  NotesSearchState copyWith({
    bool? active,
    String? keyword,
    bool? loading,
    List<NoteSearchResult>? results,
  }) => NotesSearchState(
    active: active ?? this.active,
    keyword: keyword ?? this.keyword,
    loading: loading ?? this.loading,
    results: results ?? this.results,
  );
}

/// Debounced (300ms) full-text search over the notes tree, with a monotonic
/// token so stale async results are discarded.
@riverpod
class NotesSearchController extends _$NotesSearchController {
  Timer? _debounce;
  int _token = 0;

  @override
  NotesSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const NotesSearchState();
  }

  /// Opens the search bar.
  void open() => state = state.copyWith(active: true);

  /// Closes the search bar and clears the query/results.
  void close() {
    _debounce?.cancel();
    _token++;
    state = const NotesSearchState();
  }

  /// Updates the query and runs a debounced search.
  void search(String keyword) {
    state = state.copyWith(keyword: keyword);
    _debounce?.cancel();
    if (keyword.trim().isEmpty) {
      _token++;
      state = state.copyWith(loading: false, results: const <NoteSearchResult>[]);
      return;
    }
    state = state.copyWith(loading: true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(keyword));
  }

  Future<void> _run(String keyword) async {
    final token = ++_token;
    final store = ref.read(notesFileStoreProvider);
    final results = await store.search(keyword);
    if (token != _token) return; // a newer query superseded this one
    state = state.copyWith(loading: false, results: results);
  }
}
