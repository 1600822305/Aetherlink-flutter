// Fuzzes Terminal.write, which feeds every byte through EscapeParser
// (lib/src/core/escape/parser.dart, ~3077 lines of state transitions). Rather
// than instantiating EscapeParser directly against a mock handler, we drive
// it through Terminal so the invariant helper from the stress test
// (test/_support/terminal_invariants.dart) can validate real buffer/cursor
// state after each burst of adversarial input.
//
// Run harder locally with, e.g.:
//   XTERM3_FUZZ_ROUNDS=20000 flutter test test/src/core/escape/parser_fuzz_test.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

import '../../../_support/terminal_invariants.dart';

const _c0 = [
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // includes BEL
  0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
  // 0x18 (CAN) and 0x1a (SUB) are exercised separately below.
  0x19, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
];

const _csiPrefixes = ['', '?', '>', '=', r'$'];

// A representative slice of CSI final bytes (letters plus a few punctuation
// finals actually used by the parser, e.g. '@', '`', '~').
const _csiFinals = [
  '@',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'P',
  'S',
  'T',
  'X',
  'Z',
  '`',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'l',
  'm',
  'n',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  '~',
];

const _wideChars = [0x4e2d, 0x56fd, 0x65e5, 0x672c]; // CJK, width 2
const _combiningChars = [0x0301, 0x0308, 0x0327]; // combining accents
const _emoji = [0x1f600, 0x1f680, 0x1f44d]; // astral plane, surrogate pairs

/// Builds one "logical" escape/text token as a single string. The caller may
/// choose to deliver it whole or split across several [Terminal.write] calls.
String _randomToken(Random random) {
  switch (random.nextInt(11)) {
    case 0:
      return _randomPlainText(random);
    case 1:
      return _randomCsi(random);
    case 2:
      return _randomOsc(random, terminated: true);
    case 3:
      return _randomOsc(random, terminated: false);
    case 4:
      return _randomDcs(random, oversized: false);
    case 5:
      return _randomDcs(random, oversized: true);
    case 6:
      return '\x1b'; // lone ESC
    case 7:
      return '\x1b${String.fromCharCode(_c0[random.nextInt(_c0.length)])}';
    case 8:
      return '\x1b\x1b'; // ESC ESC
    case 9:
      return String.fromCharCode(random.nextBool() ? 0x18 : 0x1a);
    default:
      return _randomCsiInterruptedByCancel(random);
  }
}

String _randomPlainText(Random random) {
  final buffer = StringBuffer();
  final length = random.nextInt(20) + 1;
  for (var i = 0; i < length; i++) {
    switch (random.nextInt(4)) {
      case 0:
        buffer.writeCharCode(0x20 + random.nextInt(0x5f)); // printable ASCII
      case 1:
        buffer.writeCharCode(_wideChars[random.nextInt(_wideChars.length)]);
      case 2:
        buffer.writeCharCode(
          _combiningChars[random.nextInt(_combiningChars.length)],
        );
      default:
        buffer.writeCharCode(_emoji[random.nextInt(_emoji.length)]);
    }
  }
  return buffer.toString();
}

String _randomParams(Random random) {
  final count = random.nextInt(4);
  return List.generate(count, (_) => random.nextInt(200)).join(';');
}

String _randomCsi(Random random) {
  final prefix = _csiPrefixes[random.nextInt(_csiPrefixes.length)];
  final params = _randomParams(random);
  final finalByte = _csiFinals[random.nextInt(_csiFinals.length)];
  // Occasionally inject a C0 control byte in the middle of the parameter
  // string; real terminals execute C0 controls immediately even mid-sequence.
  final injected = random.nextBool()
      ? String.fromCharCode(_c0[random.nextInt(_c0.length)])
      : '';
  return '\x1b[$prefix$params$injected$finalByte';
}

String _randomCsiInterruptedByCancel(Random random) {
  final prefix = _csiPrefixes[random.nextInt(_csiPrefixes.length)];
  final params = _randomParams(random);
  final cancel = random.nextBool() ? '\x18' : '\x1a';
  // No final byte: CAN/SUB should abort the in-flight sequence.
  return '\x1b[$prefix$params$cancel';
}

String _randomOscPayload(Random random, {required int length}) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    // Keep payload printable-ish but allow the occasional semicolon/backslash
    // to stress the tokenizer.
    buffer.writeCharCode(0x20 + random.nextInt(0x5f));
  }
  return buffer.toString();
}

String _randomOsc(Random random, {required bool terminated}) {
  final ps = random.nextInt(1200);
  final payload = _randomOscPayload(random, length: random.nextInt(24));
  var body = '\x1b]$ps;$payload';
  if (random.nextBool()) {
    // Embed a lone ESC inside the payload (not forming ST) before whatever
    // terminator (or lack thereof) follows.
    body += '\x1b';
    body += _randomOscPayload(random, length: random.nextInt(8));
  }
  if (!terminated) return body;
  return body + (random.nextBool() ? '\x07' : '\x1b\\');
}

String _randomDcs(Random random, {required bool oversized}) {
  final params = _randomParams(random);
  final finalByte = String.fromCharCode(0x40 + random.nextInt(0x3f));
  final payloadLength =
      oversized ? 20000 + random.nextInt(5000) : random.nextInt(16);
  final payload = _randomOscPayload(random, length: payloadLength);
  return '\x1bP$params$finalByte$payload\x1b\\';
}

/// Splits [token] into 1-4 pieces of random (possibly zero) length so it can
/// be delivered across multiple [Terminal.write] calls, exercising the
/// parser's rollback/resume path for sequences truncated mid-write.
List<String> _splitForDelivery(Random random, String token) {
  if (token.isEmpty) return [token];
  final pieces = random.nextInt(4) + 1;
  if (pieces == 1) return [token];

  // Cut points may repeat (producing empty chunks, i.e. empty write() calls,
  // which is a valid and useful thing to fuzz). Using a plain sorted list
  // instead of a Set avoids ever looping for more distinct values than a
  // short token can offer.
  final cuts = List.generate(
    pieces - 1,
    (_) => random.nextInt(token.length + 1),
  )..sort();

  final chunks = <String>[];
  var start = 0;
  for (final cut in cuts) {
    chunks.add(token.substring(start, cut));
    start = cut;
  }
  chunks.add(token.substring(start));
  return chunks;
}

void _runFuzzSeed(int seed, int rounds) {
  final random = Random(seed);
  final terminal = Terminal(maxLines: 500)..resize(80, 24);
  final invariantRandom = Random(seed ^ 0x7ffffff);

  const checkEveryN = 25;
  for (var round = 0; round < rounds; round++) {
    final token = _randomToken(random);
    final splitAcrossWrites = random.nextInt(3) == 0;
    if (splitAcrossWrites) {
      for (final chunk in _splitForDelivery(random, token)) {
        terminal.write(chunk);
      }
    } else {
      terminal.write(token);
    }

    if (round % 11 == 0) {
      terminal.resize(random.nextInt(159) + 1, random.nextInt(79) + 1);
    }

    final shouldCheck = round % checkEveryN == 0 || round == rounds - 1;
    if (shouldCheck) {
      checkTerminalInvariants(
        terminal,
        invariantRandom,
        context: 'seed 0x${seed.toRadixString(16)}, round $round, '
            'token: ${token.codeUnits}',
      );
    }
  }
}

void main() {
  // Fixed seeds keep CI deterministic; each covers a different slice of the
  // random token space via its distinct PRNG stream.
  const seeds = [
    0x5eeda11,
    0xc0ffee,
    0xfeedface,
    0xdeadbeef,
    0x1337,
  ];

  // Allow a much longer local run via an env var, e.g.:
  //   XTERM3_FUZZ_ROUNDS=20000 flutter test test/src/core/escape/parser_fuzz_test.dart
  final roundsPerSeed =
      int.tryParse(Platform.environment['XTERM3_FUZZ_ROUNDS'] ?? '') ?? 400;

  for (final seed in seeds) {
    test(
      'parser fuzz survives adversarial input '
      '(seed 0x${seed.toRadixString(16)})',
      () {
        _runFuzzSeed(seed, roundsPerSeed);
      },
    );
  }

  group('regressions found by this fuzzer', () {
    // These are RAW (unminimized) repros: they replay the exact same
    // deterministic token/resize stream that _runFuzzSeed produces for the
    // given seed, for exactly as many rounds as it takes to reach the state
    // that used to break. They were found by running this suite with
    // XTERM3_FUZZ_ROUNDS=5000 (the default of 400 rounds is too short to
    // reach any of them, which is why the tests above stay green in normal
    // CI runs).
    //
    // Every one of them passes now. Each records a bug that was real, the
    // state that produced it, and the fix that closed it, so that a change
    // to the wide-cell handling has something concrete to fail against.
    // Do not "fix" a failure here by weakening an assertion - see the
    // invariant helper in test/_support/terminal_invariants.dart for what
    // is supposed to hold.

    test(
      'a width-2 cell no longer ends up in the last column of a line with '
      'no placeholder cell after it (seed 0xdeadbeef, round 506)',
      () {
        // Every width-2 ("wide") cell must be followed by a width-0
        // placeholder cell with code point 0 - see Buffer.writeChar in
        // lib/src/core/buffer/buffer.dart, which always writes the wide cell
        // and its placeholder as a pair.
        //
        // This used to break: after round 506 of this seed's stream, line 14
        // held a wide cell at column 59, the LAST cell of the line, with no
        // room for its placeholder at all - and that dangling lead went on to
        // crash reflow on a later resize (the next test). Closed by
        // BufferLine._repairWideCellPairing, which keeps the pairing intact
        // inside setCell itself rather than trusting each call site to clear
        // the neighbouring half first.
        final random = Random(0xdeadbeef);
        final terminal = Terminal(maxLines: 500)..resize(80, 24);

        for (var round = 0; round <= 506; round++) {
          final token = _randomToken(random);
          if (random.nextInt(3) == 0) {
            for (final chunk in _splitForDelivery(random, token)) {
              terminal.write(chunk);
            }
          } else {
            terminal.write(token);
          }
          if (round % 11 == 0) {
            terminal.resize(random.nextInt(159) + 1, random.nextInt(79) + 1);
          }
        }

        final line = terminal.buffer.lines[14];
        expect(line.getWidth(59), isNot(2),
            reason: 'a wide cell at the last column of the line has no '
                'room for its placeholder cell');
      },
    );

    test(
      'Buffer.resize no longer throws RangeError(-1) during reflow after '
      'the above corruption (seed 0xdeadbeef, round 2827)',
      () {
        // Resize, and the reflow it triggers, must never throw for any
        // prior buffer content - at worst content is truncated or dropped.
        //
        // This used to throw: replaying this seed's stream for 2827 rounds
        // and then calling terminal.resize(...) raised `RangeError (length):
        // Invalid value: Not in inclusive range 0..511: -1` from
        // BufferLine.getWidth, via _LineReflow._addPart in
        // lib/src/core/reflow.dart, _LineReflow.add, reflow(), and
        // Buffer.resize. It was the dangling wide-cell-with-no-placeholder
        // state from the test above reaching reflow, which read one column
        // past where it expected a placeholder and computed a negative
        // index. Fixing the pairing at its source closed this too - reflow
        // never sees the state that produced the negative index.
        final random = Random(0xdeadbeef);
        final terminal = Terminal(maxLines: 500)..resize(80, 24);

        for (var round = 0; round <= 2827; round++) {
          final token = _randomToken(random);
          if (random.nextInt(3) == 0) {
            for (final chunk in _splitForDelivery(random, token)) {
              terminal.write(chunk);
            }
          } else {
            terminal.write(token);
          }
          if (round % 11 == 0) {
            terminal.resize(random.nextInt(159) + 1, random.nextInt(79) + 1);
          }
        }
        // The RangeError happens on the very next resize call at round
        // 2827; the loop above already performs it (round 2827 % 11 != 0
        // is false is not guaranteed, so assert directly below as well for
        // a self-contained repro independent of the loop's own resize call).
        expect(() => terminal.resize(40, 20), returnsNormally);
      },
    );

    test(
      'a wide cell\'s placeholder is no longer overwritten with non-zero '
      'content by BufferLine.resize exposing a stale mid-range lead while '
      'growing (seed 0xc0ffee, round 3225)',
      () {
        // Expected behaviour: a width-2 cell must always be immediately
        // followed by a width-0 placeholder cell with code point 0.
        //
        // Root cause (found via XTERM3_FUZZ_ROUNDS=5000; the default
        // 400-round CI run is too short to reach it): unrelated to the ESC
        // ESC token that happens to be the last token processed before this
        // round's invariant check runs. The actual corruption is introduced
        // earlier, by a `terminal.resize` at round 3223 that grows a line
        // back up after it had previously been shrunk repeatedly at
        // different widths. `BufferLine.resize` intentionally preserves
        // cell data past the old length when growing (so it can reappear
        // if the line is grown back after a shrink), but each individual
        // shrink/grow only ever checked the single cell sitting exactly at
        // *that* call's own boundary for a dangling wide-char lead - a
        // lead+placeholder pair frozen mid-pair by an *earlier* resize with
        // a different boundary, now somewhere in the *middle* of a later,
        // larger newly-exposed range, was never re-validated. Once such a
        // pair drifts out of sync (e.g. only the placeholder half gets
        // overwritten by a subsequent write while shrunk to a width that no
        // longer exposes the lead), regrowing past it resurrects the
        // mismatch verbatim. Fixed in BufferLine.resize by scanning the
        // *entire* newly exposed range on every grow - not just its last
        // column - and clearing any wide-char lead left without a valid
        // placeholder.
        expect(() => _runFuzzSeed(0xc0ffee, 3226), returnsNormally);
      },
    );

    test(
      'a wide cell\'s placeholder is overwritten with a non-zero-width '
      'filler cell when a wide char doesn\'t fit before the right margin '
      '(seed 0x1337, round 6200)',
      () {
        // Expected behaviour: a width-2 cell must always be immediately
        // followed by a width-0 placeholder cell with code point 0.
        //
        // Observed (found via XTERM3_FUZZ_ROUNDS=20000; 400 and 5000 rounds
        // are both too short to reach this): the periodic invariant sampler
        // in checkTerminalInvariants only inspects one random line every 25
        // rounds, so it doesn't report this until round 6200, well after the
        // corruption actually happens. Root cause confirmed directly (by
        // instrumenting the write path and re-running this exact seed):
        // Buffer.writeChar has a branch for when a width-2 character doesn't
        // fit in the last column before the right margin (buffer.dart,
        // around `cellWidth == 2 && _cursorX == rightLimit - 1`). That
        // branch writes a width-1/code-point-0 filler cell at `_cursorX`
        // *before* wrapping to the next line, so cursor movement past the
        // margin is later recognisable. Unlike the ordinary write path a
        // few lines below it - which always calls
        // `line.clearWideCellAt(_cursorX, ...)` first - this branch never
        // clears `_cursorX` first. When cursor positioning (e.g. CUP) has
        // left `_cursorX` sitting on the placeholder half of an existing
        // wide pair (i.e. `_cursorX - 1` holds a width-2 lead), the filler
        // write silently destroys that placeholder in place - replacing its
        // width-0/code-point-0 content with width-1/code-point-0 - while
        // leaving the neighbouring lead cell still marked width 2. That
        // lead is now dangling with a corrupted "placeholder".
        expect(() => _runFuzzSeed(0x1337, 6201), returnsNormally);
      },
    );

    test(
      'same wide-char/placeholder corruption as the 0x1337 regression above, '
      'reached via a different token stream (seed 0xdeadbeef, round 6325)',
      () {
        // Same root cause as the 0x1337 regression immediately above:
        // confirmed via the same instrumentation that this seed also hits
        // Buffer.writeChar's un-clamped filler-cell write at
        // `cellWidth == 2 && _cursorX == rightLimit - 1`, corrupting an
        // existing wide pair's placeholder in place (much earlier, around
        // round 5551, than the round-6325 invariant sample that reports
        // it). Kept as a separate test because it was found independently
        // by the fuzzer at a different seed/round and confirms the bug
        // isn't specific to one token stream.
        expect(() => _runFuzzSeed(0xdeadbeef, 6326), returnsNormally);
      },
    );
  });
}
