// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_dao.dart';

// ignore_for_file: type=lint
mixin _$ProviderDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProviderRowsTable get providerRows => attachedDatabase.providerRows;
  ProviderDaoManager get managers => ProviderDaoManager(this);
}

class ProviderDaoManager {
  final _$ProviderDaoMixin _db;
  ProviderDaoManager(this._db);
  $$ProviderRowsTableTableManager get providerRows =>
      $$ProviderRowsTableTableManager(_db.attachedDatabase, _db.providerRows);
}
