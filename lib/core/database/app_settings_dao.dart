import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/database/app_settings_table.dart';

part 'app_settings_dao.g.dart';

/// Data-access object for the [AppSettingRows] key/value store. Reads/writes a
/// single string value under a unique key (the port of `dexieStorage`'s
/// `getSetting` / `saveSetting`).
@DriftAccessor(tables: [AppSettingRows])
class AppSettingDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingDaoMixin {
  AppSettingDao(super.db);

  /// The value stored under [key], or `null` if unset.
  Future<String?> getValue(String key) async {
    final row = await (select(
      appSettingRows,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Inserts or overwrites the value stored under [key].
  Future<void> setValue(String key, String value) {
    return into(appSettingRows).insertOnConflictUpdate(
      AppSettingRowsCompanion.insert(key: key, value: value),
    );
  }
}
