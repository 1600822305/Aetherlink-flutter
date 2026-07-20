import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_trigger.dart';

void main() {
  group('effectiveContextWindowTokens', () {
    test('大窗口减去 20k 摘要预留', () {
      expect(effectiveContextWindowTokens(200000), 180000);
      expect(effectiveContextWindowTokens(128000), 108000);
    });

    test('小窗口预留按窗口 1/4 封顶（不被预留吃掉大半）', () {
      expect(effectiveContextWindowTokens(8000), 8000 - 2000);
      expect(effectiveContextWindowTokens(32000), 32000 - 8000);
    });
  });

  group('compactionTriggerTokens', () {
    test('触发阈值 = 有效窗口 × 92%', () {
      expect(compactionTriggerTokens(200000), (180000 * 0.92).floor());
      expect(compactionTriggerTokens(8000), (6000 * 0.92).floor());
    });
  });

  group('shouldTriggerCompaction', () {
    test('有 usage + 窗口：按 token 判定', () {
      expect(
        shouldTriggerCompaction(
          contextTokens: 170000,
          contextLimitTokens: 200000,
          estimatedChars: 0,
          fallbackTriggerChars: 120000,
        ),
        isTrue,
      );
      expect(
        shouldTriggerCompaction(
          contextTokens: 100000,
          contextLimitTokens: 200000,
          estimatedChars: 999999,
          fallbackTriggerChars: 120000,
        ),
        isFalse,
        reason: 'token 路径生效时忽略字符估算',
      );
    });

    test('无 usage（0）：回退字符估算', () {
      expect(
        shouldTriggerCompaction(
          contextTokens: 0,
          contextLimitTokens: 200000,
          estimatedChars: 130000,
          fallbackTriggerChars: 120000,
        ),
        isTrue,
      );
      expect(
        shouldTriggerCompaction(
          contextTokens: 0,
          contextLimitTokens: 200000,
          estimatedChars: 100000,
          fallbackTriggerChars: 120000,
        ),
        isFalse,
      );
    });

    test('窗口未知（0）：回退字符估算', () {
      expect(
        shouldTriggerCompaction(
          contextTokens: 500000,
          contextLimitTokens: 0,
          estimatedChars: 100000,
          fallbackTriggerChars: 120000,
        ),
        isFalse,
      );
    });

    test('不同窗口大小（8k/128k/200k）行为正确', () {
      for (final (window, below, above) in [
        (8000, 5000, 5600),
        (128000, 99000, 99500),
        (200000, 165000, 166000),
      ]) {
        expect(
          shouldTriggerCompaction(
            contextTokens: below,
            contextLimitTokens: window,
            estimatedChars: 0,
            fallbackTriggerChars: 120000,
          ),
          isFalse,
          reason: '$window 窗口 $below tokens 不应触发',
        );
        expect(
          shouldTriggerCompaction(
            contextTokens: above,
            contextLimitTokens: window,
            estimatedChars: 0,
            fallbackTriggerChars: 120000,
          ),
          isTrue,
          reason: '$window 窗口 $above tokens 应触发',
        );
      }
    });
  });
}
