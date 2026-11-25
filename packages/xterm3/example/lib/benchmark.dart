// A deterministic render benchmark for A/B comparing two builds of xterm3.
//
// Run it in profile mode on both builds, with nothing else on screen:
//
//   cd example
//   flutter run --profile -t lib/benchmark.dart
//
// It drives the terminal with a fixed, precomputed byte stream - one write per
// frame - and reports UI and raster frame times per workload. There is no PTY
// and no shell, so two runs on the same machine see the same work.
//
// Compare the printed tables, not the DevTools FPS average. FPS conflates the
// two threads; the split is what tells you which bottleneck you are hitting:
//
//   UI high, raster low     -> parsing, paint recording, allocation
//   raster high, UI low     -> draw call count, glyph atlas, overdraw
//
// The `boxdraw` and `fullscreen` workloads run mostly through the procedural
// glyph path, which bypasses the paragraph cache entirely. `plain` and `sgr`
// are the cache-friendly text paths.
//
// `static` is the odd one out and the most important number for damage
// tracking work: a full screen is drawn once, then exactly one cell changes
// per frame. The paint path still walks every visible line, so `lines/paint`
// stays at the viewport height and the UI time is almost entirely work that a
// damage-tracking renderer would skip. Any change that claims to add partial
// repaint has to move this row and leave the others alone.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xterm3/xterm.dart';

import 'bench/bench_stats.dart';

/// Frames written before measurement starts, to let caches and the shader
/// warm-up settle.
const _warmupFrames = 60;

/// Frames measured per workload.
const _measuredFrames = 400;

/// The grid every run has to measure, in cells.
///
/// The cell count drives every cost in the paint path, so it - not the pixel
/// size of the viewport - is what has to be held fixed between two builds.
/// Cell metrics are not stable across builds: `fix(ui): size cells from a
/// reference glyph, not the widest ASCII glyph` changed them, and a fixed
/// pixel viewport would therefore have handed the two builds different grids
/// and made the comparison meaningless. [_calibrate] sizes the viewport until
/// the grid comes out at exactly these numbers, whatever a cell measures.
/// Overridable so the same harness can measure a laptop-sized grid and a
/// full-screen one. The defaults are the grid every table in BENCHMARKS.md
/// before 2026-08-05 was taken at.
const _targetColumns = int.fromEnvironment('BENCH_COLS', defaultValue: 100);
const _targetRows = int.fromEnvironment('BENCH_ROWS', defaultValue: 37);

/// Where calibration starts. The 100x37 grid landed here on the build the
/// baseline table was measured on, so this is usually the answer already.
const _initialViewportSize = Size(1000, 600);

/// Bounds of the bisection search for a viewport extent, in logical pixels.
/// The upper bound has to stay inside the window: a `SizedBox` bigger than the
/// space the layout has is silently constrained, and the cell count would stop
/// responding to the size being asked for.
const _minimumExtent = 100.0;
const _maximumExtent = 2400.0;

/// How many resize attempts each axis of [_calibrate] gets before giving up.
const _calibrationAttempts = 24;

const _frameBudgetMs = 1000 / 60;

/// Names the build in the console output, so interleaved runs can be told
/// apart after the fact. Set by `script/bench-compare.sh`.
const _label = String.fromEnvironment('BENCH_LABEL', defaultValue: 'local');

/// Quit once the report has been printed. `script/bench-compare.sh` sets this
/// so `flutter run` returns instead of sitting at its interactive prompt.
const _exitWhenDone = bool.fromEnvironment('BENCH_EXIT');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BenchmarkPage(),
    );
  }
}

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final _terminal = Terminal(maxLines: 10000);
  final _controller = TerminalController();

  final _collected = <FrameTiming>[];
  final _results = <_Result>[];

  /// Logical size handed to the terminal view. Adjusted by [_calibrate] until
  /// the grid is [_targetColumns] x [_targetRows], then left alone.
  var _viewportSize = _initialViewportSize;

  /// Reads back the size the view was actually laid out at, which is not
  /// necessarily [_viewportSize]: a `SizedBox` larger than the window is
  /// silently constrained to it.
  final _viewKey = GlobalKey();

  /// Frames actually produced. `FrameTiming` callbacks are delivered
  /// asynchronously and in batches, so they cannot be used to count frames
  /// inside a window that has just closed - this counter can.
  var _frameCount = 0;

  var _status = 'starting';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _frameCount++);
    WidgetsBinding.instance.endOfFrame.then((_) => _run());
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _controller.dispose();
    _terminal.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _collected.addAll(timings);
  }

  /// Resizes the viewport until the terminal reports exactly
  /// [_targetColumns] x [_targetRows] cells, and reports what that took.
  ///
  /// Two builds only produce comparable frame times if they are painting the
  /// same number of cells. Cell metrics change between builds, so the pixel
  /// size that yields this grid is not a constant and has to be found at run
  /// time. Returns false if it could not be found, in which case the run is
  /// worthless and is abandoned rather than reported.
  Future<bool> _calibrate() async {
    // The two axes are independent - width decides columns, height decides
    // rows - so they are searched separately.
    final width = await _bisect(
      axis: 'width',
      target: _targetColumns,
      measure: () => _terminal.viewWidth,
      apply: (value) => _viewportSize = Size(value, _viewportSize.height),
    );
    if (width == null) return false;

    final height = await _bisect(
      axis: 'height',
      target: _targetRows,
      measure: () => _terminal.viewHeight,
      apply: (value) => _viewportSize = Size(_viewportSize.width, value),
    );
    if (height == null) return false;

    await _idle(3);
    final columns = _terminal.viewWidth;
    final rows = _terminal.viewHeight;
    if (columns != _targetColumns || rows != _targetRows) {
      _report('calibration did not hold: ${columns}x$rows after both axes');
      return false;
    }

    // Report the size the view was laid out at, not the size it was asked
    // for. They differ when the window is smaller than the request, and the
    // laid-out one is what the cell metrics have to be read against.
    final actual =
        (_viewKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    final effective = actual ?? Size(width, height);
    if (actual != null &&
        ((actual.width - width).abs() > 0.5 ||
            (actual.height - height).abs() > 0.5)) {
      _report('note: window clipped the view to '
          '${actual.width.toStringAsFixed(1)}x'
          '${actual.height.toStringAsFixed(1)} px (asked for '
          '${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)}). '
          'The grid is still $columns x $rows, so the comparison holds.');
    }

    _report('calibrated: ${columns}x$rows cells (${columns * rows}) at '
        '${effective.width.toStringAsFixed(1)}x'
        '${effective.height.toStringAsFixed(1)} logical px, '
        'cell <= ${(effective.width / columns).toStringAsFixed(2)}x'
        '${(effective.height / rows).toStringAsFixed(2)} px');
    return true;
  }

  /// Finds a viewport extent along one axis that yields exactly [target] cells.
  ///
  /// Bisection rather than arithmetic: cells-per-pixel cannot be derived from
  /// the cell count the layout reports (that only bounds it), and an estimate
  /// built from it converges far too slowly - it oscillated between 37 and 38
  /// rows for a dozen resizes when this was written that way. Cell count is
  /// monotonic in extent, which is all bisection needs.
  Future<double?> _bisect({
    required String axis,
    required int target,
    required int Function() measure,
    required void Function(double) apply,
  }) async {
    var low = _minimumExtent;
    var high = _maximumExtent;

    for (var attempt = 0; attempt < _calibrationAttempts; attempt++) {
      final mid = (low + high) / 2;
      setState(() => apply(mid));
      await _idle(3);

      final got = measure();
      if (got == target) return mid;
      if (got < target) {
        low = mid;
      } else {
        high = mid;
      }
      if (high - low < 0.5) {
        _report('calibration failed on $axis: cannot land on $target cells, '
            'closest $got between ${low.toStringAsFixed(1)} and '
            '${high.toStringAsFixed(1)} px');
        return null;
      }
    }
    _report('calibration failed on $axis: no $target-cell extent found in '
        '$_calibrationAttempts attempts');
    return null;
  }

  Future<void> _run() async {
    // Let layout settle so the terminal has been resized to the viewport.
    await _idle(10);

    _report('build: $_label');
    _report('release mode: $kReleaseMode  profile mode: $kProfileMode');
    if (!kProfileMode && !kReleaseMode) {
      _report('WARNING: debug mode. Numbers are not comparable to a real '
          'build. Re-run with --profile.');
    }

    if (!await _calibrate()) {
      _report('ABORT: could not reach a ${_targetColumns}x$_targetRows grid. '
          'The numbers below would not be comparable to another build, so '
          'none were taken.');
      setState(() => _status = 'aborted - see console');
      if (_exitWhenDone) exit(1);
      return;
    }

    final cols = _terminal.viewWidth;
    final rows = _terminal.viewHeight;

    final total = _warmupFrames + _measuredFrames;
    await _runWorkload('plain', _plainFrames(total));
    await _runWorkload('sgr', _sgrFrames(total));
    await _runWorkload('boxdraw', _boxFrames(total));
    await _runWorkload(
      'fullscreen',
      _fullscreenFrames(total, rows, cols),
      enterAltScreen: true,
    );
    await _runWorkload(
      'static',
      _staticFrames(total, rows, cols),
      enterAltScreen: true,
      setup: _staticSetup(rows, cols),
    );

    _printReport();
    await _runFlood();
    await _runFlood(frameBudgetMs: 8);
    await _runFlood(frameBudgetMs: 4);
    _report('');
    _report('flood      = chunks written as fast as the event loop takes them');
    _report('flood-paced = chunks written until the frame budget is spent, '
        'then the thread is handed back. Trades drain time for frames.');
    _report('');

    setState(() => _status = 'done - see console');

    if (_exitWhenDone) {
      // Give the console output a frame to flush before the process goes.
      await _idle(2);
      exit(0);
    }
  }

  /// The `cat bigfile` case. The four workloads above deliberately write once
  /// per frame, so they never test what happens when output arrives faster
  /// than frames can be produced. Here chunks are handed to `Terminal.write`
  /// as fast as the event loop will take them, exactly as a PTY stream
  /// listener does, and the interesting number is how many frames the UI still
  /// manages to produce while that is going on.
  Future<void> _runFlood({double? frameBudgetMs}) async {
    final label = frameBudgetMs == null
        ? 'flood'
        : 'flood-paced(${frameBudgetMs.toStringAsFixed(0)}ms)';
    setState(() => _status = 'running $label');

    _terminal.write('\x1b[0m\x1b[2J\x1b[3J\x1b[H');
    await _idle(5);

    final chunk = _floodChunk();
    const chunkCount = 4096;
    final bytes = chunk.length * chunkCount;

    _collected.clear();
    final framesBefore = _frameCount;
    final stopwatch = Stopwatch()..start();
    if (frameBudgetMs == null) {
      for (var i = 0; i < chunkCount; i++) {
        _terminal.write(chunk);
        // Yield the way a stream listener does, so frames get a chance to run
        // between chunks if the pipeline is not starved.
        await Future<void>.delayed(Duration.zero);
      }
    } else {
      // What a paced consumer would do: parse until the frame's share of the
      // budget is gone, then hand the thread back and let the frame happen.
      // Total drain time gets worse; the question is what it buys in frames.
      final budgetMicroseconds = (frameBudgetMs * 1000).round();
      var written = 0;
      while (written < chunkCount) {
        final slice = Stopwatch()..start();
        while (written < chunkCount &&
            slice.elapsedMicroseconds < budgetMicroseconds) {
          _terminal.write(chunk);
          written++;
        }
        await SchedulerBinding.instance.endOfFrame;
      }
    }
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMicroseconds / 1000;
    final framesDuringFlood = _frameCount - framesBefore;

    // Frame timings arrive a frame or two late, so flush before reading them.
    // The max below therefore covers the burst plus that short tail.
    await _idle(10);
    final worstUi = _collected.isEmpty
        ? 0.0
        : _collected
            .map((t) => t.buildDuration.inMicroseconds / 1000)
            .reduce((a, b) => a > b ? a : b);

    _report('$label: ${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB in '
        '${elapsedMs.toStringAsFixed(0)}ms '
        '(${(bytes / 1024 / elapsedMs).toStringAsFixed(1)} MiB/s), '
        '$framesDuringFlood frames '
        '(${(framesDuringFlood * 1000 / elapsedMs).toStringAsFixed(1)} fps), '
        'worst UI frame ${worstUi.toStringAsFixed(1)}ms');
  }

  Future<void> _runWorkload(
    String name,
    List<String> frames, {
    bool enterAltScreen = false,
    String? setup,
  }) async {
    setState(() => _status = 'running $name');

    // Reset scrollback and attributes so each workload starts from the same
    // terminal state regardless of what ran before it.
    _terminal.write('\x1b[0m\x1b[2J\x1b[3J\x1b[H');
    if (enterAltScreen) _terminal.write('\x1b[?1049h');
    // Screen content the per-frame writes are meant to sit on top of, written
    // once so it does not count as per-frame work.
    if (setup != null) _terminal.write(setup);
    await _idle(5);

    for (var i = 0; i < _warmupFrames; i++) {
      _terminal.write(frames[i]);
      await SchedulerBinding.instance.endOfFrame;
    }

    await _idle(5);
    _collected.clear();
    // Reset after warm-up so the cache ratios describe the steady state, not
    // the compulsory misses of the first frames.
    BenchStats.reset();

    for (var i = _warmupFrames; i < frames.length; i++) {
      _terminal.write(frames[i]);
      await SchedulerBinding.instance.endOfFrame;
    }

    // Snapshot the counters before flushing: `_idle` schedules extra frames,
    // and those repaints would otherwise be attributed to the workload.
    final stats = BenchStats.capture();

    await _idle(10);
    _results.add(_Result(name, List.of(_collected), stats));
    _collected.clear();

    if (enterAltScreen) _terminal.write('\x1b[?1049l');
    await _idle(5);
  }

  Future<void> _idle(int frames) async {
    for (var i = 0; i < frames; i++) {
      // endOfFrame only completes once a frame is actually scheduled, so nudge
      // the pipeline first - between workloads the terminal is quiet and
      // nothing else would schedule one.
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  void _printReport() {
    _report('');
    _report('workload    frames | UI p50  p90  p99 | RASTER p50  p90  p99 | '
        'over ${_frameBudgetMs.toStringAsFixed(1)}ms');
    for (final result in _results) {
      _report(result.format());
    }
    _report('');
    if (!BenchStats.available) {
      _report('paint-path counters: not available in this build - it predates '
          'TerminalRenderStats. Frame times above are unaffected.');
      _report('');
      setState(() => _status = 'done - see console');
      return;
    }
    _report('workload    paints | l/pnt | para%  look/f | glyf%  look/f');
    for (final result in _results) {
      _report(result.stats.format(result.name));
    }
    _report('');
    _report('l/pnt = lines visited per paint. With no damage tracking this is '
        'the viewport height on every workload, `static` included - that gap '
        'is what a partial-repaint renderer has to close.');
    _report('look/f = cache lookups per paint. para = shaped text, '
        'glyf = procedural (box drawing, Powerline, Braille).');
    _report('');
    setState(() => _status = 'done - see console');
  }

  void _report(String line) {
    // ignore: avoid_print
    print('[xterm3-bench] $line');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Center(
            child: SizedBox.fromSize(
              key: _viewKey,
              size: _viewportSize,
              child: TerminalView(
                _terminal,
                controller: _controller,
                padding: EdgeInsets.zero,
                // Keep every other option at its default: the benchmark should
                // measure the same code path a real embedder gets.
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _StatsReport on BenchStats {
  String format(String name) {
    String ratio(int hits, int lookups) {
      if (lookups == 0) return '    -';
      return '${(hits * 100 / lookups).toStringAsFixed(1).padLeft(4)}%';
    }

    final linesPerPaint = paints == 0
        ? '    -'
        : (paintedLines / paints).toStringAsFixed(1).padLeft(5);

    return '${name.padRight(11)} ${paints.toString().padLeft(6)} | '
        '$linesPerPaint | '
        '${ratio(paragraphHits, paragraphLookups)} '
        '${(paragraphLookups ~/ (paints == 0 ? 1 : paints)).toString().padLeft(6)} | '
        '${ratio(glyphHits, glyphLookups)} '
        '${(glyphLookups ~/ (paints == 0 ? 1 : paints)).toString().padLeft(6)}';
  }
}

class _Result {
  _Result(this.name, this.timings, this.stats);

  final String name;
  final List<FrameTiming> timings;
  final BenchStats stats;

  String format() {
    final ui = timings
        .map((t) => t.buildDuration.inMicroseconds / 1000)
        .toList(growable: false)
      ..sort();
    final raster = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000)
        .toList(growable: false)
      ..sort();

    if (ui.isEmpty) return '${name.padRight(11)}      0 | no frames captured';

    final over = timings
        .where((t) =>
            t.buildDuration.inMicroseconds / 1000 > _frameBudgetMs ||
            t.rasterDuration.inMicroseconds / 1000 > _frameBudgetMs)
        .length;

    return '${name.padRight(11)} ${ui.length.toString().padLeft(5)} | '
        '${_p(ui, 50)} ${_p(ui, 90)} ${_p(ui, 99)} | '
        '       ${_p(raster, 50)} ${_p(raster, 90)} ${_p(raster, 99)} | '
        '${(over * 100 / ui.length).toStringAsFixed(1)}%';
  }

  static String _p(List<double> sorted, int percentile) {
    final index = ((sorted.length - 1) * percentile / 100).round();
    return sorted[index].toStringAsFixed(1).padLeft(5);
  }
}

/// Plain scrolling ASCII. The cache-friendly path: a small set of distinct
/// glyphs, every one of them a paragraph cache hit after warm-up.
List<String> _plainFrames(int count) {
  return List.generate(count, (frame) {
    final buffer = StringBuffer();
    for (var row = 0; row < 3; row++) {
      final n = frame * 3 + row;
      buffer.write('[$n] /usr/local/lib/package_${n % 97}/'
          'source_file_${n % 31}.dart '
          '${n % 7 == 0 ? "WARN" : "ok"} ${n * 7919 % 100000}\r\n');
    }
    return buffer.toString();
  }, growable: false);
}

/// Scrolling text with heavy SGR churn. Same glyphs as `plain`, but many more
/// distinct colors, so the paragraph cache key space is much larger.
List<String> _sgrFrames(int count) {
  return List.generate(count, (frame) {
    final buffer = StringBuffer();
    for (var row = 0; row < 3; row++) {
      final n = frame * 3 + row;
      for (var segment = 0; segment < 8; segment++) {
        buffer.write('\x1b[38;5;${(n * 13 + segment * 31) % 256}m');
        buffer.write('segment$segment ');
      }
      buffer.write('\x1b[0m\r\n');
    }
    return buffer.toString();
  }, growable: false);
}

const _boxGlyphs = '─│┌┐└┘├┤┼█▓▒░▄▀';

/// Box drawing and block elements. These go through the procedural glyph
/// painter, which rebuilds paths every frame and never touches the paragraph
/// cache - the path a TUI with borders and meters spends most of its time in.
List<String> _boxFrames(int count) {
  return List.generate(count, (frame) {
    final buffer = StringBuffer();
    for (var row = 0; row < 3; row++) {
      final n = frame * 3 + row;
      buffer.write('\x1b[38;5;${(n * 7) % 256}m');
      for (var column = 0; column < 60; column++) {
        buffer.write(_boxGlyphs[(n + column) % _boxGlyphs.length]);
      }
      buffer.write('\x1b[0m\r\n');
    }
    return buffer.toString();
  }, growable: false);
}

/// The screen the `static` workload leaves untouched: a full viewport of
/// ordinary colored text, written once before measurement starts.
String _staticSetup(int rows, int columns) {
  final buffer = StringBuffer();
  for (var row = 0; row < rows; row++) {
    buffer.write('\x1b[${row + 1};1H');
    buffer.write('\x1b[38;5;${(row * 11) % 256}m');
    final line = StringBuffer();
    var word = 0;
    while (line.length < columns) {
      line.write(
          'field_${(row * 17 + word) % 89}.value=${(row * 7919 + word) % 10000} ');
      word++;
    }
    buffer.write(line.toString().substring(0, columns));
    buffer.write('\x1b[0m');
  }
  return buffer.toString();
}

/// A screen that is entirely static except for one spinning cell in the
/// bottom-right corner - the minimum amount of damage a frame can carry.
///
/// Everything the paint path does beyond redrawing that single cell is waste
/// that damage tracking is supposed to remove, so the gap between this
/// workload and `fullscreen` is the size of the prize.
const _spinner = '|/-\\';

List<String> _staticFrames(int count, int rows, int columns) {
  return List.generate(count, (frame) {
    return '\x1b[$rows;${columns - 1}H${_spinner[frame % _spinner.length]}';
  }, growable: false);
}

/// One PTY-sized chunk of ordinary program output, ~8 KiB.
String _floodChunk() {
  final buffer = StringBuffer();
  var line = 0;
  while (buffer.length < 8192) {
    buffer.write('-rw-r--r--  1 user  staff  ${line * 7919 % 1000000} '
        'Aug  2 12:${(line % 60).toString().padLeft(2, '0')} '
        'file_${line}_with_a_reasonably_long_name.dart\r\n');
    line++;
  }
  return buffer.toString();
}

/// Cursor-addressed full-screen redraw on the alternate screen: every cell is
/// rewritten every frame, with a moving bar and per-row colors. This is the
/// deterministic stand-in for htop, without htop's run-to-run variance.
List<String> _fullscreenFrames(int count, int rows, int columns) {
  return List.generate(count, (frame) {
    final buffer = StringBuffer();
    for (var row = 0; row < rows; row++) {
      buffer.write('\x1b[${row + 1};1H');
      buffer.write('\x1b[48;5;${(row * 3 + frame) % 256}m'
          '\x1b[38;5;${(row * 11 + frame) % 256}m');
      final bar = (frame + row) % columns;
      for (var column = 0; column < columns; column++) {
        buffer.write(column < bar ? '█' : ' ');
      }
      buffer.write('\x1b[0m');
    }
    return buffer.toString();
  }, growable: false);
}
