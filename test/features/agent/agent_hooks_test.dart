import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

void main() {
  group('decodeAgentHooksConfig', () {
    test('完整配置解析：三个事件 + 默认值', () {
      final config = decodeAgentHooksConfig('''
{
  "preToolUse": [
    {"matcher": "terminal_execute", "pattern": "git push *",
     "command": "sh check.sh", "timeout": 10}
  ],
  "postToolUse": [{"matcher": "write", "command": "dart format ."}],
  "stop": [{"command": "flutter analyze"}]
}
''')!;
      expect(config.hooks.length, 3);
      final pre = config.ofEvent(AgentHookEvent.preToolUse).single;
      expect(pre.matcher, 'terminal_execute');
      expect(pre.pattern, 'git push *');
      expect(pre.timeoutSeconds, 10);
      final post = config.ofEvent(AgentHookEvent.postToolUse).single;
      expect(post.pattern, '*');
      expect(post.timeoutSeconds, kAgentHookDefaultTimeoutSeconds);
      expect(config.ofEvent(AgentHookEvent.stop).single.matcher, '*');
    });

    test('坏 JSON / 非对象 / 空串返回 null', () {
      expect(decodeAgentHooksConfig('not json'), isNull);
      expect(decodeAgentHooksConfig('[1,2]'), isNull);
      expect(decodeAgentHooksConfig(''), isNull);
      expect(decodeAgentHooksConfig(null), isNull);
    });

    test('缺 command / 类型不对的条目丢弃，未知事件键忽略', () {
      final config = decodeAgentHooksConfig('''
{
  "preToolUse": [{"matcher": "x"}, "junk", {"command": "ok"}],
  "unknownEvent": [{"command": "nope"}]
}
''')!;
      expect(config.hooks.single.command, 'ok');
    });

    test('postToolUseFailure 事件解析与匹配', () {
      final config = decodeAgentHooksConfig('''
{"postToolUseFailure": [{"matcher": "terminal_*", "command": "diagnose.sh"}]}
''')!;
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.postToolUseFailure,
        'terminal_execute',
        ['git push origin main'],
      );
      expect(hooks.single.command, 'diagnose.sh');
      expect(
        hooksForToolCall(
          config,
          AgentHookEvent.postToolUse,
          'terminal_execute',
          ['ls'],
        ),
        isEmpty,
      );
    });

    test('非法 timeout 回退默认', () {
      final config = decodeAgentHooksConfig(
        '{"stop":[{"command":"c","timeout":-5}]}',
      )!;
      expect(config.hooks.single.timeoutSeconds, kAgentHookDefaultTimeoutSeconds);
    });
  });

  group('hooksForToolCall', () {
    final config = decodeAgentHooksConfig('''
{
  "preToolUse": [
    {"matcher": "terminal_execute", "pattern": "git push *", "command": "a"},
    {"matcher": "terminal_*", "command": "b"},
    {"matcher": "write", "command": "c"}
  ]
}
''')!;

    test('matcher + pattern 双重命中', () {
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.preToolUse,
        'terminal_execute',
        ['git push origin main'],
      );
      expect(hooks.map((h) => h.command), ['a', 'b']);
    });

    test('pattern 不命中时只剩通配 hook', () {
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.preToolUse,
        'terminal_execute',
        ['ls -la'],
      );
      expect(hooks.map((h) => h.command), ['b']);
    });

    test('patterns 为空按 * 处理（非终端工具）', () {
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.preToolUse,
        'write',
        const [],
      );
      expect(hooks.single.command, 'c');
    });

    test('事件不匹配返回空', () {
      expect(
        hooksForToolCall(
          config,
          AgentHookEvent.postToolUse,
          'terminal_execute',
          ['ls'],
        ),
        isEmpty,
      );
    });
  });

  group('interpretAgentHookExit', () {
    test('exit 0 无输出 → proceed', () {
      final r = interpretAgentHookExit(0, '', '');
      expect(r.outcome, AgentHookOutcome.proceed);
    });

    test('exit 2 → block，stderr 优先作为原因', () {
      final r = interpretAgentHookExit(2, 'out', 'lint failed');
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, 'lint failed');
      expect(interpretAgentHookExit(2, 'only stdout', '').message,
          'only stdout');
    });

    test('exit 0 + stdout JSON decision → block', () {
      final r = interpretAgentHookExit(
        0,
        '{"decision":"deny","reason":"危险命令"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '危险命令');
      expect(
        interpretAgentHookExit(0, '{"decision":"block"}', '').outcome,
        AgentHookOutcome.block,
      );
    });

    test('exit 0 + 非 decision JSON / 普通输出 → proceed', () {
      expect(interpretAgentHookExit(0, '{"foo":1}', '').outcome,
          AgentHookOutcome.proceed);
      expect(interpretAgentHookExit(0, 'all good', '').outcome,
          AgentHookOutcome.proceed);
    });

    test('其他 exit code → failed（不阻断）', () {
      final r = interpretAgentHookExit(1, '', 'boom');
      expect(r.outcome, AgentHookOutcome.failed);
      expect(r.message, 'boom');
      expect(interpretAgentHookExit(127, '', '').message, 'exit 127');
    });
  });
}
