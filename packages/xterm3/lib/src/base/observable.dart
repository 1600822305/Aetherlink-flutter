/// A minimum size below which we never bother compacting [Observable]'s
/// internal listener storage - avoids repeated tiny rebuilds.
const _compactionThreshold = 16;

mixin Observable {
  // Listeners are stored in an append-only list rather than a Set. Removal
  // tombstones the slot (sets it to null) instead of shifting the list, so
  // that notifyListeners() can walk the list by index without ever taking a
  // defensive copy: appends land after the captured length (and so are
  // simply not visited this round) and removals just turn future reads of
  // that slot into a no-op. Both are safe to do from within a listener
  // callback while notifyListeners() is mid-iteration.
  final _listeners = <void Function()?>[];

  // Tracks reentrant notifyListeners() calls so _compactIfNeeded() can defer
  // shrinking the list while notify is mid-iteration - compacting in place
  // would invalidate the index the outer notifyListeners() loop is reading.
  var _notifyDepth = 0;
  var _compactionPending = false;

  /// Read-only view of the currently registered listeners (removed/tombstoned
  /// slots are excluded).
  Iterable<void Function()> get listeners =>
      _listeners.whereType<void Function()>();

  void addListener(void Function() listener) {
    _listeners.add(listener);
    _compactIfNeeded();
  }

  void removeListener(void Function() listener) {
    final index = _listeners.indexOf(listener);
    if (index != -1) {
      _listeners[index] = null;
    }
  }

  void clearListeners() {
    _listeners.clear();
  }

  void notifyListeners() {
    _notifyDepth++;
    try {
      // Snapshot only the length, not the contents: this is the hot path
      // (hit on every Terminal.write()) and must not allocate in the steady
      // state.
      final length = _listeners.length;
      for (var i = 0; i < length; i++) {
        _listeners[i]?.call();
      }
    } finally {
      _notifyDepth--;
      if (_notifyDepth == 0 && _compactionPending) {
        _compactionPending = false;
        _compactIfNeeded();
      }
    }
  }

  /// Rebuilds the backing list without tombstoned (null) slots once they
  /// make up a significant fraction of it, so long-lived [Observable]s with
  /// frequent add/remove churn (e.g. widgets attaching/detaching listeners
  /// on every rebuild) don't grow the list unboundedly.
  void _compactIfNeeded() {
    if (_notifyDepth > 0) {
      _compactionPending = true;
      return;
    }
    if (_listeners.length < _compactionThreshold) return;

    final liveCount = _listeners.where((l) => l != null).length;
    if (liveCount * 2 > _listeners.length) return;

    final compacted = _listeners.where((l) => l != null).toList();
    _listeners
      ..clear()
      ..addAll(compacted);
  }
}
