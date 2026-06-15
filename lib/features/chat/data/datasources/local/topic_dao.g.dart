// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic_dao.dart';

// ignore_for_file: type=lint
mixin _$TopicDaoMixin on DatabaseAccessor<AppDatabase> {
  $TopicRowsTable get topicRows => attachedDatabase.topicRows;
  TopicDaoManager get managers => TopicDaoManager(this);
}

class TopicDaoManager {
  final _$TopicDaoMixin _db;
  TopicDaoManager(this._db);
  $$TopicRowsTableTableManager get topicRows =>
      $$TopicRowsTableTableManager(_db.attachedDatabase, _db.topicRows);
}
