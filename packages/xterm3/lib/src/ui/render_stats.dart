/// Process-wide counters for the paint path, used to make render work
/// observable from a benchmark or an embedder's debug overlay.
///
/// The counters are plain integer increments on paths that are already doing
/// map lookups or paragraph layout, so they are not worth gating behind a
/// compile-time flag. They are cumulative and process-wide - a single terminal
/// per process is the normal case, and aggregating across every [TerminalView]
/// is what a benchmark wants anyway. Call [reset] to start a measurement
/// window.
///
/// A cache hit ratio is only meaningful when read over a window that starts
/// after the caches have warmed up; the first frames after a font, theme or
/// size change necessarily miss.
abstract final class TerminalRenderStats {
  /// Number of times the terminal's paint method has run.
  static int paints = 0;

  /// Total lines visited by the per-line paint loops, summed over [paints].
  ///
  /// Divided by [paints] this gives the average number of lines repainted per
  /// frame. Damage tracking is what would make this fall below the viewport
  /// height on a mostly static screen.
  static int paintedLines = 0;

  /// Lookups in the shaped-text cache that found a laid out paragraph.
  static int paragraphCacheHits = 0;

  /// Lookups in the shaped-text cache that had to shape and lay out the text.
  static int paragraphCacheMisses = 0;

  /// Lookups in the procedural glyph cache that found a rasterised picture.
  static int glyphCacheHits = 0;

  /// Lookups in the procedural glyph cache that had to rebuild the path.
  static int glyphCacheMisses = 0;

  /// Fraction of paragraph cache lookups that hit, or `null` if there were no
  /// lookups at all.
  static double? get paragraphCacheHitRatio =>
      _ratio(paragraphCacheHits, paragraphCacheMisses);

  /// Fraction of procedural glyph cache lookups that hit, or `null` if there
  /// were no lookups at all.
  static double? get glyphCacheHitRatio =>
      _ratio(glyphCacheHits, glyphCacheMisses);

  /// Average number of lines repainted per frame, or `null` if nothing has
  /// been painted.
  static double? get linesPerPaint =>
      paints == 0 ? null : paintedLines / paints;

  static double? _ratio(int hits, int misses) {
    final total = hits + misses;
    return total == 0 ? null : hits / total;
  }

  /// Zeroes every counter, starting a new measurement window.
  static void reset() {
    paints = 0;
    paintedLines = 0;
    paragraphCacheHits = 0;
    paragraphCacheMisses = 0;
    glyphCacheHits = 0;
    glyphCacheMisses = 0;
  }

  /// A one line summary, suitable for printing next to frame timings.
  static String summary() {
    String percent(double? ratio) =>
        ratio == null ? '  n/a' : '${(ratio * 100).toStringAsFixed(1)}%';

    final lines = linesPerPaint;
    return 'paints ${paints.toString().padLeft(5)} | '
        'lines/paint ${lines == null ? ' n/a' : lines.toStringAsFixed(1).padLeft(5)} | '
        'paragraph hit ${percent(paragraphCacheHitRatio)} '
        '(${paragraphCacheHits + paragraphCacheMisses} lookups) | '
        'glyph hit ${percent(glyphCacheHitRatio)} '
        '(${glyphCacheHits + glyphCacheMisses} lookups)';
  }
}
