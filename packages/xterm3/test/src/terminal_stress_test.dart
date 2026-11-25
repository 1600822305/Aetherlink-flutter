import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

import '../_support/terminal_invariants.dart';

void main() {
  test('Terminal survives deterministic output and resize stress', () {
    const seed = 0x5eeda11;
    const checkEveryN = 50;
    final random = Random(seed);
    final terminal = Terminal(maxLines: 500)..resize(80, 24);

    for (var iteration = 0; iteration < 20000; iteration++) {
      final length = random.nextInt(128);
      final codeUnits = List<int>.generate(
        length,
        (_) => random.nextInt(0x100),
        growable: false,
      );
      terminal.write(String.fromCharCodes(codeUnits));

      if (iteration % 13 == 0) {
        terminal.resize(random.nextInt(159) + 1, random.nextInt(79) + 1);
      }

      final shouldCheck =
          iteration % checkEveryN == 0 || iteration == 20000 - 1;
      if (shouldCheck) {
        checkTerminalInvariants(
          terminal,
          random,
          context: 'seed 0x${seed.toRadixString(16)}, iteration $iteration',
        );
      }
    }
  });
}
