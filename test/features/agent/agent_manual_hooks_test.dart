import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_manual_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

void main() {
  test('手动 hooks 编码/解码往返', () {
    final hooks = [
      const AgentManualHook(
        name: '推送前检查',
        hook: AgentHook(
          event: AgentHookEvent.preToolUse,
          matcher: 'terminal_execute',
          pattern: 'git push *',
          command: 'sh check-push.sh',
          timeoutSeconds: 60,
        ),
      ),
      const AgentManualHook(
        name: '收尾分析',
        enabled: false,
        hook: AgentHook(
          event: AgentHookEvent.stop,
          command: 'flutter analyze --no-pub',
        ),
      ),
      const AgentManualHook(
        name: '启动准备',
        hook: AgentHook(
          event: AgentHookEvent.taskStart,
          command: 'echo start',
        ),
      ),
    ];
    final decoded = decodeAgentManualHooks(encodeAgentManualHooks(hooks))!;
    expect(decoded.length, 3);
    expect(decoded[0].name, '推送前检查');
    expect(decoded[0].enabled, isTrue);
    expect(decoded[0].hook.event, AgentHookEvent.preToolUse);
    expect(decoded[0].hook.matcher, 'terminal_execute');
    expect(decoded[0].hook.pattern, 'git push *');
    expect(decoded[0].hook.command, 'sh check-push.sh');
    expect(decoded[0].hook.timeoutSeconds, 60);
    expect(decoded[1].enabled, isFalse);
    expect(decoded[1].hook.event, AgentHookEvent.stop);
    expect(decoded[2].hook.event, AgentHookEvent.taskStart);
  });

  test('turnStart/turnEnd 生命周期事件可编码解码', () {
    final decoded = decodeAgentManualHooks(encodeAgentManualHooks(const [
      AgentManualHook(
        name: '轮次开始',
        hook: AgentHook(event: AgentHookEvent.turnStart, command: 'echo s'),
      ),
      AgentManualHook(
        name: '轮次结束',
        hook: AgentHook(event: AgentHookEvent.turnEnd, command: 'echo e'),
      ),
    ]))!;
    expect(decoded[0].hook.event, AgentHookEvent.turnStart);
    expect(decoded[1].hook.event, AgentHookEvent.turnEnd);
  });

  test('坏数据返回 null，坏条目丢弃', () {
    expect(decodeAgentManualHooks('not json'), isNull);
    expect(decodeAgentManualHooks('{"a":1}'), isNull);
    expect(decodeAgentManualHooks(''), isNull);
    expect(decodeAgentManualHooks(null), isNull);
    final decoded = decodeAgentManualHooks(
      '[{"event":"preToolUse"},'
      '{"event":"unknown","command":"c"},'
      '{"event":"postToolUse","command":"dart format ."},'
      '1]',
    )!;
    expect(decoded.length, 1);
    expect(decoded[0].hook.event, AgentHookEvent.postToolUse);
    expect(decoded[0].name, 'dart format .');
    expect(decoded[0].hook.matcher, '*');
    expect(decoded[0].hook.timeoutSeconds, kAgentHookDefaultTimeoutSeconds);
  });
}
