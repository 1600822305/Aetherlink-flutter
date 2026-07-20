import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_compaction_settings.dart';

void main() {
  test('编码/解码往返', () {
    const settings = AgentCompactionSettings(
      autoCompactEnabled: false,
      microCompactEnabled: false,
      triggerRatio: 0.85,
      keepChars: 20000,
      microCompactTriggerChars: 100000,
    );
    expect(
      decodeAgentCompactionSettings(encodeAgentCompactionSettings(settings)),
      settings,
    );
  });

  test('缺失/坏数据回退默认值（默认不改变现有行为）', () {
    const fallback = AgentCompactionSettings();
    expect(decodeAgentCompactionSettings(null), fallback);
    expect(decodeAgentCompactionSettings(''), fallback);
    expect(decodeAgentCompactionSettings('not json'), fallback);
    expect(decodeAgentCompactionSettings('[]'), fallback);
    expect(decodeAgentCompactionSettings('{"keepChars":"x"}'), fallback);
  });

  test('坏字段逐个回退，好字段保留', () {
    final decoded = decodeAgentCompactionSettings(
      '{"autoCompactEnabled":false,"triggerRatio":2.5,'
      '"keepChars":-1,"microCompactTriggerChars":60000}',
    );
    expect(decoded.autoCompactEnabled, isFalse);
    expect(decoded.triggerRatio, const AgentCompactionSettings().triggerRatio);
    expect(decoded.keepChars, const AgentCompactionSettings().keepChars);
    expect(decoded.microCompactTriggerChars, 60000);
  });

  test('字符回退触发阈值随比例缩放，默认比例下与既有默认 120000 一致', () {
    expect(const AgentCompactionSettings().compactionTriggerChars, 120000);
    expect(
      const AgentCompactionSettings(triggerRatio: 0.46).compactionTriggerChars,
      60000,
    );
  });
}
