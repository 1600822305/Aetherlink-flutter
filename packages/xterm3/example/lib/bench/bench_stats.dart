// Paint-path counters, as the benchmark harness sees them.
//
// This file exists so `benchmark.dart` never names `TerminalRenderStats`
// directly. `TerminalRenderStats` was added by `perf(ui): make the paint path
// measurable`, so it is absent from any build older than that, and the whole
// point of the harness is to run unmodified against an older build. The
// comparison script copies `bench_stats_stub.dart` over this file in the
// baseline worktree; everything else about the harness stays byte-identical
// between the two runs.

import 'package:xterm3/xterm.dart';

/// The paint-path counters as they stood at the end of a measurement window.
///
/// [TerminalRenderStats] is a set of process-wide mutable statics, so a
/// workload's numbers have to be copied out before the next one starts.
class BenchStats {
  BenchStats({
    required this.paints,
    required this.paintedLines,
    required this.paragraphHits,
    required this.paragraphLookups,
    required this.glyphHits,
    required this.glyphLookups,
  });

  factory BenchStats.capture() {
    return BenchStats(
      paints: TerminalRenderStats.paints,
      paintedLines: TerminalRenderStats.paintedLines,
      paragraphHits: TerminalRenderStats.paragraphCacheHits,
      paragraphLookups: TerminalRenderStats.paragraphCacheHits +
          TerminalRenderStats.paragraphCacheMisses,
      glyphHits: TerminalRenderStats.glyphCacheHits,
      glyphLookups: TerminalRenderStats.glyphCacheHits +
          TerminalRenderStats.glyphCacheMisses,
    );
  }

  /// Whether the build under test reports these counters at all. False in the
  /// stub, which is how the report knows to say so rather than print zeros as
  /// if they were measurements.
  static const available = true;

  static void reset() => TerminalRenderStats.reset();

  final int paints;
  final int paintedLines;
  final int paragraphHits;
  final int paragraphLookups;
  final int glyphHits;
  final int glyphLookups;
}
