import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';

part 'database_provider.g.dart';

/// The single app-wide Drift database handle (composition root in
/// `core/database`). Kept alive for the app's lifetime and closed when the
/// container disposes.
///
/// Every feature must reach the database through this provider — opening a
/// second [AppDatabase] on the same file creates a second SQLite connection,
/// and two connections writing concurrently throw
/// "database is locked (code 5)" (WAL + busy_timeout in
/// [AppDatabase.open] only soften, not remove, that failure mode).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}
