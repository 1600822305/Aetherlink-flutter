import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_tables.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

part 'agent_dao.g.dart';

/// 智能体三表（档案/话题/事件流）的数据访问对象（设计初稿 §4.3）。
@DriftAccessor(tables: [AgentProfileRows, AgentTaskRows, AgentEventRows])
class AgentDao extends DatabaseAccessor<AppDatabase> with _$AgentDaoMixin {
  AgentDao(super.db);

  // ---- 档案 ----

  Future<List<AgentProfile>> getAllProfiles() async {
    final rows = await select(agentProfileRows).get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> upsertProfile(AgentProfile profile) {
    return into(agentProfileRows).insertOnConflictUpdate(
      AgentProfileRowsCompanion.insert(id: profile.id, data: profile),
    );
  }

  Future<void> deleteProfile(String id) =>
      (delete(agentProfileRows)..where((t) => t.id.equals(id))).go();

  // ---- 话题 ----

  /// 全部话题，按最近活动倒序（侧栏排序）。
  Future<List<AgentTask>> getAllTasks() async {
    final rows =
        await (select(agentTaskRows)..orderBy([
              (t) => OrderingTerm(
                expression: t.updatedAtNum,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    return rows.map((row) => row.data).toList();
  }

  /// 单个话题的一次性读取（行不存在返回 null）。
  Future<AgentTask?> getTask(String id) async {
    final row = await (select(
      agentTaskRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  Future<void> upsertTask(AgentTask task) {
    return into(agentTaskRows).insertOnConflictUpdate(
      AgentTaskRowsCompanion.insert(
        id: task.id,
        profileId: task.profileId,
        updatedAtNum: task.updatedAt.millisecondsSinceEpoch,
        data: task,
      ),
    );
  }

  /// 删除话题及其全部事件。
  Future<void> deleteTask(String id) => transaction(() async {
    await (delete(agentEventRows)..where((e) => e.taskId.equals(id))).go();
    await (delete(agentTaskRows)..where((t) => t.id.equals(id))).go();
  });

  /// 删除某智能体下全部话题及事件（删智能体联动）。
  Future<void> deleteTasksByProfile(String profileId) => transaction(() async {
    final ids =
        await (selectOnly(agentTaskRows)
              ..addColumns([agentTaskRows.id])
              ..where(agentTaskRows.profileId.equals(profileId)))
            .map((row) => row.read(agentTaskRows.id)!)
            .get();
    if (ids.isNotEmpty) {
      await (delete(agentEventRows)..where((e) => e.taskId.isIn(ids))).go();
    }
    await (delete(
      agentTaskRows,
    )..where((t) => t.profileId.equals(profileId))).go();
  });

  // ---- 事件流 ----

  /// 某话题事件流的实时查询（按 seq 升序，UI watch 即得增量更新）。
  /// drift 的 watch 每次变更都全表读回；长任务（数千事件）流式期间
  /// 全量 payload 每次跨 isolate 拷贝的开销随事件数线性增长。这里
  /// watch 一个不含 payload 的轻量投影，用 [rev]（每次写入单调递增，
  /// 原位更新时 seq/createdAt 不变但 rev 必变）判定变更，只对新增/
  /// 变更行二次取 payload 并解码，未变行复用缓存的同一事件实例
  /// （时间线折叠器靠 identical 校验前缀，实例复用是其契约）。
  Stream<List<AgentEvent>> watchEvents(String taskId) {
    final projection = selectOnly(agentEventRows)
      ..addColumns([agentEventRows.id, agentEventRows.rev])
      ..where(agentEventRows.taskId.equals(taskId))
      ..orderBy([OrderingTerm(expression: agentEventRows.seq)]);
    // id → (rev, 已解码事件)。
    var cache = <String, (int, AgentEvent)>{};
    return projection.watch().asyncMap((rows) async {
      final metas = [
        for (final row in rows)
          (row.read(agentEventRows.id)!, row.read(agentEventRows.rev)!),
      ];
      final stale = [
        for (final (id, rev) in metas)
          if (cache[id]?.$1 != rev) id,
      ];
      final fetched = <String, (int, AgentEvent)>{};
      // 分块避免超出 SQLite 绑定变量上限。
      for (var i = 0; i < stale.length; i += 400) {
        final chunk = stale.sublist(
          i,
          i + 400 > stale.length ? stale.length : i + 400,
        );
        final detailRows = await (select(
          agentEventRows,
        )..where((e) => e.id.isIn(chunk))).get();
        for (final row in detailRows) {
          fetched[row.id] = (
            row.rev,
            decodeAgentEvent(
              id: row.id,
              seq: row.seq,
              at: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
              kind: row.kind,
              payloadJson: row.payloadJson,
            ),
          );
        }
      }
      final next = <String, (int, AgentEvent)>{};
      final events = <AgentEvent>[];
      for (final (id, rev) in metas) {
        // 取详情窗口内行又被改/删时以详情为准；已删且无缓存的行跳过，
        // 删除本身会触发下一次发射兜底修正。
        final entry =
            (cache[id]?.$1 == rev ? cache[id] : fetched[id]) ?? cache[id];
        if (entry == null) continue;
        next[id] = entry;
        events.add(entry.$2);
      }
      cache = next;
      return events;
    });
  }

  /// 某话题事件流的一次性读取（按 seq 升序，引擎组上下文用）。
  Future<List<AgentEvent>> getEvents(String taskId) async {
    final rows =
        await (select(agentEventRows)
              ..where((e) => e.taskId.equals(taskId))
              ..orderBy([(e) => OrderingTerm(expression: e.seq)]))
            .get();
    return [
      for (final row in rows)
        decodeAgentEvent(
          id: row.id,
          seq: row.seq,
          at: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
          kind: row.kind,
          payloadJson: row.payloadJson,
        ),
    ];
  }

  /// 某话题指定 kind 事件的一次性读取（按 seq 升序）：安全点消费排队
  /// 消息等定向场景用，避免全表读取+解码。
  Future<List<AgentEvent>> getEventsOfKind(String taskId, String kind) async {
    final rows =
        await (select(agentEventRows)
              ..where((e) => e.taskId.equals(taskId) & e.kind.equals(kind))
              ..orderBy([(e) => OrderingTerm(expression: e.seq)]))
            .get();
    return [
      for (final row in rows)
        decodeAgentEvent(
          id: row.id,
          seq: row.seq,
          at: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
          kind: row.kind,
          payloadJson: row.payloadJson,
        ),
    ];
  }

  /// 话题内当前最大 seq（无事件时 0），新事件从这里续增。
  Future<int> maxSeq(String taskId) async {
    final expr = agentEventRows.seq.max();
    final row =
        await (selectOnly(agentEventRows)
              ..addColumns([expr])
              ..where(agentEventRows.taskId.equals(taskId)))
            .getSingle();
    return row.read(expr) ?? 0;
  }

  /// 按 id 删除单个事件（占位检查点静默降级用）。
  Future<void> deleteEventById(String taskId, String id) => (delete(
    agentEventRows,
  )..where((e) => e.taskId.equals(taskId) & e.id.equals(id))).go();

  /// 删除话题内 seq 大于 [seq] 的全部事件（回滚对话到检查点用）。
  Future<void> deleteEventsAfterSeq(String taskId, int seq) => (delete(
    agentEventRows,
  )..where((e) => e.taskId.equals(taskId) & e.seq.isBiggerThanValue(seq))).go();

  /// 进程内单调 rev 发生器：以微秒时钟为底、同微秒内自增，重启后
  /// 时钟前进保证仍大于历史值（存量迁移行为 0）。
  static int _lastRev = 0;
  static int _nextRev() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastRev = now > _lastRev ? now : _lastRev + 1;
    return _lastRev;
  }

  /// 追加（或按 id 覆盖，用于流式文本/工具状态原位更新）一批事件。
  /// 每行盖上新 rev，watchEvents 的投影据此感知原位更新。
  Future<void> upsertEvents(String taskId, List<AgentEvent> events) {
    return batch((b) {
      for (final event in events) {
        b.insert(
          agentEventRows,
          AgentEventRowsCompanion.insert(
            id: event.id,
            taskId: taskId,
            seq: event.seq,
            kind: agentEventKind(event),
            payloadJson: encodeAgentEventPayload(event),
            createdAt: event.at.millisecondsSinceEpoch,
            rev: Value(_nextRev()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
