// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_dao.dart';

// ignore_for_file: type=lint
mixin _$AssistantDaoMixin on DatabaseAccessor<AppDatabase> {
  $AssistantRowsTable get assistantRows => attachedDatabase.assistantRows;
  AssistantDaoManager get managers => AssistantDaoManager(this);
}

class AssistantDaoManager {
  final _$AssistantDaoMixin _db;
  AssistantDaoManager(this._db);
  $$AssistantRowsTableTableManager get assistantRows =>
      $$AssistantRowsTableTableManager(_db.attachedDatabase, _db.assistantRows);
}
