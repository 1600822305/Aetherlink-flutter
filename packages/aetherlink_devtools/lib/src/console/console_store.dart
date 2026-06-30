import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';

/// The Console panel's data layer: a bounded ring buffer of [LogEntry] plus the
/// active filter, exposed as [ValueListenable]s the UI listens to.
///
/// Use the [instance] singleton. The global capture hooks
/// ([installConsoleCapture]) feed it; the panel reads [entries]/[filtered]. It
/// is dependency-free (no Riverpod) so the package stays self-contained, exactly
/// like `aetherlink_perf`'s monitor.
class ConsoleStore {
  ConsoleStore._();

  static final ConsoleStore instance = ConsoleStore._();

  /// Hard cap on retained lines (oldest dropped first). Bounded so a chatty app
  /// can run indefinitely without unbounded memory growth.
  static const int maxEntries = 2000;

  final ListQueue<LogEntry> _buffer = ListQueue<LogEntry>();
  int _nextId = 0;

  final ValueNotifier<List<LogEntry>> _entries =
      ValueNotifier<List<LogEntry>>(const <LogEntry>[]);
  final ValueNotifier<ConsoleFilter> _filter =
      ValueNotifier<ConsoleFilter>(const ConsoleFilter());

  /// All retained entries, oldest → newest.
  ValueListenable<List<LogEntry>> get entries => _entries;

  /// The active filter (levels + search text).
  ValueListenable<ConsoleFilter> get filter => _filter;

  /// Appends a captured line. Assigns a monotonic id and trims to [maxEntries].
  void add({
    required LogLevel level,
    required String message,
    String? context,
    String? stackTrace,
  }) {
    _buffer.add(
      LogEntry(
        id: _nextId++,
        level: level,
        message: message,
        context: context,
        stackTrace: stackTrace,
      ),
    );
    while (_buffer.length > maxEntries) {
      _buffer.removeFirst();
    }
    _entries.value = List<LogEntry>.unmodifiable(_buffer);
  }

  /// Clears all retained entries.
  void clear() {
    _buffer.clear();
    _entries.value = const <LogEntry>[];
  }

  void setFilter(ConsoleFilter value) => _filter.value = value;

  /// The entries matching the current [filter] — what the panel renders and
  /// what copy/share operate on. Compiles the regex once (when enabled) instead
  /// of per-entry, so a 2000-line buffer stays cheap to re-filter on keystroke.
  List<LogEntry> get filtered {
    final f = _filter.value;
    final re = f.compiledRegExp;
    return _buffer
        .where((e) => f.matchesWith(e, re))
        .toList(growable: false);
  }

  /// Per-level counts over the whole buffer (for the filter chips' badges),
  /// independent of the active search/level filter.
  Map<LogLevel, int> get levelCounts {
    final counts = <LogLevel, int>{for (final l in LogLevel.values) l: 0};
    for (final e in _buffer) {
      counts[e.level] = (counts[e.level] ?? 0) + 1;
    }
    return counts;
  }
}

/// Immutable filter state for the Console panel: which levels are visible and a
/// free-text search over message + context.
class ConsoleFilter {
  const ConsoleFilter({
    this.levels = const <LogLevel>{
      LogLevel.error,
      LogLevel.warn,
      LogLevel.info,
      LogLevel.debug,
      LogLevel.trace,
    },
    this.search = '',
    this.regex = false,
  });

  final Set<LogLevel> levels;
  final String search;

  /// When true, [search] is a case-insensitive regular expression; an invalid
  /// pattern matches nothing (so the field visibly "finds nothing" rather than
  /// silently falling back to substring).
  final bool regex;

  /// The compiled pattern for regex mode, or null (substring mode / empty / bad
  /// pattern). Computed lazily so [ConsoleStore.filtered] can compile once.
  RegExp? get compiledRegExp {
    if (!regex || search.isEmpty) return null;
    try {
      return RegExp(search, caseSensitive: false);
    } catch (_) {
      return null;
    }
  }

  bool matches(LogEntry e) => matchesWith(e, compiledRegExp);

  /// Like [matches] but reuses a pre-compiled [re] (regex mode) to avoid
  /// recompiling per entry.
  bool matchesWith(LogEntry e, RegExp? re) {
    if (!levels.contains(e.level)) return false;
    if (search.isEmpty) return true;
    if (regex) {
      if (re == null) return false; // invalid pattern → no matches
      return re.hasMatch(e.message) ||
          (e.context != null && re.hasMatch(e.context!));
    }
    final q = search.toLowerCase();
    return e.message.toLowerCase().contains(q) ||
        (e.context?.toLowerCase().contains(q) ?? false);
  }

  ConsoleFilter copyWith({Set<LogLevel>? levels, String? search, bool? regex}) =>
      ConsoleFilter(
        levels: levels ?? this.levels,
        search: search ?? this.search,
        regex: regex ?? this.regex,
      );
}
