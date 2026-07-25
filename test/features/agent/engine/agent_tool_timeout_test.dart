import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';

void main() {
  group('resolveAgentToolTimeout（引擎兜底超时分级）', () {
    const fallback = Duration(minutes: 5);

    test('未传超时参数 → 维持预算一刀切值', () {
      expect(
        resolveAgentToolTimeout(fallback: fallback, requestedTimeoutMs: null),
        fallback,
      );
      expect(
        resolveAgentToolTimeout(fallback: fallback, requestedTimeoutMs: 0),
        fallback,
      );
      expect(
        resolveAgentToolTimeout(fallback: fallback, requestedTimeoutMs: -1),
        fallback,
      );
    });

    test('超时参数不长于兜底 → 不收紧，仍用兜底', () {
      expect(
        resolveAgentToolTimeout(fallback: fallback, requestedTimeoutMs: 120000),
        fallback,
      );
    });

    test('超时参数超过兜底 → 放宽为参数值 + 宽限', () {
      expect(
        resolveAgentToolTimeout(fallback: fallback, requestedTimeoutMs: 480000),
        const Duration(milliseconds: 480000) + kAgentToolTimeoutGrace,
      );
    });

    test('超时参数超上限 → 按上限封顶再加宽限', () {
      expect(
        resolveAgentToolTimeout(
          fallback: fallback,
          requestedTimeoutMs: 3600000,
        ),
        kAgentToolTimeoutMax + kAgentToolTimeoutGrace,
      );
    });
  });

  group('clipAgentTimeoutPartialOutput（超时部分输出裁剪）', () {
    test('不超预算 → 原样返回', () {
      expect(clipAgentTimeoutPartialOutput('short output'), 'short output');
    });

    test('超预算 → 保留头尾、标注省略字符数', () {
      final long = 'H' * 2000 + 'M' * 5000 + 'T' * 4000;
      final clipped = clipAgentTimeoutPartialOutput(long);
      expect(clipped.length, lessThan(long.length));
      expect(clipped, startsWith('H' * kAgentTimeoutPartialHeadChars));
      expect(clipped, endsWith('T' * kAgentTimeoutPartialTailChars));
      expect(clipped, contains('中间省略'));
    });
  });
}
