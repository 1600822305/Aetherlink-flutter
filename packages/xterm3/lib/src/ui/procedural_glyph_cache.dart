import 'dart:ui';

import 'render_stats.dart';

/// A cache of rasterised procedural glyphs (box-drawing, Powerline, Braille,
/// etc). These are drawn as vector paths rather than shaped from a font, so
/// without this cache the same vector path would be rebuilt and rasterised on
/// every repaint of every cell that uses one, even on an otherwise static
/// screen.
///
/// Follows the same LRU-with-lazy-eviction pattern as [ParagraphCache]: a
/// min-heap of recency snapshots is used to find eviction candidates in
/// O(log n) instead of resorting the whole cache, and a cache hit only bumps
/// a counter, never mutating the cache or the heap.
class ProceduralGlyphCache {
  ProceduralGlyphCache(this.maximumSize) {
    if (maximumSize <= 0) {
      throw ArgumentError.value(maximumSize, 'maximumSize');
    }
  }

  final int maximumSize;

  final _cache = <Object, _CachedPicture>{};

  /// Min-heap of recency snapshots, ordered by [_HeapEntry.lastUsed]. See
  /// [ParagraphCache._recencyHeap] for the full rationale - the same
  /// lazy-repair scheme is used here.
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

  /// Returns the cached [Picture] for [key], if any, bumping its recency.
  Picture? getFromCache(Object key) {
    final entry = _cache[key];
    if (entry == null) {
      TerminalRenderStats.glyphCacheMisses++;
      return null;
    }
    TerminalRenderStats.glyphCacheHits++;
    entry.lastUsed = ++_clock;
    return entry.picture;
  }

  /// Inserts [picture] into the cache under [key], evicting the least
  /// recently used entries first if the cache is full.
  ///
  /// [key] must not already be present in the cache - callers should check
  /// [getFromCache] first.
  void insert(Object key, Picture picture) {
    // Guards against a native Picture leak (and a stale duplicate node in
    // _recencyHeap) if a caller ever inserts over a key that's already
    // cached, in violation of the contract above.
    _cache.remove(key)?.picture.dispose();
    if (_cache.length >= maximumSize) {
      _evictLeastRecentlyUsed();
    }
    final lastUsed = ++_clock;
    _cache[key] = _CachedPicture(picture, lastUsed);
    _heapPush(_HeapEntry(key, lastUsed));
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
        continue;
      }
      if (entry.lastUsed != candidate.lastUsed) {
        _heapPush(_HeapEntry(candidate.key, entry.lastUsed));
        continue;
      }
      _cache.remove(candidate.key);
      entry.picture.dispose();
      evicted++;
    }
  }

  /// Clears the cache. This should be called whenever the same key could
  /// stop producing the same rasterised output, for example when the cell
  /// size or a relevant color changes.
  void clear() {
    for (final entry in _cache.values) {
      entry.picture.dispose();
    }
    _cache.clear();
    _recencyHeap.clear();
  }

  void dispose() {
    clear();
  }

  /// Returns the number of [Picture]s in the cache.
  int get length => _cache.length;

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

class _CachedPicture {
  _CachedPicture(this.picture, this.lastUsed);

  final Picture picture;

  int lastUsed;
}

/// A snapshot of a cache entry's recency at the time it was pushed onto
/// [ProceduralGlyphCache._recencyHeap].
class _HeapEntry {
  _HeapEntry(this.key, this.lastUsed);

  final Object key;

  final int lastUsed;
}
