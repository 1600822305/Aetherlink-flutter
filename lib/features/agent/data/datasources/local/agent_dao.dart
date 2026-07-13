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
  Stream<List<AgentEvent>> watchEvents(String taskId) {
    final query = select(agentEventRows)
      ..where((e) => e.taskId.equals(taskId))
      ..orderBy([(e) => OrderingTerm(expression: e.seq)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          decodeAgentEvent(
            id: row.id,
            seq: row.seq,
            at: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
            kind: row.kind,
            payloadJson: row.payloadJson,
          ),
      ],
    );
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

  /// 删除话题内 seq 大于 [seq] 的全部事件（回滚对话到检查点用）。
  Future<void> deleteEventsAfterSeq(String taskId, int seq) => (delete(
    agentEventRows,
  )..where((e) => e.taskId.equals(taskId) & e.seq.isBiggerThanValue(seq))).go();

  /// 追加（或按 id 覆盖，用于流式文本/工具状态原位更新）一批事件。
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
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
