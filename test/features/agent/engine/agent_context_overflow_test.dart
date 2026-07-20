import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_context_overflow.dart';

void main() {
  test('识别各供应商上下文超限报错', () {
    expect(
      isContextOverflowError(
          Exception('prompt is too long: 137500 tokens > 135000 maximum')),
      isTrue,
    );
    expect(
      isContextOverflowError(Exception('Prompt is too long')),
      isTrue,
    );
    expect(
      isContextOverflowError(Exception(
          "This model's maximum context length is 128000 tokens "
          '(context_length_exceeded)')),
      isTrue,
    );
    expect(
      isContextOverflowError(
          Exception('input token count exceeds the maximum allowed')),
      isTrue,
    );
    expect(
      isContextOverflowError(Exception('Request too large for model')),
      isTrue,
    );
  });

  test('非超限错误不误判', () {
    expect(isContextOverflowError(Exception('rate limit exceeded')), isFalse);
    expect(isContextOverflowError(Exception('invalid api key')), isFalse);
    expect(isContextOverflowError(StateError('压缩摘要为空')), isFalse);
    expect(isContextOverflowError(Exception('network timeout')), isFalse);
  });
}
