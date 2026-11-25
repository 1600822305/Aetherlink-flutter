import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'render_stats.dart';

/// A cache of laid out [Paragraph]s. This is used to avoid laying out the same
/// text multiple times, which is expensive.
class ParagraphCache {
  ParagraphCache(this.maximumSize) {
    if (maximumSize <= 0) {
      throw ArgumentError.value(maximumSize, 'maximumSize');
    }
  }

  /// Entries kept before the least recently used ones are evicted. Can be
  /// changed while the cache is in use: lowering it evicts down to the new
  /// size over the next few insertions rather than at once.
  int maximumSize;

  final _cache = <Object, _CachedParagraph>{};

  /// Min-heap of recency snapshots, ordered by [_HeapEntry.lastUsed], used to
  /// find eviction candidates in O(log n) instead of resorting the whole
  /// cache on every eviction. A heap entry can go stale - see
  /// [_evictLeastRecentlyUsed] - because a cache hit bumps an entry's
  /// [_CachedParagraph.lastUsed] without touching the heap (see
  /// [getLayoutFromCache]); staleness is detected and repaired lazily, only
  /// when it is encountered while evicting.
  final _recencyHeap = <_HeapEntry>[];

  /// Monotonic counter used to order entries by recency of use. Reading an
  /// entry only bumps this counter and writes it into the entry, so cache hits
  /// never mutate [_cache] or [_recencyHeap].
  var _clock = 0;

  /// Number of entries dropped in one eviction pass. Evicting in batches keeps
  /// the amortized cost of eviction low relative to insertion.
  int get _evictionBatchSize {
    final batchSize = maximumSize >> 4;
    return batchSize < 1 ? 1 : batchSize;
  }

  /// Returns a [Paragraph] for the given [key]. [key] is the same as the
  /// key argument to [performAndCacheLayout].
  Paragraph? getLayoutFromCache(Object key) {
    final entry = _cache[key];
    if (entry == null) {
      TerminalRenderStats.paragraphCacheMisses++;
      return null;
    }
    TerminalRenderStats.paragraphCacheHits++;
    entry.lastUsed = ++_clock;
    return entry.paragraph;
  }

  /// Applies [style] and [textScaler] to [text] and lays it out to create
  /// a [Paragraph]. The [Paragraph] is cached and can be retrieved with the
  /// same [key] by calling [getLayoutFromCache].
  Paragraph performAndCacheLayout(
    String text,
    TextStyle style,
    TextScaler textScaler,
    Object key,
  ) {
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle(textScaler: textScaler));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    _cache.remove(key)?.paragraph.dispose();
    if (_cache.length >= maximumSize) {
      _evictLeastRecentlyUsed();
    }
    final lastUsed = ++_clock;
    _cache[key] = _CachedParagraph(paragraph, lastUsed);
    _heapPush(_HeapEntry(key, lastUsed));
    return paragraph;
  }

  void _evictLeastRecentlyUsed() {
    final batchSize = _evictionBatchSize;
    final count = batchSize > _cache.length ? _cache.length : batchSize;
    if (count <= 0) return;

    var evicted = 0;
    while (evicted < count && _recencyHeap.isNotEmpty) {
      final candidate = _heapPop();
      final entry = _cache[candidate.key];
      if (entry == null) {
        // This heap node refers to an entry that was already evicted or
        // replaced (performAndCacheLayout removes+disposes on key reuse).
        // Just drop it.
        continue;
      }
      if (entry.lastUsed != candidate.lastUsed) {
        // The entry was read (or replaced) again after this heap node was
        // created, so its recorded priority is out of date. Re-insert it
        // with the up-to-date priority - lazily "repairing" it instead of
        // resorting anything - and keep looking for the true LRU entry.
        _heapPush(_HeapEntry(candidate.key, entry.lastUsed));
        continue;
      }
      _cache.remove(candidate.key);
      entry.paragraph.dispose();
      evicted++;
    }
  }

  /// Clears the cache. This should be called when the same text and style
  /// pair no longer produces the same layout. For example, when a font is
  /// loaded.
  void clear() {
    for (final entry in _cache.values) {
      entry.paragraph.dispose();
    }
    _cache.clear();
    _recencyHeap.clear();
  }

  void dispose() {
    clear();
  }

  /// Returns the number of [Paragraph]s in the cache.
  int get length {
    return _cache.length;
  }

  void _heapPush(_HeapEntry entry) {
    _recencyHeap.add(entry);
    var i = _recencyHeap.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_recencyHeap[parent].lastUsed <= _recencyHeap[i].lastUsed) break;
      final tmp = _recencyHeap[parent];
      _recencyHeap[parent] = _recencyHeap[i];
      _recencyHeap[i] = tmp;
      i = parent;
    }
  }

  _HeapEntry _heapPop() {
    final top = _recencyHeap[0];
    final last = _recencyHeap.removeLast();
    final n = _recencyHeap.length;
    if (n > 0) {
      _recencyHeap[0] = last;
      var i = 0;
      while (true) {
        final left = 2 * i + 1;
        final right = 2 * i + 2;
        var smallest = i;
        if (left < n &&
            _recencyHeap[left].lastUsed < _recencyHeap[smallest].lastUsed) {
          smallest = left;
        }
        if (right < n &&
            _recencyHeap[right].lastUsed < _recencyHeap[smallest].lastUsed) {
          smallest = right;
        }
        if (smallest == i) break;
        final tmp = _recencyHeap[i];
        _recencyHeap[i] = _recencyHeap[smallest];
        _recencyHeap[smallest] = tmp;
        i = smallest;
      }
    }
    return top;
  }
}

class _CachedParagraph {
  _CachedParagraph(this.paragraph, this.lastUsed);

  final Paragraph paragraph;

  int lastUsed;
}

/// A snapshot of a cache entry's recency at the time it was pushed onto
/// [ParagraphCache._recencyHeap].
class _HeapEntry {
  _HeapEntry(this.key, this.lastUsed);

  final Object key;

  final int lastUsed;
}
