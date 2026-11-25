// The `bench_stats.dart` a build without `TerminalRenderStats` gets.
//
// `script/bench-compare.sh` copies this file over `bench/bench_stats.dart`
// inside the baseline worktree. Frame timings - the numbers the comparison is
// actually about - are collected through `SchedulerBinding`, so they are
// unaffected; only the cache-counter table goes away.

/// Stand-in for the real [BenchStats] on builds that do not have paint-path
/// counters. Every field reads zero and [available] is false.
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
      paints: 0,
      paintedLines: 0,
      paragraphHits: 0,
      paragraphLookups: 0,
      glyphHits: 0,
      glyphLookups: 0,
    );
  }

  static const available = false;

  static void reset() {}

  final int paints;
  final int paintedLines;
  final int paragraphHits;
  final int paragraphLookups;
  final int glyphHits;
  final int glyphLookups;
}
