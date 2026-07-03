import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/debate/application/debate_engine.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_chat_port.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_models.dart';

/// 录制引擎调用序列的假端口；[reply] 决定每次 speak 的返回，
/// [generateReply] 决定静默生成（裁决 JSON）的返回。
class _FakePort implements DebateChatPort {
  _FakePort({
    DebateSpeakResult Function(DebateSpeakRequest request)? reply,
    DebateSpeakResult Function(DebateSpeakRequest request)? generateReply,
  }) : _reply = reply ?? ((r) => DebateSpeakResult(text: '${r.role.name}的发言')),
       _generateReply =
           generateReply ?? ((_) => const DebateSpeakResult(failed: true));

  final DebateSpeakResult Function(DebateSpeakRequest request) _reply;
  final DebateSpeakResult Function(DebateSpeakRequest request) _generateReply;
  final List<DebateSpeakRequest> speaks = [];
  final List<DebateSpeakRequest> generates = [];
  final List<String> announcements = [];
  final List<String> readAlouds = [];
  void Function(String text)? interjectionListener;
  int cancelCount = 0;
  int _speakCount = 0;

  @override
  Future<DebateSpeakResult> speak(DebateSpeakRequest request) async {
    speaks.add(request);
    final result = _reply(request);
    if (!result.succeeded) return result;
    // 真实端口会附上落地消息 id，供 TTS 朗读定位。
    return DebateSpeakResult(text: result.text, messageId: 'msg-${_speakCount++}');
  }

  @override
  Future<DebateSpeakResult> generate(DebateSpeakRequest request) async {
    generates.add(request);
    return _generateReply(request);
  }

  @override
  Future<void> announce(String markdown, {Map<String, dynamic>? metadata}) async {
    announcements.add(markdown);
  }

  @override
  void setInterjectionListener(void Function(String text)? listener) {
    interjectionListener = listener;
  }

  @override
  void readAloud(String text, {required String messageId}) {
    readAlouds.add('$messageId:$text');
  }

  @override
  void cancelActiveStream() {
    cancelCount++;
  }
}

const _pro = DebateRole(
  id: 'r-pro',
  name: '正方辩手',
  modelKey: 'p/m1',
  stance: DebateStance.pro,
);
const _con = DebateRole(
  id: 'r-con',
  name: '反方辩手',
  modelKey: 'p/m2',
  stance: DebateStance.con,
);
const _moderator = DebateRole(
  id: 'r-mod',
  name: '主持人',
  modelKey: 'p/m3',
  stance: DebateStance.moderator,
);
const _summary = DebateRole(
  id: 'r-sum',
  name: '总结分析师',
  modelKey: 'p/m4',
  stance: DebateStance.summary,
);

DebateRunConfig _config({
  List<DebateRole> roles = const [_pro, _con, _moderator, _summary],
  int maxRounds = 3,
  bool moderatorEnabled = true,
  bool summaryEnabled = true,
  bool verdictEnabled = false,
  bool ttsEnabled = false,
}) => DebateRunConfig(
  topic: '测试辩题',
  roles: roles,
  maxRounds: maxRounds,
  turnGapSeconds: 0,
  moderatorEnabled: moderatorEnabled,
  summaryEnabled: summaryEnabled,
  verdictEnabled: verdictEnabled,
  ttsEnabled: ttsEnabled,
);

void main() {
  test('跑满 maxRounds：每轮按序发言，总结角色只在总结阶段出场', () async {
    final port = _FakePort();
    final engine = DebateEngine(port: port);

    final outcome = await engine.run(_config(maxRounds: 2));

    expect(outcome, DebateOutcome.completed);
    // 2 轮 × 3 发言角色 + 1 次总结。
    expect(port.speaks, hasLength(7));
    expect(
      [for (final s in port.speaks.take(6)) s.role.id],
      ['r-pro', 'r-con', 'r-mod', 'r-pro', 'r-con', 'r-mod'],
    );
    expect(port.speaks.take(6).map((s) => s.round), [1, 1, 1, 2, 2, 2]);
    final summarySpeak = port.speaks.last;
    expect(summarySpeak.role.id, 'r-sum');
    expect(summarySpeak.round, 0);
    // 开场 + 结束通告。
    expect(port.announcements.first, contains('AI辩论开始'));
    expect(port.announcements.last, contains('AI辩论结束'));
  });

  test('主持人第 2 轮起输出 [DEBATE_END] 时提前收束并总结', () async {
    final port = _FakePort(
      reply: (r) {
        if (r.role.stance == DebateStance.moderator && r.round >= 2) {
          return const DebateSpeakResult(
            text: '讨论充分，建议结束辩论。${DebateEngine.endDirective}',
          );
        }
        return DebateSpeakResult(text: '${r.role.name}的发言');
      },
    );
    final engine = DebateEngine(port: port);

    final outcome = await engine.run(_config(maxRounds: 5));

    expect(outcome, DebateOutcome.completed);
    // 第 2 轮主持人发言后立即总结：2×3 轮内发言 + 1 总结。
    expect(port.speaks, hasLength(7));
    expect(port.speaks.last.role.id, 'r-sum');
  });

  test('第 1 轮的 [DEBATE_END] 被忽略（至少 2 轮才允许收束）', () async {
    final port = _FakePort(
      reply: (r) => DebateSpeakResult(
        text: r.role.stance == DebateStance.moderator
            ? '结束吧 ${DebateEngine.endDirective}'
            : '发言',
      ),
    );
    final engine = DebateEngine(port: port);

    await engine.run(_config(maxRounds: 3));

    // 第 1 轮不收束，第 2 轮主持人触发：2 轮 × 3 + 总结。
    expect(port.speaks, hasLength(7));
  });

  test('moderatorEnabled=false 时主持人不发言', () async {
    final port = _FakePort();
    final engine = DebateEngine(port: port);

    await engine.run(_config(maxRounds: 1, moderatorEnabled: false));

    expect(
      port.speaks.map((s) => s.role.id),
      isNot(contains('r-mod')),
    );
  });

  test('发言失败：跳过并通告，不产出假回复', () async {
    final port = _FakePort(
      reply: (r) => r.role.id == 'r-con'
          ? DebateSpeakResult.noModel
          : DebateSpeakResult(text: '${r.role.name}的发言'),
    );
    final engine = DebateEngine(port: port);

    await engine.run(_config(maxRounds: 1));

    expect(engine.history.map((t) => t.role.id), isNot(contains('r-con')));
    expect(
      port.announcements.where((a) => a.contains('发言失败')),
      hasLength(1),
    );
  });

  test('summaryEnabled=false：结束时不调用总结角色', () async {
    final port = _FakePort();
    final engine = DebateEngine(port: port);

    await engine.run(_config(maxRounds: 1, summaryEnabled: false));

    expect(port.speaks.map((s) => s.role.id), isNot(contains('r-sum')));
    expect(port.announcements.last, contains('AI辩论结束'));
  });

  test('总结角色无模型时降级到本地模板总结', () async {
    const roles = [
      _pro,
      _con,
      DebateRole(id: 'r-sum', name: '总结分析师', stance: DebateStance.summary),
    ];
    final port = _FakePort(
      reply: (r) => r.role.hasModel
          ? DebateSpeakResult(text: '${r.role.name}的发言')
          : DebateSpeakResult.noModel,
    );
    final engine = DebateEngine(port: port);

    await engine.run(_config(roles: roles, maxRounds: 1));

    // 总结落到任一配模型的角色（正方），而不是无模型的总结角色。
    expect(port.speaks.last.role.id, 'r-pro');
  });

  test('stop()：中断轮间等待并取消流式请求', () async {
    final port = _FakePort();
    final engine = DebateEngine(port: port);
    const config = DebateRunConfig(
      topic: '测试辩题',
      roles: [_pro, _con],
      maxRounds: 3,
      turnGapSeconds: 30,
    );

    final future = engine.run(config);
    // 等第一条发言完成后停止（此时引擎在 30s 轮间等待中）。
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    engine.stop();
    final outcome = await future;

    expect(outcome, DebateOutcome.stopped);
    expect(port.cancelCount, 1);
    // 未进入总结。
    expect(port.speaks.map((s) => s.round), isNot(contains(0)));
  });

  test('buildContext：包含辩题/轮次/历史窗口与字数约束', () async {
    final engine = DebateEngine(port: _FakePort());
    final config = _config();

    final context = engine.buildContext(config, _pro, 1);

    expect(context, contains('辩论主题：测试辩题'));
    expect(context, contains('第1轮'));
    expect(context, contains('不超过200字'));
    expect(context, isNot(contains('之前的发言')));

    final moderatorContext = engine.buildContext(config, _moderator, 2);
    expect(moderatorContext, contains(DebateEngine.endDirective));
  });

  test('用户插话：进入历史并出现在后续上下文，带回应提示', () async {
    final engine = DebateEngine(port: _FakePort());
    final config = _config();

    engine.injectUserMessage('  请双方结合具体案例论证  ');

    expect(engine.history, hasLength(1));
    expect(engine.history.single.role.id, DebateEngine.audienceRole.id);
    final context = engine.buildContext(config, _pro, 2);
    expect(context, contains('场外观众（用户插话）：请双方结合具体案例论证'));
    expect(context, contains('适当回应'));
  });

  test('事实核查角色：toolsEnabled 随发言请求传递', () async {
    const factChecker = DebateRole(
      id: 'r-fact',
      name: '事实核查员',
      modelKey: 'p/m5',
      stance: DebateStance.neutral,
      toolsEnabled: true,
    );
    final port = _FakePort();
    final engine = DebateEngine(port: port);

    await engine.run(_config(roles: const [_pro, _con, factChecker], maxRounds: 1));

    for (final s in port.speaks) {
      expect(s.toolsEnabled, s.role.id == 'r-fact');
    }
  });

  test('ttsEnabled：每条成功发言都被朗读；关闭时不朗读', () async {
    final port = _FakePort();
    final engine = DebateEngine(port: port);

    await engine.run(_config(maxRounds: 1, ttsEnabled: true));

    // 3 发言角色 + 1 总结。
    expect(port.readAlouds, hasLength(4));

    final silentPort = _FakePort();
    await DebateEngine(port: silentPort).run(_config(maxRounds: 1));
    expect(silentPort.readAlouds, isEmpty);
  });

  test('空插话被忽略', () {
    final engine = DebateEngine(port: _FakePort());
    engine.injectUserMessage('   ');
    expect(engine.history, isEmpty);
  });

  test('裁决模式：静默生成 JSON 并以卡片通告呈现', () async {
    const verdictJson = '''
```json
{
  "winner": "正方辩手",
  "rationale": "论证更严密",
  "scores": [
    {"name": "正方辩手", "logic": 9, "evidence": 8, "rebuttal": 8, "expression": 9},
    {"name": "反方辩手", "logic": 7, "evidence": 7, "rebuttal": 8, "expression": 8}
  ],
  "clashPoints": ["效率与公平的取舍"]
}
```''';
    final port = _FakePort(
      generateReply: (_) => const DebateSpeakResult(text: verdictJson),
    );
    final engine = DebateEngine(port: port);

    await engine.run(_config(maxRounds: 1, verdictEnabled: true));

    expect(port.generates, hasLength(1));
    expect(port.generates.single.role.id, 'r-sum');
    final card = port.announcements.firstWhere((a) => a.contains('辩论裁决'));
    expect(card, contains('胜方：正方辩手'));
    expect(card, contains('| 正方辩手 | 9 | 8 | 8 | 9 | **34** |'));
    expect(card, contains('效率与公平的取舍'));
  });

  test('裁决 JSON 无效时降级提示，不阻断收尾', () async {
    final port = _FakePort(
      generateReply: (_) => const DebateSpeakResult(text: '我无法裁决'),
    );
    final engine = DebateEngine(port: port);

    final outcome = await engine.run(_config(maxRounds: 1, verdictEnabled: true));

    expect(outcome, DebateOutcome.completed);
    expect(
      port.announcements.where((a) => a.contains('裁决生成失败')),
      hasLength(1),
    );
    expect(port.announcements.last, contains('AI辩论结束'));
  });

  group('共识模式', () {
    DebateRunConfig consensusConfig({
      List<DebateRole> roles = const [_pro, _con, _moderator, _summary],
    }) => DebateRunConfig(
      topic: '选哪个数据库？',
      roles: roles,
      turnGapSeconds: 0,
      mode: DebateMode.consensus,
    );

    test('独立作答 → 互评 → 主持人汇总投票', () async {
      final port = _FakePort();
      final engine = DebateEngine(port: port);

      final outcome = await engine.run(consensusConfig());

      expect(outcome, DebateOutcome.completed);
      // 2 陈述人 × (作答 + 互评) + 1 汇总；主持/总结角色不作答。
      expect(
        [for (final s in port.speaks) '${s.role.id}@${s.round}'],
        ['r-pro@1', 'r-con@1', 'r-pro@2', 'r-con@2', 'r-mod@0'],
      );
      // 作答阶段互不可见：作答 prompt 不含他人回答。
      expect(port.speaks[1].prompt, isNot(contains('【正方辩手】')));
      expect(port.speaks.first.prompt, contains('选哪个数据库？'));
      // 互评阶段能看到全部回答并被要求投票。
      expect(port.speaks[2].prompt, contains('【正方辩手】'));
      expect(port.speaks[2].prompt, contains('【反方辩手】'));
      expect(port.speaks[2].prompt, contains('我投票支持'));
      // 汇总 prompt 含互评与投票要求。
      expect(port.speaks.last.prompt, contains('投票统计'));
      expect(port.announcements.first, contains('共识决策开始'));
      expect(port.announcements.last, contains('共识决策结束'));
    });

    test('陈述人不足 2 个时拒绝开始', () async {
      final port = _FakePort();
      final engine = DebateEngine(port: port);

      await engine.run(consensusConfig(roles: const [_pro, _moderator]));

      expect(port.speaks, isEmpty);
      expect(port.announcements.single, contains('无法开始共识决策'));
    });

    test('作答失败的陈述人不参与互评；有效回答不足 2 份时终止', () async {
      final port = _FakePort(
        reply: (r) => r.role.id == 'r-con'
            ? DebateSpeakResult.noModel
            : DebateSpeakResult(text: '${r.role.name}的发言'),
      );
      final engine = DebateEngine(port: port);

      await engine.run(consensusConfig());

      expect(
        port.announcements.where((a) => a.contains('有效回答不足')),
        hasLength(1),
      );
      // 只有作答阶段的 2 次调用，无互评/汇总。
      expect(port.speaks.map((s) => s.round), [1, 1]);
    });

    test('无主持人时由总结角色汇总', () async {
      final port = _FakePort();
      final engine = DebateEngine(port: port);

      await engine.run(consensusConfig(roles: const [_pro, _con, _summary]));

      expect(port.speaks.last.role.id, 'r-sum');
      expect(port.speaks.last.round, 0);
    });
  });
}
