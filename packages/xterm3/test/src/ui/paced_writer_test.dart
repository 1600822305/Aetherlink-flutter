import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

/// Deterministic stand-in for [Stopwatch]: reports zero elapsed for the
/// first [chunksPerPass] reads of `elapsed`, then reports far past any
/// budget. Makes pass sizes an exact chunk count instead of a race against
/// wall-clock resolution (see Bulgu 2 in CODE_REVIEW_2026-08-06.md).
class _SteppedStopwatch implements Stopwatch {
  _SteppedStopwatch(this.chunksPerPass);

  final int chunksPerPass;
  var _reads = 0;

  @override
  void start() {}
  @override
  void stop() {}
  @override
  void reset() {}
  @override
  bool get isRunning => true;
  @override
  int get elapsedTicks => elapsed.inMicroseconds;
  @override
  int get elapsedMicroseconds => elapsed.inMicroseconds;
  @override
  int get elapsedMilliseconds => elapsed.inMilliseconds;
  @override
  int get frequency => 1000000;
  @override
  Duration get elapsed {
    _reads++;
    return _reads > chunksPerPass ? const Duration(seconds: 1) : Duration.zero;
  }
}

void main() {
  /// Drives the writer without a frame pipeline: every yield completes only
  /// when the test says so, which is what makes the pacing observable.
  late List<Completer<void>> frames;
  Future<void> waitForFrame() {
    final completer = Completer<void>();
    frames.add(completer);
    return completer.future;
  }

  Future<void> pumpFrame() async {
    expect(frames, isNotEmpty, reason: 'writer is not waiting for a frame');
    frames.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() => frames = []);

  test('writes everything in order', () async {
    final terminal = Terminal()..resize(20, 5);
    final writer = PacedTerminalWriter(
      terminal,
      // Large enough that one pass takes it all, so this test is about
      // ordering rather than pacing.
      frameBudget: const Duration(seconds: 10),
      waitForFrame: waitForFrame,
    );

    writer.write('one ');
    writer.write('two ');
    writer.write('three');
    await Future<void>.delayed(Duration.zero);

    expect(terminal.buffer.lines[0].getText().trimRight(), 'one two three');
    expect(writer.hasPendingOutput, isFalse);
    expect(frames, isEmpty, reason: 'nothing needed to be deferred');
  });

  test('defers output past the budget to later frames', () async {
    final terminal = Terminal()..resize(20, 5);
    // Fake clock instead of a real 1us budget: a wall-clock budget that
    // close to Stopwatch resolution made pass sizes - and therefore whether
    // this test passed at all - a hardware lottery. 10 chunks/pass is now
    // exact, so the frame count below is an equality, not a bound.
    final writer = PacedTerminalWriter(
      terminal,
      frameBudget: const Duration(milliseconds: 8),
      waitForFrame: waitForFrame,
      createStopwatch: () => _SteppedStopwatch(9),
    );

    const chunkCount = 200;
    for (var i = 0; i < chunkCount; i++) {
      writer.write('x');
    }
    await Future<void>.delayed(Duration.zero);

    expect(writer.hasPendingOutput, isTrue,
        reason: 'first pass should have written only 10 of $chunkCount chunks');

    var pumps = 0;
    while (writer.hasPendingOutput) {
      await pumpFrame();
      pumps++;
    }
    expect(pumps, equals(19), reason: '190 remaining chunks at 10/pass');

    expect(terminal.buffer.lines[0].getText().trimRight(), 'x' * 20);
    expect(frames, isEmpty);
  });

  test('flush writes pending output immediately', () async {
    final terminal = Terminal()..resize(400, 5);
    final writer = PacedTerminalWriter(
      terminal,
      frameBudget: const Duration(milliseconds: 8),
      waitForFrame: waitForFrame,
      createStopwatch: () => _SteppedStopwatch(9),
    );

    for (var i = 0; i < 200; i++) {
      writer.write('x');
    }
    await Future<void>.delayed(Duration.zero);
    expect(writer.hasPendingOutput, isTrue);

    writer.flush();

    expect(terminal.buffer.lines[0].getText().trimRight(), 'x' * 200);
    expect(writer.hasPendingOutput, isFalse);
  });

  test('dispose drops pending output', () async {
    final terminal = Terminal()..resize(200, 5);
    final writer = PacedTerminalWriter(
      terminal,
      frameBudget: const Duration(milliseconds: 8),
      waitForFrame: waitForFrame,
      createStopwatch: () => _SteppedStopwatch(9),
    );

    for (var i = 0; i < 200; i++) {
      writer.write('x');
    }
    await Future<void>.delayed(Duration.zero);
    final writtenBeforeDispose =
        terminal.buffer.lines[0].getText().trimRight().length;
    expect(writer.hasPendingOutput, isTrue);

    writer.dispose();
    while (frames.isNotEmpty) {
      await pumpFrame();
    }

    expect(writer.hasPendingOutput, isFalse);
    expect(terminal.buffer.lines[0].getText().trimRight().length,
        writtenBeforeDispose,
        reason: 'nothing queued at disposal should reach the terminal');

    // Writes after disposal are ignored rather than throwing.
    writer.write('y');
    await Future<void>.delayed(Duration.zero);
    expect(terminal.buffer.lines[0].getText(), isNot(contains('y')));
  });

  test('rejects a non-positive frame budget', () {
    expect(
      () => PacedTerminalWriter(Terminal(), frameBudget: Duration.zero),
      throwsArgumentError,
    );
  });
}
