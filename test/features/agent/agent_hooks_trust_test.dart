import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_hooks_trust.dart';

void main() {
  test('信任表编码/解码往返', () {
    final trusted = {'ws-1': '{"stop":[{"command":"c"}]}', 'ws-2': '{}'};
    expect(decodeAgentTrustedHooks(encodeAgentTrustedHooks(trusted)), trusted);
  });

  test('坏数据返回 null，非字符串条目丢弃', () {
    expect(decodeAgentTrustedHooks('not json'), isNull);
    expect(decodeAgentTrustedHooks('[1]'), isNull);
    expect(decodeAgentTrustedHooks(''), isNull);
    expect(decodeAgentTrustedHooks(null), isNull);
    expect(decodeAgentTrustedHooks('{"a":"x","b":1}'), {'a': 'x'});
  });
}
