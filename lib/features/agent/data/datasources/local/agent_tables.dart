import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';

/// 智能体档案表（设计初稿 §4.3，独立于 chat 表）。
/// 整体存 JSON blob（对齐 [TopicRows] 的存法），id 为主键。
@DataClassName('AgentProfileRow')
class AgentProfileRows extends Table {
  TextColumn get id => text()();
  TextColumn get data => text().map(const AgentProfileConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 智能体话题（任务）表。[profileId]/[updatedAtNum] 为派生索引列
/// （侧栏按最近活动排序、删智能体联动删话题）。
@DataClassName('AgentTaskRow')
@TableIndex(name: 'idx_agent_tasks_profile_id', columns: {#profileId})
class AgentTaskRows extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  IntColumn get updatedAtNum => integer()();
  TextColumn get data => text().map(const AgentTaskConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 事件流表（append-only，(taskId, seq) 复合索引支撑按序重放）。
/// kind + payload_json 拆列；大输出未来落文件、行内只存引用（§4.3）。
@DataClassName('AgentEventRow')
@TableIndex(name: 'idx_agent_events_task_seq', columns: {#taskId, #seq})
class AgentEventRows extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  IntColumn get seq => integer()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
