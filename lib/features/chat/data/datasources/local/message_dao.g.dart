// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_dao.dart';

// ignore_for_file: type=lint
mixin _$MessageDaoMixin on DatabaseAccessor<AppDatabase> {
  $MessageRowsTable get messageRows => attachedDatabase.messageRows;
  MessageDaoManager get managers => MessageDaoManager(this);
}

class MessageDaoManager {
  final _$MessageDaoMixin _db;
  MessageDaoManager(this._db);
  $$MessageRowsTableTableManager get messageRows =>
      $$MessageRowsTableTableManager(_db.attachedDatabase, _db.messageRows);
}
