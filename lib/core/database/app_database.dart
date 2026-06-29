import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/database/app_settings_dao.dart';
import 'package:aetherlink_flutter/core/database/app_settings_table.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/assistant_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/assistants_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/group_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/groups_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_block_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_blocks_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/messages_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/topic_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/topics_table.dart';
// Domain entities persisted as JSON blobs. The generated `app_database.g.dart`
// part references these types (column converters / row data classes), so they
// must be in this library's scope — see the carve-out in
// `test/architecture/import_boundaries_test.dart`.
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memories_table.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memory_converters.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memory_dao.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memory_history_table.dart';
// Persisted as a JSON blob in [MemoryRows]; the generated part references the
// converter's row data type.
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/model_provider_converters.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/provider_dao.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/providers_table.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'app_database.g.dart';

/// The single application Drift database (one SQLite file for the whole app).
///
/// This is the persistence composition root: a single SQLite database has to
/// aggregate every feature's tables and DAOs, which live in their owning
/// feature's `data` layer. The generated part references those table/DAO
/// definitions and the (pure-Dart) domain entities they persist as JSON blobs,
/// so this `core` library imports both — the database equivalent of how `app/`
/// wires up features. See the documented carve-out in
/// `test/architecture/import_boundaries_test.dart`.
@DriftDatabase(
  tables: [
    TopicRows,
    MessageRows,
    MessageBlockRows,
    AssistantRows,
    ProviderRows,
    GroupRows,
    AppSettingRows,
    MemoryRows,
    MemoryHistoryRows,
  ],
  daos: [
    TopicDao,
    MessageDao,
    MessageBlockDao,
    AssistantDao,
    ProviderDao,
    GroupDao,
    AppSettingDao,
    MemoryDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database file (`aetherlink.sqlite` under the app
  /// documents directory).
  AppDatabase.open() : super(_openConnection());

  @override
  int get schemaVersion => 8;

  // v1 → v2 adds the model-provider store ([ProviderRows]); v2 → v3 adds the
  // sidebar group store ([GroupRows]); v3 → v4 adds the key/value preferences
  // store ([AppSettingRows], the port of the web `dexieStorage` settings). The
  // one-time IndexedDB (`aetherlink-db-new` v9) → SQLite data import remains a
  // separate cross-cutting task (see docs/ROADMAP.md). v4 → v5 adds the
  // long-term memory store ([MemoryRows]); v5 → v6 adds the memory audit log
  // ([MemoryHistoryRows]). v6 → v7 promotes the message-tree columns
  // (parentId / role / siblingsGroupId / createdAt) from the JSON blob to real
  // columns on [MessageRows] and adds the parentId lookup index — PR-1 of the
  // message-tree refactor (see docs/design/message-tree-model-design.md). It
  // only adds columns + index; backfill, the single-root partial-unique index
  // and read-path switch land in later PRs. v7 → v8 backfills existing data
  // into the tree shape (PR-2): a virtual root per topic + parentId /
  // siblingsGroupId / activeNodeId, via [backfillMessageTree]. The single-root
  // partial-unique index is deliberately deferred to PR-3 — until the write
  // path attaches new messages to the tree, a freshly-sent message would still
  // have parentId=null and collide with the (also-null-parent) root under that
  // index.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(providerRows);
      }
      if (from < 3) {
        await m.createTable(groupRows);
      }
      if (from < 4) {
        await m.createTable(appSettingRows);
      }
      if (from < 5) {
        await m.createTable(memoryRows);
      }
      if (from < 6) {
        await m.createTable(memoryHistoryRows);
      }
      if (from < 7) {
        await m.addColumn(messageRows, messageRows.parentId);
        await m.addColumn(messageRows, messageRows.role);
        await m.addColumn(messageRows, messageRows.siblingsGroupId);
        await m.addColumn(messageRows, messageRows.createdAt);
        // @TableIndex 只在 createTable/createAll 时建；对已存在的表手动建索引。
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_messages_parent_id '
          'ON message_rows (parent_id)',
        );
      }
      if (from < 8) {
        // 回填存量数据为树形：建虚拟根 + parentId/siblingsGroupId + activeNodeId。
        // 非破坏性（不删旧字段）、幂等（已有根的话题跳过），失败可由回退代码恢复。
        await backfillMessageTree(this);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'aetherlink.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
