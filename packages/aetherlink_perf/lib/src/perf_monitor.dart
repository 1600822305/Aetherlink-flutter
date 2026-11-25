import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'context_log.dart';
import 'diagnoser.dart';
import 'frame_collector.dart';
import 'memory_collector.dart';
import 'models/perf_models.dart';

/// The compact, always-current numbers the floating overlay paints. Distinct
/// from [PerfSnapshot], which is the heavier aggregated export.
class PerfLiveMetrics {
  const PerfLiveMetrics({
    this.fps = 0,
    this.buildMs = 0,
    this.rasterMs = 0,
    this.rssMb = 0,
    this.imageCacheMb = 0,
    this.jankRate = 0,
    this.verdict = Bottleneck.none,
  });

  final double fps;
  final double buildMs;
  final double rasterMs;
  final double rssMb;
  final double imageCacheMb;
  final double jankRate;
  final Bottleneck verdict;
}

/// Central coordinator: owns the collectors, subscribes to frame timings, drives
/// a sampling timer, holds the live app context the host reports, and builds the
/// AI-friendly [PerfSnapshot] on demand.
///
/// Use the [instance] singleton. [start] is idempotent; calling it when already
/// running is a no-op, so the host can wire it to a settings toggle freely.
class PerfMonitor {
  PerfMonitor._();

  static final PerfMonitor instance = PerfMonitor._();

  final FrameCollector _frames = FrameCollector();
  final MemoryCollector _memory = MemoryCollector();
  final Diagnoser _diagnoser = const Diagnoser();
  final PerfContextLog _contextLog = PerfContextLog();

  final ValueNotifier<PerfContext> _context =
      ValueNotifier<PerfContext>(PerfContext.empty);
  final ValueNotifier<PerfLiveMetrics> _live =
      ValueNotifier<PerfLiveMetrics>(const PerfLiveMetrics());

  Timer? _timer;
  bool _running = false;
  String? _deviceModel;
  double _refreshRate = 60;

  /// Live metrics for the overlay to listen to.
  ValueListenable<PerfLiveMetrics> get live => _live;

  bool get isRunning => _running;

  /// The context last reported by the host.
  PerfContext get context => _context.value;

  /// Per-frame budget in ms, derived from the display refresh rate.
  double get budgetMs => _refreshRate <= 0 ? 16.7 : 1000 / _refreshRate;

  /// Begins collection. Safe to call repeatedly.
  void start() {
    if (_running) return;
    _running = true;
    _refreshRate = _detectRefreshRate();
    _frames.reset(budgetMs);
    _contextLog
      ..clear()
      ..record(_frames.epochUs, _context.value);
    _memory.reset();
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  /// Stops collection and clears buffers and the reported context.
  void stop() {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    _timer?.cancel();
    _timer = null;
    _context.value = PerfContext.empty;
    _contextLog.clear();
    _live.value = const PerfLiveMetrics();
  }

  // --- Host-reported context -------------------------------------------------

  /// The current router location, e.g. `/chat`.
  void setRoute(String? route) => _update((c) => c.copyWith(route: route));

  /// Whether a model response is currently streaming.
  void setStreaming(bool value) =>
      _update((c) => c.copyWith(streaming: value));

  /// Whether a scrollable is actively being dragged/flung.
  void setScrolling(bool value) =>
      _update((c) => c.copyWith(scrolling: value));

  /// Number of messages in the visible conversation.
  void setMessages(int? count) => _update((c) => c.copyWith(messages: count));

  /// Clears the page-scoped context (messages / streaming / scrolling) while
  /// keeping the route — pages only report on change, so a value left by the
  /// previous screen or conversation would otherwise be attributed to the next.
  void resetPageContext() => _update((c) => PerfContext(route: c.route));

  /// Optional device model string (the host has device_info; the package does
  /// not, to stay dependency-free).
  void setDeviceModel(String? model) => _deviceModel = model;

  // Context tracks the host even while stopped (the toggle hydrates
  // asynchronously, after the first route report); only frames gate on running.
  void _update(PerfContext Function(PerfContext) f) {
    _context.value = f(_context.value);
    if (_running) _contextLog.record(_frames.nowUs(), _context.value);
  }

  // --- Collection ------------------------------------------------------------

  void _onTimings(List<FrameTiming> timings) {
    if (!_running) return;
    _frames.addTimings(timings, _contextLog.at);
  }

  void _tick() {
    if (!_running) return;
    _memory.sample();
    final latest = _frames.latest;
    final agg = _frames.aggregate();
    _live.value = PerfLiveMetrics(
      fps: _frames.recentFps(),
      buildMs: latest?.build ?? 0,
      rasterMs: latest?.raster ?? 0,
      rssMb: _memory.lastRssMb,
      imageCacheMb: _memory.lastImageCacheMb,
      jankRate: agg.slowPct,
      verdict: agg.raster.p95 >= agg.build.p95 ? Bottleneck.raster : Bottleneck.ui,
    );
  }

  // --- Export ----------------------------------------------------------------

  /// Builds the aggregated snapshot over the retained window.
  PerfSnapshot snapshot() {
    final agg = _frames.aggregate();
    final jank = _frames.jankEvents();
    final warmup = _frames.warmup();
    final summary = PerfSummary(
      buildMs: agg.build,
      rasterMs: agg.raster,
      totalMs: agg.total,
      slowFramePct: agg.slowPct,
      severeFramePct: agg.severePct,
      frozenFrames: agg.frozen,
      frameCount: agg.frameCount,
      budgetMs: agg.budgetMs,
      liveFps: _frames.recentFps(),
      memory: _memory.aggregate(),
    );
    final diagnosis = _diagnoser.diagnose(
      summary: summary,
      jankEvents: jank,
      warmup: warmup,
    );
    return PerfSnapshot(
      device: PerfDevice(
        os: _osString(),
        refreshRateHz: _refreshRate,
        model: _deviceModel,
      ),
      windowStart: _frames.epoch,
      windowDurationMs:
          DateTime.now().difference(_frames.epoch).inMilliseconds,
      summary: summary,
      warmup: warmup,
      jankEvents: jank,
      diagnosis: diagnosis,
    );
  }

  /// The snapshot as pretty-printed JSON, ready to paste into an AI prompt.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(snapshot().toJson());

  double _detectRefreshRate() {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.implicitView ??
          WidgetsBinding.instance.platformDispatcher.views.first;
      final rate = view.display.refreshRate;
      if (rate >= 30 && rate <= 240) return rate;
    } catch (_) {}
    return 60;
  }

  String _osString() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown';
    }
  }
}
