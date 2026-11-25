import 'models/perf_models.dart';

/// Timestamped history of [PerfContext] changes, so a frame can be tagged with
/// the context that was live at its own vsync rather than whatever is current
/// when its (batched, delayed) timing report arrives.
class PerfContextLog {
  PerfContextLog({this.capacity = 256});

  /// Retained changes; older entries are dropped first.
  final int capacity;

  final List<({int atUs, PerfContext context})> _entries = [];

  int get length => _entries.length;

  /// Records [context] as live from [atUs] (µs since epoch). Repeats of the
  /// latest value are skipped so per-build reports don't flush the history.
  void record(int atUs, PerfContext context) {
    if (_entries.isNotEmpty && _same(_entries.last.context, context)) return;
    _entries.add((atUs: atUs, context: context));
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
  }

  /// The context live at [atUs]; the oldest retained one if [atUs] predates
  /// the history.
  PerfContext at(int atUs) {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].atUs <= atUs) return _entries[i].context;
    }
    return _entries.isEmpty ? PerfContext.empty : _entries.first.context;
  }

  void clear() => _entries.clear();

  static bool _same(PerfContext a, PerfContext b) =>
      a.route == b.route &&
      a.streaming == b.streaming &&
      a.scrolling == b.scrolling &&
      a.messages == b.messages;
}
