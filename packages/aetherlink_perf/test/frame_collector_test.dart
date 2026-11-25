import 'dart:ui' show FrameTiming;

import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:aetherlink_perf/src/frame_collector.dart';
import 'package:flutter_test/flutter_test.dart';

const int _epochUs = 1000000000;

/// A frame whose vsync lands [atMs] after the collector epoch, with the UI
/// and raster threads pipelined (raster starts right after build).
FrameTiming _frame({
  required int atMs,
  required double buildMs,
  required double rasterMs,
  double gapMs = 0,
}) {
  final vsync = _epochUs + atMs * 1000;
  final buildEnd = vsync + (buildMs * 1000).round();
  final rasterStart = buildEnd + (gapMs * 1000).round();
  final rasterEnd = rasterStart + (rasterMs * 1000).round();
  return FrameTiming(
    vsyncStart: vsync,
    buildStart: vsync,
    buildFinish: buildEnd,
    rasterStart: rasterStart,
    rasterFinish: rasterEnd,
    rasterFinishWallTime: rasterEnd,
  );
}

FrameCollector _collector({int nowMs = 0}) {
  var now = _epochUs;
  final c = FrameCollector(warmupMs: 0, clock: () => now);
  c.reset(1000 / 120);
  now = _epochUs + nowMs * 1000;
  return c;
}

PerfContext _none(int _) => PerfContext.empty;

void main() {
  test('pipelined build + raster within budget is not slow at 120Hz', () {
    final c = _collector();
    // 5ms + 5ms: totalSpan 10ms > 8.33ms budget, but neither thread overruns.
    c.addTimings([_frame(atMs: 10, buildMs: 5, rasterMs: 5)], _none);
    final agg = c.aggregate();
    expect(agg.frameCount, 1);
    expect(agg.slowPct, 0);
    expect(agg.severePct, 0);
    expect(agg.total.max, closeTo(10, 0.5));
    expect(c.jankEvents(), isEmpty);
  });

  test('slow and severe tiers use the slower thread', () {
    final c = _collector();
    c.addTimings([
      _frame(atMs: 10, buildMs: 9, rasterMs: 2),
      _frame(atMs: 30, buildMs: 2, rasterMs: 17),
      _frame(atMs: 50, buildMs: 3, rasterMs: 3),
      _frame(atMs: 70, buildMs: 4, rasterMs: 4),
    ], _none);
    final agg = c.aggregate();
    expect(agg.slowPct, 0.5);
    expect(agg.severePct, 0.25);
    final jank = c.jankEvents();
    expect(jank.map((e) => e.verdict), [Bottleneck.ui, Bottleneck.raster]);
  });

  test('frozen frames still use totalSpan', () {
    final c = _collector();
    c.addTimings(
      [_frame(atMs: 10, buildMs: 5, rasterMs: 5, gapMs: 800)],
      _none,
    );
    expect(c.aggregate().frozen, 1);
  });

  test('frames are placed by their own vsync, not the batch arrival', () {
    final c = FrameCollector(warmupMs: 100, clock: () => _epochUs);
    c.reset(1000 / 60);
    c.addTimings([
      _frame(atMs: 50, buildMs: 20, rasterMs: 1),
      _frame(atMs: 150, buildMs: 20, rasterMs: 1),
    ], _none);
    expect(c.warmup().frameCount, 1);
    expect(c.aggregate().frameCount, 1);
    expect(c.jankEvents().map((e) => e.atMs), [50, 150]);
  });

  test('each frame is tagged with the context at its vsync', () {
    final c = _collector();
    final seen = <int>[];
    PerfContext contextAt(int us) {
      seen.add(us);
      return PerfContext(route: us < _epochUs + 100000 ? '/chat' : '/agent');
    }

    c.addTimings([
      _frame(atMs: 50, buildMs: 20, rasterMs: 1),
      _frame(atMs: 150, buildMs: 20, rasterMs: 1),
    ], contextAt);
    expect(seen, [_epochUs + 50000, _epochUs + 150000]);
    expect(c.jankEvents().map((e) => e.context.route), ['/chat', '/agent']);
  });

  test('frames from before the epoch are ignored', () {
    final c = _collector();
    c.addTimings([_frame(atMs: -5, buildMs: 20, rasterMs: 1)], _none);
    expect(c.aggregate().frameCount, 0);
    expect(c.warmup().frameCount, 0);
  });

  test('recentFps counts frames against the engine clock', () {
    final c = _collector(nowMs: 1000);
    c.addTimings([
      for (var i = 0; i < 60; i++)
        _frame(atMs: 500 + i * 8, buildMs: 2, rasterMs: 2),
    ], _none);
    expect(c.recentFps(), 60);
  });
}
