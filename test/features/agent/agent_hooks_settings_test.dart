import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_hooks_settings.dart';

void main() {
  test('disableAllHooks 编码/解码往返', () {
    expect(decodeAgentDisableAllHooks(encodeAgentDisableAllHooks(true)), isTrue);
    expect(
        decodeAgentDisableAllHooks(encodeAgentDisableAllHooks(false)), isFalse);
  });

  test('缺失/坏数据回退 false（默认不改变现有行为）', () {
    expect(decodeAgentDisableAllHooks(null), isFalse);
    expect(decodeAgentDisableAllHooks(''), isFalse);
    expect(decodeAgentDisableAllHooks('TRUE'), isFalse);
    expect(decodeAgentDisableAllHooks('1'), isFalse);
    expect(decodeAgentDisableAllHooks('not json'), isFalse);
  });
}
