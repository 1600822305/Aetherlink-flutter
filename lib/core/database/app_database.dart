import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/assistant_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/assistants_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_block_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_blocks_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/messages_table.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/topic_dao.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/topics_table.dart';
// Domain entities persisted as JSON blobs. The generated `app_database.g.dart`
// part references these types (column converters / row data classes), so they
// must be in this library's scope — see the carve-out in
// `test/architecture/import_boundaries_test.dart`.
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/model_provider_converters.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/provider_dao.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/providers_table.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
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
  ],
  daos: [TopicDao, MessageDao, MessageBlockDao, AssistantDao, ProviderDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database file (`aetherlink.sqlite` under the app
  /// documents directory).
  AppDatabase.open() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  // v1 → v2 adds the model-provider store ([ProviderRows]). The one-time
  // IndexedDB (`aetherlink-db-new` v9) → SQLite data import remains a separate
  // cross-cutting task (see docs/ROADMAP.md).
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(providerRows);
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
