import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/math_expression.dart';

void main() {
  group('evaluateMathExpression', () {
    test('respects operator precedence and parentheses', () {
      expect(evaluateMathExpression('2 + 3 * 4'), 14);
      expect(evaluateMathExpression('(2 + 3) * 4'), 20);
      expect(evaluateMathExpression('10 / 4'), 2.5);
      expect(evaluateMathExpression('10 % 3'), 1);
    });

    test('handles unary minus and decimals', () {
      expect(evaluateMathExpression('-5 + 2'), -3);
      expect(evaluateMathExpression('3.5 * 2'), 7);
      expect(evaluateMathExpression('-(2 + 3)'), -5);
    });

    test('evaluates functions in radians and pow for exponentiation', () {
      expect(evaluateMathExpression('sqrt(16)'), 4);
      expect(evaluateMathExpression('pow(2, 10)'), 1024);
      expect(evaluateMathExpression('abs(-7)'), 7);
      expect(evaluateMathExpression('max(1, 9, 4)'), 9);
      expect(evaluateMathExpression('min(1, 9, 4)'), 1);
      expect(evaluateMathExpression('sin(0)'), 0);
      expect(evaluateMathExpression('sin(30)'), closeTo(math.sin(30), 1e-12));
    });

    test('supports pi / e constants (case-insensitive)', () {
      expect(evaluateMathExpression('pi'), closeTo(math.pi, 1e-12));
      expect(evaluateMathExpression('PI'), closeTo(math.pi, 1e-12));
      expect(evaluateMathExpression('e'), closeTo(math.e, 1e-12));
      expect(evaluateMathExpression('2 * pi'), closeTo(2 * math.pi, 1e-12));
    });

    test('log is natural; log10 / log2 derived', () {
      expect(evaluateMathExpression('log(e)'), closeTo(1, 1e-12));
      expect(evaluateMathExpression('log10(1000)'), closeTo(3, 1e-12));
      expect(evaluateMathExpression('log2(8)'), closeTo(3, 1e-12));
    });

    test('parses scientific notation', () {
      expect(evaluateMathExpression('1e3'), 1000);
      expect(evaluateMathExpression('2.5e-1'), 0.25);
    });

    test('throws on malformed input', () {
      expect(() => evaluateMathExpression('2 +'), throwsFormatException);
      expect(() => evaluateMathExpression('(2 + 3'), throwsFormatException);
      expect(() => evaluateMathExpression('foo(2)'), throwsFormatException);
      expect(() => evaluateMathExpression('2 3'), throwsFormatException);
      expect(() => evaluateMathExpression('pow(2)'), throwsFormatException);
    });
  });
}
