import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_dao.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// watchEvents 轻量投影 + 增量取详情后的语义等价验证：任意写入序列
/// （追加、原位更新、同 id 换 kind、删除、截断）下，watch 最终发射的
/// 列表都要与全量读取（getEvents）一致，且未变行复用同一实例
/// （时间线折叠器前缀缓存的 identical 契约）。
void main() {
  late AppDatabase db;
  late AgentDao dao;
  const taskId = 't1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = AgentDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  String sig(AgentEvent e) =>
      '${e.id}|${e.seq}|${e.at.millisecondsSinceEpoch}|'
      '${agentEventKind(e)}|${encodeAgentEventPayload(e)}';

  List<String> sigs(List<AgentEvent> events) => events.map(sig).toList();

  DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  /// 等待 watch 缓冲区里出现与 getEvents 一致的发射（最后一条为准）。
  Future<void> expectConverged(List<List<AgentEvent>> emissions) async {
    final expected = sigs(await dao.getEvents(taskId));
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      if (emissions.isNotEmpty && sigs(emissions.last).join() ==
          expected.join()) {
        expect(sigs(emissions.last), expected);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('watchEvents 未收敛到 getEvents 快照：'
        '期望 $expected，最后发射 ${emissions.isEmpty ? null : sigs(emissions.last)}');
  }

  test('任意写入序列下 watch 与全量读取语义等价', () async {
    final emissions = <List<AgentEvent>>[];
    final sub = dao.watchEvents(taskId).listen(emissions.add);
    addTearDown(sub.cancel);

    // 追加：用户消息 + 流式文本 + 运行中工具。
    await dao.upsertEvents(taskId, [
      UserMessageEvent(id: 'um-1', seq: 1, at: at(1000), text: 'hi'),
      AssistantTextEvent(
          id: 'at-1', seq: 2, at: at(2000), text: 'he', streaming: true),
      ToolCallEvent(
        id: 'tc-1',
        seq: 3,
        at: at(3000),
        toolName: 'read',
        argSummary: 'a.txt',
        state: AgentToolCallState.running,
      ),
    ]);
    await expectConverged(emissions);

    // 原位更新：id/seq/at 全不变，仅 payload 变（旧判据不可见的场景）。
    await dao.upsertEvents(taskId, [
      AssistantTextEvent(
          id: 'at-1', seq: 2, at: at(2000), text: 'hello', streaming: false),
      ToolCallEvent(
        id: 'tc-1',
        seq: 3,
        at: at(3000),
        toolName: 'read',
        argSummary: 'a.txt',
        state: AgentToolCallState.success,
        resultSummary: 'ok',
      ),
    ]);
    await expectConverged(emissions);
    expect(
      (emissions.last[1] as AssistantTextEvent).text,
      'hello',
      reason: '同 id/seq/createdAt 的原位更新必须被 watch 感知',
    );

    // 同 id 换 kind：占位检查点降级为状态行（replaceCheckpointWithStatus）。
    await dao.upsertEvents(taskId, [
      CheckpointEvent(id: 'ck-1', seq: 4, at: at(4000), commits: {}),
    ]);
    await expectConverged(emissions);
    await dao.upsertEvents(taskId, [
      StatusChangeEvent(id: 'ck-1', seq: 4, at: at(4000), description: '降级'),
    ]);
    await expectConverged(emissions);
    expect(emissions.last[3], isA<StatusChangeEvent>());

    // 删除单条 + 截断尾部。
    await dao.upsertEvents(taskId, [
      StatusChangeEvent(id: 'sc-9', seq: 5, at: at(5000), description: 'x'),
    ]);
    await expectConverged(emissions);
    await dao.deleteEventById(taskId, 'sc-9');
    await expectConverged(emissions);
    await dao.deleteEventsAfterSeq(taskId, 2);
    await expectConverged(emissions);
    expect(sigs(emissions.last).length, 2);
  });

  test('未变更行跨发射复用同一实例（折叠器 identical 契约）', () async {
    final emissions = <List<AgentEvent>>[];
    final sub = dao.watchEvents(taskId).listen(emissions.add);
    addTearDown(sub.cancel);

    await dao.upsertEvents(taskId, [
      UserMessageEvent(id: 'um-1', seq: 1, at: at(1000), text: 'hi'),
    ]);
    await expectConverged(emissions);
    final first = emissions.last[0];

    await dao.upsertEvents(taskId, [
      AssistantTextEvent(
          id: 'at-1', seq: 2, at: at(2000), text: 'a', streaming: true),
    ]);
    await expectConverged(emissions);
    expect(identical(emissions.last[0], first), isTrue);
    final streamingInstance = emissions.last[1];

    // 原位更新只替换变更行的实例，未变行仍是原实例。
    await dao.upsertEvents(taskId, [
      AssistantTextEvent(
          id: 'at-1', seq: 2, at: at(2000), text: 'ab', streaming: true),
    ]);
    await expectConverged(emissions);
    expect(identical(emissions.last[0], first), isTrue);
    expect(identical(emissions.last[1], streamingInstance), isFalse);
    expect((emissions.last[1] as AssistantTextEvent).text, 'ab');
  });

  test('不同话题的事件互不可见', () async {
    await dao.upsertEvents(taskId, [
      UserMessageEvent(id: 'um-1', seq: 1, at: at(1000), text: 'hi'),
    ]);
    await dao.upsertEvents('t2', [
      UserMessageEvent(id: 'um-2', seq: 1, at: at(1000), text: 'other'),
    ]);
    final events = await dao.watchEvents(taskId).first;
    expect(sigs(events), sigs(await dao.getEvents(taskId)));
    expect(events.single.id, 'um-1');
  });
}
