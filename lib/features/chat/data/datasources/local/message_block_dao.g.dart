// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_block_dao.dart';

// ignore_for_file: type=lint
mixin _$MessageBlockDaoMixin on DatabaseAccessor<AppDatabase> {
  $MessageBlockRowsTable get messageBlockRows =>
      attachedDatabase.messageBlockRows;
  MessageBlockDaoManager get managers => MessageBlockDaoManager(this);
}

class MessageBlockDaoManager {
  final _$MessageBlockDaoMixin _db;
  MessageBlockDaoManager(this._db);
  $$MessageBlockRowsTableTableManager get messageBlockRows =>
      $$MessageBlockRowsTableTableManager(
        _db.attachedDatabase,
        _db.messageBlockRows,
      );
}
