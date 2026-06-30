import 'dart:collection';

import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:aetherlink_perf/aetherlink_perf.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/settings/application/perf_monitor_controller.dart';

/// The Performance [DevToolsPanel]: a full-page view over the existing
/// `aetherlink_perf` monitor (devtools-design §5.3 — integrate, don't rewrite).
///
/// This bridge panel lives in `app/` (the composition root) rather than inside
/// the dependency-free `aetherlink_devtools` package, so that package never has
/// to depend on `aetherlink_perf`. It's registered via [DevToolsRegistry] at
/// startup, using the same extension point the Console/Network panels use.
///
/// It reads [PerfMonitor.instance]: live FPS/build/raster/memory with rolling
/// sparklines, the aggregated window summary (percentiles + tiered jank), the
/// rule-based bottleneck verdict, and a one-tap AI-friendly JSON export.
///
/// Ownership of the shared monitor singleton is resolved against the 显示性能监控
/// overlay flag: while the overlay is on it drives collection (the panel only
/// observes); while it's off the panel may start collection on demand and stops
/// it again when disposed (so it never leaks a running monitor).
class PerformancePanel extends DevToolsPanel {
  const PerformancePanel();

  @override
  String get title => '性能';

  @override
  IconData get icon => Icons.speed;

  @override
  Widget build(BuildContext context) => const _PerformanceView();

  /// Feeds the page-level "复制" action: the AI-ready JSON when collecting.
  @override
  String exportAsText() =>
      PerfMonitor.instance.isRunning ? PerfMonitor.instance.exportJson() : '';
}

class _PerformanceView extends ConsumerStatefulWidget {
  const _PerformanceView();

  @override
  ConsumerState<_PerformanceView> createState() => _PerformanceViewState();
}

class _PerformanceViewState extends ConsumerState<_PerformanceView> {
  final PerfMonitor _monitor = PerfMonitor.instance;

  /// ~60s of history at the monitor's 2 Hz sampling.
  static const int _historyCap = 120;
  final ListQueue<double> _fps = ListQueue<double>();
  final ListQueue<double> _build = ListQueue<double>();
  final ListQueue<double> _raster = ListQueue<double>();

  /// Whether this panel (rather than the overlay) started the monitor — used to
  /// decide whether to stop it on dispose.
  bool _startedByPanel = false;

  /// Last-seen overlay flag, captured in build so [dispose] can read it.
  bool _overlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _monitor.live.addListener(_onLive);
  }

  @override
  void dispose() {
    _monitor.live.removeListener(_onLive);
    // Only tear down collection we ourselves started, and never while the
    // overlay still wants it running.
    if (_startedByPanel && !_overlayEnabled) _monitor.stop();
    super.dispose();
  }

  void _onLive() {
    if (!_monitor.isRunning) return;
    final m = _monitor.live.value;
    _push(_fps, m.fps);
    _push(_build, m.buildMs);
    _push(_raster, m.rasterMs);
    if (mounted) setState(() {});
  }

  void _push(ListQueue<double> q, double v) {
    q.add(v);
    while (q.length > _historyCap) {
      q.removeFirst();
    }
  }

  void _start() {
    _monitor.start();
    _startedByPanel = true;
    setState(() {});
  }

  void _stop() {
    _monitor.stop();
    _startedByPanel = false;
    _fps.clear();
    _build.clear();
    _raster.clear();
    setState(() {});
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _monitor.exportJson()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制性能诊断 JSON')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _overlayEnabled = ref.watch(perfMonitorControllerProvider);

    if (!_monitor.isRunning) return _StoppedHint(onStart: _start);

    return ValueListenableBuilder<PerfLiveMetrics>(
      valueListenable: _monitor.live,
      builder: (context, m, _) {
        // The window summary is recomputed each live tick (~2 Hz) so percentiles
        // and jank rates stay current without a separate timer.
        final snap = _monitor.snapshot();
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _liveCard(context, m),
            const SizedBox(height: 12),
            _chartsCard(context),
            const SizedBox(height: 12),
            _summaryCard(context, snap),
            const SizedBox(height: 12),
            _actions(context),
          ],
        );
      },
    );
  }

  // --- live ------------------------------------------------------------------

  Widget _liveCard(BuildContext context, PerfLiveMetrics m) {
    final budget = _monitor.budgetMs;
    return _Card(
      title: '实时',
      child: Column(
        children: [
          _metric(context, 'FPS', m.fps.toStringAsFixed(0), _fpsColor(m.fps)),
          _metric(context, 'Build (UI)', '${m.buildMs.toStringAsFixed(1)}ms',
              _frameColor(m.buildMs, budget)),
          _metric(context, 'Raster (GPU)', '${m.rasterMs.toStringAsFixed(1)}ms',
              _frameColor(m.rasterMs, budget)),
          _metric(context, '慢帧率(稳态)',
              '${(m.jankRate * 100).toStringAsFixed(1)}%', _jankColor(m.jankRate)),
          _metric(context, '内存 RSS', '${m.rssMb.toStringAsFixed(0)}MB',
              _memColor(m.rssMb)),
          _metric(context, '图片缓存', '${m.imageCacheMb.toStringAsFixed(0)}MB',
              _memColor(m.imageCacheMb * 2)),
          const SizedBox(height: 8),
          _verdictChip(context, m.verdict, m.jankRate),
        ],
      ),
    );
  }

  // --- charts ----------------------------------------------------------------

  Widget _chartsCard(BuildContext context) {
    final budget = _monitor.budgetMs;
    return _Card(
      title: '实时曲线（近 ${_fps.length ~/ 2}s）',
      child: Column(
        children: [
          _SparkRow(
            label: 'FPS',
            values: _fps.toList(growable: false),
            color: const Color(0xFF66BB6A),
            // Higher is better; scale to the refresh rate.
            maxHint: 1000 / budget,
          ),
          const SizedBox(height: 10),
          _SparkRow(
            label: 'Build',
            values: _build.toList(growable: false),
            color: const Color(0xFF42A5F5),
            budget: budget,
          ),
          const SizedBox(height: 10),
          _SparkRow(
            label: 'Raster',
            values: _raster.toList(growable: false),
            color: const Color(0xFFFFB74D),
            budget: budget,
          ),
        ],
      ),
    );
  }

  // --- summary ---------------------------------------------------------------

  Widget _summaryCard(BuildContext context, PerfSnapshot snap) {
    final s = snap.summary;
    final mem = s.memory;
    return _Card(
      title: '窗口汇总（稳态，已剔除预热）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow(context, 'Build', s.buildMs),
          _statRow(context, 'Raster', s.rasterMs),
          _statRow(context, 'Total', s.totalMs),
          const Divider(height: 16),
          _kv(context, '帧数 / 预算',
              '${s.frameCount} 帧 · ${s.budgetMs.toStringAsFixed(1)}ms'),
          _kv(context, '慢帧 / 严重 / 冻结',
              '${_pct(s.slowFramePct)} · ${_pct(s.severeFramePct)} · ${s.frozenFrames}'),
          _kv(context, '内存 RSS',
              '${mem.rssMbEnd.toStringAsFixed(0)}MB（峰值 ${mem.rssMbPeak.toStringAsFixed(0)}，增长 ${mem.rssGrowthMb >= 0 ? '+' : ''}${mem.rssGrowthMb.toStringAsFixed(0)}）'),
          _kv(context, '图片缓存',
              '${mem.imageCacheMb.toStringAsFixed(0)}/${mem.imageCacheMaxMb.toStringAsFixed(0)}MB · ${mem.liveImages} 张'),
          _kv(context, '设备',
              '${snap.device.os} · ${snap.device.refreshRateHz.toStringAsFixed(0)}Hz'),
          if (snap.warmup.frameCount > 0)
            _kv(context, '预热',
                '${snap.warmup.frameCount} 帧 · ${snap.warmup.durationMs}ms · 最差 ${snap.warmup.worstTotalMs.toStringAsFixed(0)}ms'),
          const SizedBox(height: 8),
          _diagnosisBox(context, snap.diagnosis),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Column(
      children: [
        if (_overlayEnabled)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '采集由「显示性能监控」浮窗驱动，关闭浮窗后可在此独立控制。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        if (_overlayEnabled) const SizedBox(height: 12),
        Row(
          children: [
            if (!_overlayEnabled) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('停止采集'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: _copyJson,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('复制诊断 JSON'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- bits ------------------------------------------------------------------

  Widget _metric(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 60),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, Stat s) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              'p50 ${s.p50.toStringAsFixed(1)}  p95 ${s.p95.toStringAsFixed(1)}  '
              'p99 ${s.p99.toStringAsFixed(1)}  max ${s.max.toStringAsFixed(0)}',
              style: mono?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(v, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _verdictChip(BuildContext context, Bottleneck v, double jankRate) {
    final (label, color) = switch (v) {
      Bottleneck.ui => ('瓶颈：UI 线程', const Color(0xFFFFB74D)),
      Bottleneck.raster => ('瓶颈：Raster/GPU', const Color(0xFFFF8A65)),
      Bottleneck.memory => ('瓶颈：内存', const Color(0xFFBA68C8)),
      Bottleneck.none => ('无明显瓶颈', const Color(0xFF66BB6A)),
    };
    final ok = jankRate < 0.02;
    final show = ok ? '无明显瓶颈' : label;
    final c = ok ? const Color(0xFF66BB6A) : color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        show,
        textAlign: TextAlign.center,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _diagnosisBox(BuildContext context, PerfDiagnosis d) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '诊断',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(d.note, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

/// A labeled sparkline: current value chip + a hand-drawn line chart (no chart
/// dependency). [budget] draws a dashed reference line; [maxHint] sets a minimum
/// y-axis ceiling so a flat-but-good series isn't amplified into noise.
class _SparkRow extends StatelessWidget {
  const _SparkRow({
    required this.label,
    required this.values,
    required this.color,
    this.budget,
    this.maxHint,
  });

  final String label;
  final List<double> values;
  final Color color;
  final double? budget;
  final double? maxHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = values.isEmpty ? 0.0 : values.last;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: SizedBox(
            height: 40,
            child: CustomPaint(
              painter: _SparkPainter(
                values: values,
                color: color,
                budget: budget,
                maxHint: maxHint,
                gridColor: theme.dividerColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            last.toStringAsFixed(budget == null ? 0 : 1),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.gridColor,
    this.budget,
    this.maxHint,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;
  final double? budget;
  final double? maxHint;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      baseline,
    );

    if (values.length < 2) return;

    var maxV = maxHint ?? 0;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (budget != null && budget! > maxV) maxV = budget!;
    if (maxV <= 0) maxV = 1;

    double x(int i) => size.width * i / (values.length - 1);
    double y(double v) => size.height - (v / maxV).clamp(0, 1) * size.height;

    // Optional budget reference line (dashed).
    if (budget != null) {
      final by = y(budget!);
      final dash = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (double dx = 0; dx < size.width; dx += 6) {
        canvas.drawLine(Offset(dx, by), Offset(dx + 3, by), dash);
      }
    }

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    // Faint fill under the line.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color || old.budget != budget;
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StoppedHint extends StatelessWidget {
  const _StoppedHint({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            '性能监控未在采集',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '与「外观→开发者工具→显示性能监控」浮窗共用同一采集器',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('开始采集'),
          ),
        ],
      ),
    );
  }
}

// --- color helpers (mirror the floating overlay's thresholds) ----------------

Color _fpsColor(double fps) {
  if (fps >= 55) return const Color(0xFF66BB6A);
  if (fps >= 45) return const Color(0xFFFFB74D);
  return const Color(0xFFEF5350);
}

Color _frameColor(double ms, double budget) {
  if (ms <= budget) return const Color(0xFF66BB6A);
  if (ms <= budget * 2) return const Color(0xFFFFB74D);
  return const Color(0xFFEF5350);
}

Color _jankColor(double rate) {
  if (rate < 0.02) return const Color(0xFF66BB6A);
  if (rate < 0.05) return const Color(0xFFFFB74D);
  return const Color(0xFFEF5350);
}

Color _memColor(double mb) {
  if (mb < 300) return const Color(0xFF66BB6A);
  if (mb < 600) return const Color(0xFFFFB74D);
  return const Color(0xFFEF5350);
}
