import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:aetherlink_perf/src/diagnoser.dart';
import 'package:flutter_test/flutter_test.dart';

PerfSummary _summary({
  required double buildP95,
  required double rasterP95,
  required double jankRate,
  double imageCacheMb = 0,
}) {
  Stat s(double p95) => Stat(avg: p95 / 2, p50: p95 / 2, p95: p95, p99: p95, max: p95);
  return PerfSummary(
    fps: Stat.empty(),
    buildMs: s(buildP95),
    rasterMs: s(rasterP95),
    totalMs: s(buildP95 + rasterP95),
    jankRate: jankRate,
    frameCount: 1000,
    memory: MemoryStats(
      rssMbAvg: 200,
      rssMbPeak: 250,
      imageCacheMb: imageCacheMb,
      liveImages: 100,
    ),
  );
}

void main() {
  const d = Diagnoser();

  test('raster-dominated window is diagnosed as raster-bound', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 5, rasterP95: 40, jankRate: 0.15),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.raster);
  });

  test('build-dominated window is diagnosed as UI-bound', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 35, rasterP95: 6, jankRate: 0.2),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.ui);
  });

  test('smooth window with low jank reports no bottleneck', () {
    final diag = d.diagnose(
      summary: _summary(buildP95: 4, rasterP95: 5, jankRate: 0.005),
      jankEvents: const [],
    );
    expect(diag.primaryBottleneck, Bottleneck.none);
  });

  test('jank events context drives the note suffix', () {
    final events = List.generate(
      4,
      (_) => const JankEvent(
        atMs: 1000,
        totalMs: 48,
        buildMs: 6,
        rasterMs: 42,
        verdict: Bottleneck.raster,
        context: PerfContext(route: '/chat', scrolling: true, streaming: true),
      ),
    );
    final diag = d.diagnose(
      summary: _summary(buildP95: 6, rasterP95: 42, jankRate: 0.12),
      jankEvents: events,
    );
    expect(diag.note, contains('/chat'));
    expect(diag.note, contains('滚动'));
  });

  test('snapshot JSON has the expected schema and shape', () {
    final snap = PerfSnapshot(
      device: const PerfDevice(os: 'android 14', refreshRateHz: 120),
      windowStart: DateTime(2026, 1, 1),
      windowDurationMs: 30000,
      summary: _summary(buildP95: 6, rasterP95: 42, jankRate: 0.12),
      jankEvents: const [],
      diagnosis: const PerfDiagnosis(primaryBottleneck: Bottleneck.raster, note: 'x'),
    );
    final json = snap.toJson();
    expect(json['schema'], 'aetherlink_perf/v1');
    expect((json['device'] as Map)['refreshRate'], 120);
    expect((json['summary'] as Map).containsKey('buildMs'), isTrue);
    expect((json['diagnosis'] as Map)['primaryBottleneck'], 'raster');
  });
}
