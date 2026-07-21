import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_guard.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';

void main() {
  group('isNearCompactionThreshold', () {
    test('token 路径：达到阈值 90% 进入预警区间，超过阈值不再预警', () {
      const window = 200000;
      final trigger = compactionTriggerTokens(window);
      final warnAt = (trigger * 0.9).floor();
      expect(
        isNearCompactionThreshold(
          contextTokens: warnAt,
          contextLimitTokens: window,
          estimatedChars: 0,
          fallbackTriggerChars: 120000,
        ),
        isTrue,
      );
      expect(
        isNearCompactionThreshold(
          contextTokens: warnAt - 1,
          contextLimitTokens: window,
          estimatedChars: 0,
          fallbackTriggerChars: 120000,
        ),
        isFalse,
      );
      expect(
        isNearCompactionThreshold(
          contextTokens: trigger + 1,
          contextLimitTokens: window,
          estimatedChars: 0,
          fallbackTriggerChars: 120000,
        ),
        isFalse,
        reason: '已过阈值走压缩，不预警',
      );
    });

    test('无 usage 回退字符估算', () {
      expect(
        isNearCompactionThreshold(
          contextTokens: 0,
          contextLimitTokens: 200000,
          estimatedChars: 110000,
          fallbackTriggerChars: 120000,
        ),
        isTrue,
      );
      expect(
        isNearCompactionThreshold(
          contextTokens: 0,
          contextLimitTokens: 200000,
          estimatedChars: 90000,
          fallbackTriggerChars: 120000,
        ),
        isFalse,
      );
    });
  });

  group('CompactionCircuitBreaker', () {
    test('连续 3 次失败熔断，第 3 次返回 justOpened', () {
      final breaker = CompactionCircuitBreaker();
      expect(breaker.recordFailure(), isFalse);
      expect(breaker.recordFailure(), isFalse);
      expect(breaker.isOpen, isFalse);
      expect(breaker.recordFailure(), isTrue);
      expect(breaker.isOpen, isTrue);
    });

    test('熔断后再记失败不重复 justOpened', () {
      final breaker = CompactionCircuitBreaker();
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.recordFailure(), isFalse);
      expect(breaker.isOpen, isTrue);
    });

    test('成功一次即重置计数', () {
      final breaker = CompactionCircuitBreaker();
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordSuccess();
      expect(breaker.isOpen, isFalse);
      expect(breaker.recordFailure(), isFalse);
      expect(breaker.recordFailure(), isFalse);
      expect(breaker.recordFailure(), isTrue);
    });
  });
}
