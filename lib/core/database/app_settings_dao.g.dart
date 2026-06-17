// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$AppSettingDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppSettingRowsTable get appSettingRows => attachedDatabase.appSettingRows;
  AppSettingDaoManager get managers => AppSettingDaoManager(this);
}

class AppSettingDaoManager {
  final _$AppSettingDaoMixin _db;
  AppSettingDaoManager(this._db);
  $$AppSettingRowsTableTableManager get appSettingRows =>
      $$AppSettingRowsTableTableManager(
        _db.attachedDatabase,
        _db.appSettingRows,
      );
}
