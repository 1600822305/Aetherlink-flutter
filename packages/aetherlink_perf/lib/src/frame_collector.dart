import 'dart:ui' show FrameTiming;

import 'histogram.dart';
import 'models/perf_models.dart';

/// One captured frame: the build (UI thread) / raster (GPU thread) split, the
/// total span, the wall-clock capture time and the app context at that moment.
class _FrameSample {
  _FrameSample({
    required this.wallMs,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
    required this.context,
  });

  /// Milliseconds since [FrameCollector] epoch (host wall clock).
  final int wallMs;
  final double buildMs;
  final double rasterMs;
  final double totalMs;
  final PerfContext context;
}

/// The steady-state aggregate over the window (warm-up excluded).
typedef FrameAggregate = ({
  Stat build,
  Stat raster,
  Stat total,
  int frameCount,
  double slowPct,
  double severePct,
  int frozen,
  double budgetMs,
});

/// Subscribes to Flutter's frame timings and keeps streaming statistics,
/// splitting each frame into its UI-thread (`buildDuration`) and raster-thread
/// (`rasterDuration`) costs — the split that tells a UI-bound jank from a
/// GPU-bound one.
///
/// Design (professional-grade, continuous-run safe):
/// - Distributions are accumulated into [Histogram]s, so percentiles are O(1)
///   memory and need no per-read sort regardless of how long the monitor runs.
/// - Frames in the first [warmupMs] after collection starts are treated as a
///   one-time warm-up phase (first paint, route build, image/shader warm-up)
///   and excluded from steady-state rates; they're summarised separately.
/// - Jank is tiered (over budget / over 2× budget / over 700ms frozen) instead
///   of a single rate, mirroring Firebase/Android-Vitals slow+frozen frames.
class FrameCollector {
  FrameCollector({
    this.recentCapacity = 240,
    this.slowCapacity = 240,
    this.warmupMs = 1500,
  });

  /// Frozen-frame threshold (ms). A frame this slow reads as a freeze to the
  /// user; aligned with Firebase Performance's 700ms "frozen frame".
  static const double frozenMs = 700;

  /// Retained recent frames, for [latest] and the count-based [recentFps].
  final int recentCapacity;

  /// Retained slow frames (over budget), for [jankEvents].
  final int slowCapacity;

  /// Frames within this many ms of the epoch are the warm-up phase.
  final int warmupMs;

  final List<_FrameSample> _recent = <_FrameSample>[];
  final List<_FrameSample> _slow = <_FrameSample>[];

  Histogram _build = Histogram();
  Histogram _raster = Histogram();
  Histogram _total = Histogram();

  DateTime _epoch = DateTime.now();
  double _budgetMs = 1000 / 60;

  int _steadyCount = 0;
  int _slowCount = 0;
  int _severeCount = 0;
  int _frozenCount = 0;

  int _warmupCount = 0;
  int _warmupLastMs = 0;
  double _warmupWorst = 0;

  DateTime get epoch => _epoch;
  double get budgetMs => _budgetMs;

  /// Resets all state and arms the per-frame budget for the active display.
  void reset(double budgetMs) {
    _budgetMs = budgetMs <= 0 ? 1000 / 60 : budgetMs;
    _recent.clear();
    _slow.clear();
    _build = Histogram();
    _raster = Histogram();
    _total = Histogram();
    _epoch = DateTime.now();
    _steadyCount = 0;
    _slowCount = 0;
    _severeCount = 0;
    _frozenCount = 0;
    _warmupCount = 0;
    _warmupLastMs = 0;
    _warmupWorst = 0;
  }

  /// Most recent frame's build/raster/total in ms, or null if none yet.
  ({double build, double raster, double total})? get latest {
    if (_recent.isEmpty) return null;
    final s = _recent.last;
    return (build: s.buildMs, raster: s.rasterMs, total: s.totalMs);
  }

  /// Ingests a batch of [FrameTiming]s (the signature of
  /// `WidgetsBinding.addTimingsCallback`). [context] tags these frames.
  void addTimings(List<FrameTiming> timings, PerfContext context) {
    final now = DateTime.now().difference(_epoch).inMilliseconds;
    for (final t in timings) {
      final build = _ms(t.buildDuration);
      final raster = _ms(t.rasterDuration);
      final total = _ms(t.totalSpan);
      final s = _FrameSample(
        wallMs: now,
        buildMs: build,
        rasterMs: raster,
        totalMs: total,
        context: context,
      );

      _recent.add(s);
      if (_recent.length > recentCapacity) {
        _recent.removeRange(0, _recent.length - recentCapacity);
      }

      if (now < warmupMs) {
        _warmupCount++;
        _warmupLastMs = now;
        if (total > _warmupWorst) _warmupWorst = total;
      } else {
        _steadyCount++;
        _build.add(build);
        _raster.add(raster);
        _total.add(total);
        if (total > _budgetMs) _slowCount++;
        if (total > _budgetMs * 2) _severeCount++;
        if (total > frozenMs) _frozenCount++;
      }

      // Keep slow frames (any phase) for the jank-event list with context.
      if (total > _budgetMs) {
        _slow.add(s);
        if (_slow.length > slowCapacity) {
          _slow.removeRange(0, _slow.length - slowCapacity);
        }
      }
    }
  }

  /// FPS over the last [seconds] of wall time, anchored to *now* (not the last
  /// rendered frame): frames actually presented within the window, capped at
  /// the display refresh rate. Flutter renders on demand, so an idle app
  /// produces no frames and correctly reads 0 rather than replaying the last
  /// burst. This is a live gauge only — never a window summary.
  double recentFps([int seconds = 1]) {
    if (_recent.isEmpty || seconds <= 0) return 0;
    final nowMs = DateTime.now().difference(_epoch).inMilliseconds;
    final cutoff = nowMs - seconds * 1000;
    var count = 0;
    for (var i = _recent.length - 1; i >= 0; i--) {
      if (_recent[i].wallMs < cutoff) break;
      count++;
    }
    final cap = _budgetMs <= 0 ? 240.0 : 1000 / _budgetMs;
    return (count / seconds).clamp(0, cap).toDouble();
  }

  /// Steady-state aggregate (warm-up excluded).
  FrameAggregate aggregate() => (
        build: _build.toStat(),
        raster: _raster.toStat(),
        total: _total.toStat(),
        frameCount: _steadyCount,
        slowPct: _steadyCount == 0 ? 0 : _slowCount / _steadyCount,
        severePct: _steadyCount == 0 ? 0 : _severeCount / _steadyCount,
        frozen: _frozenCount,
        budgetMs: _budgetMs,
      );

  /// The one-time warm-up phase summary.
  WarmupStats warmup() => WarmupStats(
        frameCount: _warmupCount,
        durationMs: _warmupCount == 0 ? 0 : _warmupLastMs,
        worstTotalMs: _warmupWorst,
      );

  /// The worst [limit] slow frames (total span over budget), newest-biased,
  /// each classified UI- vs raster-bound and tagged with its context.
  List<JankEvent> jankEvents({int limit = 30}) {
    final janks = [..._slow]..sort((a, b) => b.totalMs.compareTo(a.totalMs));
    final top = janks.take(limit).toList()
      ..sort((a, b) => a.wallMs.compareTo(b.wallMs));
    return top
        .map((s) => JankEvent(
              atMs: s.wallMs,
              totalMs: s.totalMs,
              buildMs: s.buildMs,
              rasterMs: s.rasterMs,
              verdict: s.rasterMs >= s.buildMs ? Bottleneck.raster : Bottleneck.ui,
              context: s.context,
            ))
        .toList();
  }

  static double _ms(Duration d) => d.inMicroseconds / 1000.0;
}
