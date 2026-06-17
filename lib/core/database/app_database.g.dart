// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TopicRowsTable extends TopicRows
    with TableInfo<$TopicRowsTable, TopicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageTimeNumMeta =
      const VerificationMeta('lastMessageTimeNum');
  @override
  late final GeneratedColumn<int> lastMessageTimeNum = GeneratedColumn<int>(
    'last_message_time_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Topic, String> data =
      GeneratedColumn<String>(
        'data',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Topic>($TopicRowsTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns => [id, lastMessageTimeNum, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topic_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<TopicRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('last_message_time_num')) {
      context.handle(
        _lastMessageTimeNumMeta,
        lastMessageTimeNum.isAcceptableOrUnknown(
          data['last_message_time_num']!,
          _lastMessageTimeNumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMessageTimeNumMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TopicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TopicRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lastMessageTimeNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_time_num'],
      )!,
      data: $TopicRowsTable.$converterdata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data'],
        )!,
      ),
    );
  }

  @override
  $TopicRowsTable createAlias(String alias) {
    return $TopicRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<Topic, String> $converterdata = const TopicConverter();
}

class TopicRow extends DataClass implements Insertable<TopicRow> {
  final String id;
  final int lastMessageTimeNum;
  final Topic data;
  const TopicRow({
    required this.id,
    required this.lastMessageTimeNum,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['last_message_time_num'] = Variable<int>(lastMessageTimeNum);
    {
      map['data'] = Variable<String>(
        $TopicRowsTable.$converterdata.toSql(data),
      );
    }
    return map;
  }

  TopicRowsCompanion toCompanion(bool nullToAbsent) {
    return TopicRowsCompanion(
      id: Value(id),
      lastMessageTimeNum: Value(lastMessageTimeNum),
      data: Value(data),
    );
  }

  factory TopicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TopicRow(
      id: serializer.fromJson<String>(json['id']),
      lastMessageTimeNum: serializer.fromJson<int>(json['lastMessageTimeNum']),
      data: serializer.fromJson<Topic>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lastMessageTimeNum': serializer.toJson<int>(lastMessageTimeNum),
      'data': serializer.toJson<Topic>(data),
    };
  }

  TopicRow copyWith({String? id, int? lastMessageTimeNum, Topic? data}) =>
      TopicRow(
        id: id ?? this.id,
        lastMessageTimeNum: lastMessageTimeNum ?? this.lastMessageTimeNum,
        data: data ?? this.data,
      );
  TopicRow copyWithCompanion(TopicRowsCompanion data) {
    return TopicRow(
      id: data.id.present ? data.id.value : this.id,
      lastMessageTimeNum: data.lastMessageTimeNum.present
          ? data.lastMessageTimeNum.value
          : this.lastMessageTimeNum,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopicRow(')
          ..write('id: $id, ')
          ..write('lastMessageTimeNum: $lastMessageTimeNum, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastMessageTimeNum, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicRow &&
          other.id == this.id &&
          other.lastMessageTimeNum == this.lastMessageTimeNum &&
          other.data == this.data);
}

class TopicRowsCompanion extends UpdateCompanion<TopicRow> {
  final Value<String> id;
  final Value<int> lastMessageTimeNum;
  final Value<Topic> data;
  final Value<int> rowid;
  const TopicRowsCompanion({
    this.id = const Value.absent(),
    this.lastMessageTimeNum = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicRowsCompanion.insert({
    required String id,
    required int lastMessageTimeNum,
    required Topic data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lastMessageTimeNum = Value(lastMessageTimeNum),
       data = Value(data);
  static Insertable<TopicRow> custom({
    Expression<String>? id,
    Expression<int>? lastMessageTimeNum,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastMessageTimeNum != null)
        'last_message_time_num': lastMessageTimeNum,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? lastMessageTimeNum,
    Value<Topic>? data,
    Value<int>? rowid,
  }) {
    return TopicRowsCompanion(
      id: id ?? this.id,
      lastMessageTimeNum: lastMessageTimeNum ?? this.lastMessageTimeNum,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lastMessageTimeNum.present) {
      map['last_message_time_num'] = Variable<int>(lastMessageTimeNum.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(
        $TopicRowsTable.$converterdata.toSql(data.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicRowsCompanion(')
          ..write('id: $id, ')
          ..write('lastMessageTimeNum: $lastMessageTimeNum, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageRowsTable extends MessageRows
    with TableInfo<$MessageRowsTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assistantIdMeta = const VerificationMeta(
    'assistantId',
  );
  @override
  late final GeneratedColumn<String> assistantId = GeneratedColumn<String>(
    'assistant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Message, String> data =
      GeneratedColumn<String>(
        'data',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Message>($MessageRowsTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns => [id, topicId, assistantId, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('assistant_id')) {
      context.handle(
        _assistantIdMeta,
        assistantId.isAcceptableOrUnknown(
          data['assistant_id']!,
          _assistantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assistantIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      assistantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_id'],
      )!,
      data: $MessageRowsTable.$converterdata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data'],
        )!,
      ),
    );
  }

  @override
  $MessageRowsTable createAlias(String alias) {
    return $MessageRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<Message, String> $converterdata =
      const MessageConverter();
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String topicId;
  final String assistantId;
  final Message data;
  const MessageRow({
    required this.id,
    required this.topicId,
    required this.assistantId,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['topic_id'] = Variable<String>(topicId);
    map['assistant_id'] = Variable<String>(assistantId);
    {
      map['data'] = Variable<String>(
        $MessageRowsTable.$converterdata.toSql(data),
      );
    }
    return map;
  }

  MessageRowsCompanion toCompanion(bool nullToAbsent) {
    return MessageRowsCompanion(
      id: Value(id),
      topicId: Value(topicId),
      assistantId: Value(assistantId),
      data: Value(data),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      topicId: serializer.fromJson<String>(json['topicId']),
      assistantId: serializer.fromJson<String>(json['assistantId']),
      data: serializer.fromJson<Message>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'topicId': serializer.toJson<String>(topicId),
      'assistantId': serializer.toJson<String>(assistantId),
      'data': serializer.toJson<Message>(data),
    };
  }

  MessageRow copyWith({
    String? id,
    String? topicId,
    String? assistantId,
    Message? data,
  }) => MessageRow(
    id: id ?? this.id,
    topicId: topicId ?? this.topicId,
    assistantId: assistantId ?? this.assistantId,
    data: data ?? this.data,
  );
  MessageRow copyWithCompanion(MessageRowsCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      assistantId: data.assistantId.present
          ? data.assistantId.value
          : this.assistantId,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('topicId: $topicId, ')
          ..write('assistantId: $assistantId, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, topicId, assistantId, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.topicId == this.topicId &&
          other.assistantId == this.assistantId &&
          other.data == this.data);
}

class MessageRowsCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> topicId;
  final Value<String> assistantId;
  final Value<Message> data;
  final Value<int> rowid;
  const MessageRowsCompanion({
    this.id = const Value.absent(),
    this.topicId = const Value.absent(),
    this.assistantId = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageRowsCompanion.insert({
    required String id,
    required String topicId,
    required String assistantId,
    required Message data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       topicId = Value(topicId),
       assistantId = Value(assistantId),
       data = Value(data);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? topicId,
    Expression<String>? assistantId,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (topicId != null) 'topic_id': topicId,
      if (assistantId != null) 'assistant_id': assistantId,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? topicId,
    Value<String>? assistantId,
    Value<Message>? data,
    Value<int>? rowid,
  }) {
    return MessageRowsCompanion(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      assistantId: assistantId ?? this.assistantId,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (assistantId.present) {
      map['assistant_id'] = Variable<String>(assistantId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(
        $MessageRowsTable.$converterdata.toSql(data.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageRowsCompanion(')
          ..write('id: $id, ')
          ..write('topicId: $topicId, ')
          ..write('assistantId: $assistantId, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageBlockRowsTable extends MessageBlockRows
    with TableInfo<$MessageBlockRowsTable, MessageBlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageBlockRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageBlock, String> data =
      GeneratedColumn<String>(
        'data',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MessageBlock>($MessageBlockRowsTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns => [id, messageId, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_block_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageBlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageBlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageBlockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      data: $MessageBlockRowsTable.$converterdata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data'],
        )!,
      ),
    );
  }

  @override
  $MessageBlockRowsTable createAlias(String alias) {
    return $MessageBlockRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<MessageBlock, String> $converterdata =
      const MessageBlockConverter();
}

class MessageBlockRow extends DataClass implements Insertable<MessageBlockRow> {
  final String id;
  final String messageId;
  final MessageBlock data;
  const MessageBlockRow({
    required this.id,
    required this.messageId,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    {
      map['data'] = Variable<String>(
        $MessageBlockRowsTable.$converterdata.toSql(data),
      );
    }
    return map;
  }

  MessageBlockRowsCompanion toCompanion(bool nullToAbsent) {
    return MessageBlockRowsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      data: Value(data),
    );
  }

  factory MessageBlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageBlockRow(
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      data: serializer.fromJson<MessageBlock>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'data': serializer.toJson<MessageBlock>(data),
    };
  }

  MessageBlockRow copyWith({
    String? id,
    String? messageId,
    MessageBlock? data,
  }) => MessageBlockRow(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    data: data ?? this.data,
  );
  MessageBlockRow copyWithCompanion(MessageBlockRowsCompanion data) {
    return MessageBlockRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageBlockRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, messageId, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageBlockRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.data == this.data);
}

class MessageBlockRowsCompanion extends UpdateCompanion<MessageBlockRow> {
  final Value<String> id;
  final Value<String> messageId;
  final Value<MessageBlock> data;
  final Value<int> rowid;
  const MessageBlockRowsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageBlockRowsCompanion.insert({
    required String id,
    required String messageId,
    required MessageBlock data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       messageId = Value(messageId),
       data = Value(data);
  static Insertable<MessageBlockRow> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageBlockRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? messageId,
    Value<MessageBlock>? data,
    Value<int>? rowid,
  }) {
    return MessageBlockRowsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(
        $MessageBlockRowsTable.$converterdata.toSql(data.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageBlockRowsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantRowsTable extends AssistantRows
    with TableInfo<$AssistantRowsTable, AssistantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Assistant, String> data =
      GeneratedColumn<String>(
        'data',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Assistant>($AssistantRowsTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      data: $AssistantRowsTable.$converterdata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data'],
        )!,
      ),
    );
  }

  @override
  $AssistantRowsTable createAlias(String alias) {
    return $AssistantRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<Assistant, String> $converterdata =
      const AssistantConverter();
}

class AssistantRow extends DataClass implements Insertable<AssistantRow> {
  final String id;
  final Assistant data;
  const AssistantRow({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['data'] = Variable<String>(
        $AssistantRowsTable.$converterdata.toSql(data),
      );
    }
    return map;
  }

  AssistantRowsCompanion toCompanion(bool nullToAbsent) {
    return AssistantRowsCompanion(id: Value(id), data: Value(data));
  }

  factory AssistantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantRow(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<Assistant>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<Assistant>(data),
    };
  }

  AssistantRow copyWith({String? id, Assistant? data}) =>
      AssistantRow(id: id ?? this.id, data: data ?? this.data);
  AssistantRow copyWithCompanion(AssistantRowsCompanion data) {
    return AssistantRow(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantRow(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantRow && other.id == this.id && other.data == this.data);
}

class AssistantRowsCompanion extends UpdateCompanion<AssistantRow> {
  final Value<String> id;
  final Value<Assistant> data;
  final Value<int> rowid;
  const AssistantRowsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantRowsCompanion.insert({
    required String id,
    required Assistant data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data);
  static Insertable<AssistantRow> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantRowsCompanion copyWith({
    Value<String>? id,
    Value<Assistant>? data,
    Value<int>? rowid,
  }) {
    return AssistantRowsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(
        $AssistantRowsTable.$converterdata.toSql(data.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantRowsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderRowsTable extends ProviderRows
    with TableInfo<$ProviderRowsTable, ProviderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ModelProvider, String> data =
      GeneratedColumn<String>(
        'data',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ModelProvider>($ProviderRowsTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns => [id, sortOrder, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      data: $ProviderRowsTable.$converterdata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data'],
        )!,
      ),
    );
  }

  @override
  $ProviderRowsTable createAlias(String alias) {
    return $ProviderRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<ModelProvider, String> $converterdata =
      const ModelProviderConverter();
}

class ProviderRow extends DataClass implements Insertable<ProviderRow> {
  final String id;
  final int sortOrder;
  final ModelProvider data;
  const ProviderRow({
    required this.id,
    required this.sortOrder,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sort_order'] = Variable<int>(sortOrder);
    {
      map['data'] = Variable<String>(
        $ProviderRowsTable.$converterdata.toSql(data),
      );
    }
    return map;
  }

  ProviderRowsCompanion toCompanion(bool nullToAbsent) {
    return ProviderRowsCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      data: Value(data),
    );
  }

  factory ProviderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderRow(
      id: serializer.fromJson<String>(json['id']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      data: serializer.fromJson<ModelProvider>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'data': serializer.toJson<ModelProvider>(data),
    };
  }

  ProviderRow copyWith({String? id, int? sortOrder, ModelProvider? data}) =>
      ProviderRow(
        id: id ?? this.id,
        sortOrder: sortOrder ?? this.sortOrder,
        data: data ?? this.data,
      );
  ProviderRow copyWithCompanion(ProviderRowsCompanion data) {
    return ProviderRow(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderRow(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sortOrder, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderRow &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.data == this.data);
}

class ProviderRowsCompanion extends UpdateCompanion<ProviderRow> {
  final Value<String> id;
  final Value<int> sortOrder;
  final Value<ModelProvider> data;
  final Value<int> rowid;
  const ProviderRowsCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderRowsCompanion.insert({
    required String id,
    required int sortOrder,
    required ModelProvider data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sortOrder = Value(sortOrder),
       data = Value(data);
  static Insertable<ProviderRow> custom({
    Expression<String>? id,
    Expression<int>? sortOrder,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? sortOrder,
    Value<ModelProvider>? data,
    Value<int>? rowid,
  }) {
    return ProviderRowsCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(
        $ProviderRowsTable.$converterdata.toSql(data.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderRowsCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupRowsTable extends GroupRows
    with TableInfo<$GroupRowsTable, GroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Group, String> data =
      GeneratedColumn<String>(
        'data',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Group>($GroupRowsTable.$converterdata);
  @override
  List<GeneratedColumn> get $columns => [id, orderIndex, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      data: $GroupRowsTable.$converterdata.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data'],
        )!,
      ),
    );
  }

  @override
  $GroupRowsTable createAlias(String alias) {
    return $GroupRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<Group, String> $converterdata = const GroupConverter();
}

class GroupRow extends DataClass implements Insertable<GroupRow> {
  final String id;
  final int orderIndex;
  final Group data;
  const GroupRow({
    required this.id,
    required this.orderIndex,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_index'] = Variable<int>(orderIndex);
    {
      map['data'] = Variable<String>(
        $GroupRowsTable.$converterdata.toSql(data),
      );
    }
    return map;
  }

  GroupRowsCompanion toCompanion(bool nullToAbsent) {
    return GroupRowsCompanion(
      id: Value(id),
      orderIndex: Value(orderIndex),
      data: Value(data),
    );
  }

  factory GroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupRow(
      id: serializer.fromJson<String>(json['id']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      data: serializer.fromJson<Group>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'data': serializer.toJson<Group>(data),
    };
  }

  GroupRow copyWith({String? id, int? orderIndex, Group? data}) => GroupRow(
    id: id ?? this.id,
    orderIndex: orderIndex ?? this.orderIndex,
    data: data ?? this.data,
  );
  GroupRow copyWithCompanion(GroupRowsCompanion data) {
    return GroupRow(
      id: data.id.present ? data.id.value : this.id,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupRow(')
          ..write('id: $id, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderIndex, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupRow &&
          other.id == this.id &&
          other.orderIndex == this.orderIndex &&
          other.data == this.data);
}

class GroupRowsCompanion extends UpdateCompanion<GroupRow> {
  final Value<String> id;
  final Value<int> orderIndex;
  final Value<Group> data;
  final Value<int> rowid;
  const GroupRowsCompanion({
    this.id = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupRowsCompanion.insert({
    required String id,
    required int orderIndex,
    required Group data,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderIndex = Value(orderIndex),
       data = Value(data);
  static Insertable<GroupRow> custom({
    Expression<String>? id,
    Expression<int>? orderIndex,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderIndex != null) 'order_index': orderIndex,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? orderIndex,
    Value<Group>? data,
    Value<int>? rowid,
  }) {
    return GroupRowsCompanion(
      id: id ?? this.id,
      orderIndex: orderIndex ?? this.orderIndex,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(
        $GroupRowsTable.$converterdata.toSql(data.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupRowsCompanion(')
          ..write('id: $id, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingRowsTable extends AppSettingRows
    with TableInfo<$AppSettingRowsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_setting_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingRowsTable createAlias(String alias) {
    return $AppSettingRowsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  const AppSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingRowsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingRowsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSettingRow copyWith({String? key, String? value}) =>
      AppSettingRow(key: key ?? this.key, value: value ?? this.value);
  AppSettingRow copyWithCompanion(AppSettingRowsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingRowsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingRowsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingRowsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingRowsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRowsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TopicRowsTable topicRows = $TopicRowsTable(this);
  late final $MessageRowsTable messageRows = $MessageRowsTable(this);
  late final $MessageBlockRowsTable messageBlockRows = $MessageBlockRowsTable(
    this,
  );
  late final $AssistantRowsTable assistantRows = $AssistantRowsTable(this);
  late final $ProviderRowsTable providerRows = $ProviderRowsTable(this);
  late final $GroupRowsTable groupRows = $GroupRowsTable(this);
  late final $AppSettingRowsTable appSettingRows = $AppSettingRowsTable(this);
  late final Index idxTopicsLastMessageTimeNum = Index(
    'idx_topics_last_message_time_num',
    'CREATE INDEX idx_topics_last_message_time_num ON topic_rows (last_message_time_num)',
  );
  late final Index idxMessagesTopicId = Index(
    'idx_messages_topic_id',
    'CREATE INDEX idx_messages_topic_id ON message_rows (topic_id)',
  );
  late final Index idxMessagesAssistantId = Index(
    'idx_messages_assistant_id',
    'CREATE INDEX idx_messages_assistant_id ON message_rows (assistant_id)',
  );
  late final Index idxMessageBlocksMessageId = Index(
    'idx_message_blocks_message_id',
    'CREATE INDEX idx_message_blocks_message_id ON message_block_rows (message_id)',
  );
  late final Index idxProvidersSortOrder = Index(
    'idx_providers_sort_order',
    'CREATE INDEX idx_providers_sort_order ON provider_rows (sort_order)',
  );
  late final Index idxGroupsOrder = Index(
    'idx_groups_order',
    'CREATE INDEX idx_groups_order ON group_rows (order_index)',
  );
  late final TopicDao topicDao = TopicDao(this as AppDatabase);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final MessageBlockDao messageBlockDao = MessageBlockDao(
    this as AppDatabase,
  );
  late final AssistantDao assistantDao = AssistantDao(this as AppDatabase);
  late final ProviderDao providerDao = ProviderDao(this as AppDatabase);
  late final GroupDao groupDao = GroupDao(this as AppDatabase);
  late final AppSettingDao appSettingDao = AppSettingDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    topicRows,
    messageRows,
    messageBlockRows,
    assistantRows,
    providerRows,
    groupRows,
    appSettingRows,
    idxTopicsLastMessageTimeNum,
    idxMessagesTopicId,
    idxMessagesAssistantId,
    idxMessageBlocksMessageId,
    idxProvidersSortOrder,
    idxGroupsOrder,
  ];
}

typedef $$TopicRowsTableCreateCompanionBuilder =
    TopicRowsCompanion Function({
      required String id,
      required int lastMessageTimeNum,
      required Topic data,
      Value<int> rowid,
    });
typedef $$TopicRowsTableUpdateCompanionBuilder =
    TopicRowsCompanion Function({
      Value<String> id,
      Value<int> lastMessageTimeNum,
      Value<Topic> data,
      Value<int> rowid,
    });

class $$TopicRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TopicRowsTable> {
  $$TopicRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageTimeNum => $composableBuilder(
    column: $table.lastMessageTimeNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Topic, Topic, String> get data =>
      $composableBuilder(
        column: $table.data,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$TopicRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TopicRowsTable> {
  $$TopicRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageTimeNum => $composableBuilder(
    column: $table.lastMessageTimeNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TopicRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopicRowsTable> {
  $$TopicRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastMessageTimeNum => $composableBuilder(
    column: $table.lastMessageTimeNum,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Topic, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$TopicRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TopicRowsTable,
          TopicRow,
          $$TopicRowsTableFilterComposer,
          $$TopicRowsTableOrderingComposer,
          $$TopicRowsTableAnnotationComposer,
          $$TopicRowsTableCreateCompanionBuilder,
          $$TopicRowsTableUpdateCompanionBuilder,
          (TopicRow, BaseReferences<_$AppDatabase, $TopicRowsTable, TopicRow>),
          TopicRow,
          PrefetchHooks Function()
        > {
  $$TopicRowsTableTableManager(_$AppDatabase db, $TopicRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> lastMessageTimeNum = const Value.absent(),
                Value<Topic> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicRowsCompanion(
                id: id,
                lastMessageTimeNum: lastMessageTimeNum,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int lastMessageTimeNum,
                required Topic data,
                Value<int> rowid = const Value.absent(),
              }) => TopicRowsCompanion.insert(
                id: id,
                lastMessageTimeNum: lastMessageTimeNum,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TopicRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TopicRowsTable,
      TopicRow,
      $$TopicRowsTableFilterComposer,
      $$TopicRowsTableOrderingComposer,
      $$TopicRowsTableAnnotationComposer,
      $$TopicRowsTableCreateCompanionBuilder,
      $$TopicRowsTableUpdateCompanionBuilder,
      (TopicRow, BaseReferences<_$AppDatabase, $TopicRowsTable, TopicRow>),
      TopicRow,
      PrefetchHooks Function()
    >;
typedef $$MessageRowsTableCreateCompanionBuilder =
    MessageRowsCompanion Function({
      required String id,
      required String topicId,
      required String assistantId,
      required Message data,
      Value<int> rowid,
    });
typedef $$MessageRowsTableUpdateCompanionBuilder =
    MessageRowsCompanion Function({
      Value<String> id,
      Value<String> topicId,
      Value<String> assistantId,
      Value<Message> data,
      Value<int> rowid,
    });

class $$MessageRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageRowsTable> {
  $$MessageRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Message, Message, String> get data =>
      $composableBuilder(
        column: $table.data,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MessageRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageRowsTable> {
  $$MessageRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageRowsTable> {
  $$MessageRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<String> get assistantId => $composableBuilder(
    column: $table.assistantId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Message, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$MessageRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageRowsTable,
          MessageRow,
          $$MessageRowsTableFilterComposer,
          $$MessageRowsTableOrderingComposer,
          $$MessageRowsTableAnnotationComposer,
          $$MessageRowsTableCreateCompanionBuilder,
          $$MessageRowsTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$AppDatabase, $MessageRowsTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessageRowsTableTableManager(_$AppDatabase db, $MessageRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> topicId = const Value.absent(),
                Value<String> assistantId = const Value.absent(),
                Value<Message> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageRowsCompanion(
                id: id,
                topicId: topicId,
                assistantId: assistantId,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String topicId,
                required String assistantId,
                required Message data,
                Value<int> rowid = const Value.absent(),
              }) => MessageRowsCompanion.insert(
                id: id,
                topicId: topicId,
                assistantId: assistantId,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageRowsTable,
      MessageRow,
      $$MessageRowsTableFilterComposer,
      $$MessageRowsTableOrderingComposer,
      $$MessageRowsTableAnnotationComposer,
      $$MessageRowsTableCreateCompanionBuilder,
      $$MessageRowsTableUpdateCompanionBuilder,
      (
        MessageRow,
        BaseReferences<_$AppDatabase, $MessageRowsTable, MessageRow>,
      ),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$MessageBlockRowsTableCreateCompanionBuilder =
    MessageBlockRowsCompanion Function({
      required String id,
      required String messageId,
      required MessageBlock data,
      Value<int> rowid,
    });
typedef $$MessageBlockRowsTableUpdateCompanionBuilder =
    MessageBlockRowsCompanion Function({
      Value<String> id,
      Value<String> messageId,
      Value<MessageBlock> data,
      Value<int> rowid,
    });

class $$MessageBlockRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageBlockRowsTable> {
  $$MessageBlockRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageBlock, MessageBlock, String> get data =>
      $composableBuilder(
        column: $table.data,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MessageBlockRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageBlockRowsTable> {
  $$MessageBlockRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageBlockRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageBlockRowsTable> {
  $$MessageBlockRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageBlock, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$MessageBlockRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageBlockRowsTable,
          MessageBlockRow,
          $$MessageBlockRowsTableFilterComposer,
          $$MessageBlockRowsTableOrderingComposer,
          $$MessageBlockRowsTableAnnotationComposer,
          $$MessageBlockRowsTableCreateCompanionBuilder,
          $$MessageBlockRowsTableUpdateCompanionBuilder,
          (
            MessageBlockRow,
            BaseReferences<
              _$AppDatabase,
              $MessageBlockRowsTable,
              MessageBlockRow
            >,
          ),
          MessageBlockRow,
          PrefetchHooks Function()
        > {
  $$MessageBlockRowsTableTableManager(
    _$AppDatabase db,
    $MessageBlockRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageBlockRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageBlockRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageBlockRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<MessageBlock> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageBlockRowsCompanion(
                id: id,
                messageId: messageId,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String messageId,
                required MessageBlock data,
                Value<int> rowid = const Value.absent(),
              }) => MessageBlockRowsCompanion.insert(
                id: id,
                messageId: messageId,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageBlockRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageBlockRowsTable,
      MessageBlockRow,
      $$MessageBlockRowsTableFilterComposer,
      $$MessageBlockRowsTableOrderingComposer,
      $$MessageBlockRowsTableAnnotationComposer,
      $$MessageBlockRowsTableCreateCompanionBuilder,
      $$MessageBlockRowsTableUpdateCompanionBuilder,
      (
        MessageBlockRow,
        BaseReferences<_$AppDatabase, $MessageBlockRowsTable, MessageBlockRow>,
      ),
      MessageBlockRow,
      PrefetchHooks Function()
    >;
typedef $$AssistantRowsTableCreateCompanionBuilder =
    AssistantRowsCompanion Function({
      required String id,
      required Assistant data,
      Value<int> rowid,
    });
typedef $$AssistantRowsTableUpdateCompanionBuilder =
    AssistantRowsCompanion Function({
      Value<String> id,
      Value<Assistant> data,
      Value<int> rowid,
    });

class $$AssistantRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantRowsTable> {
  $$AssistantRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Assistant, Assistant, String> get data =>
      $composableBuilder(
        column: $table.data,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$AssistantRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantRowsTable> {
  $$AssistantRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssistantRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantRowsTable> {
  $$AssistantRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Assistant, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$AssistantRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantRowsTable,
          AssistantRow,
          $$AssistantRowsTableFilterComposer,
          $$AssistantRowsTableOrderingComposer,
          $$AssistantRowsTableAnnotationComposer,
          $$AssistantRowsTableCreateCompanionBuilder,
          $$AssistantRowsTableUpdateCompanionBuilder,
          (
            AssistantRow,
            BaseReferences<_$AppDatabase, $AssistantRowsTable, AssistantRow>,
          ),
          AssistantRow,
          PrefetchHooks Function()
        > {
  $$AssistantRowsTableTableManager(_$AppDatabase db, $AssistantRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Assistant> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantRowsCompanion(id: id, data: data, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required Assistant data,
                Value<int> rowid = const Value.absent(),
              }) => AssistantRowsCompanion.insert(
                id: id,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssistantRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantRowsTable,
      AssistantRow,
      $$AssistantRowsTableFilterComposer,
      $$AssistantRowsTableOrderingComposer,
      $$AssistantRowsTableAnnotationComposer,
      $$AssistantRowsTableCreateCompanionBuilder,
      $$AssistantRowsTableUpdateCompanionBuilder,
      (
        AssistantRow,
        BaseReferences<_$AppDatabase, $AssistantRowsTable, AssistantRow>,
      ),
      AssistantRow,
      PrefetchHooks Function()
    >;
typedef $$ProviderRowsTableCreateCompanionBuilder =
    ProviderRowsCompanion Function({
      required String id,
      required int sortOrder,
      required ModelProvider data,
      Value<int> rowid,
    });
typedef $$ProviderRowsTableUpdateCompanionBuilder =
    ProviderRowsCompanion Function({
      Value<String> id,
      Value<int> sortOrder,
      Value<ModelProvider> data,
      Value<int> rowid,
    });

class $$ProviderRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderRowsTable> {
  $$ProviderRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ModelProvider, ModelProvider, String>
  get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$ProviderRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderRowsTable> {
  $$ProviderRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderRowsTable> {
  $$ProviderRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ModelProvider, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$ProviderRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderRowsTable,
          ProviderRow,
          $$ProviderRowsTableFilterComposer,
          $$ProviderRowsTableOrderingComposer,
          $$ProviderRowsTableAnnotationComposer,
          $$ProviderRowsTableCreateCompanionBuilder,
          $$ProviderRowsTableUpdateCompanionBuilder,
          (
            ProviderRow,
            BaseReferences<_$AppDatabase, $ProviderRowsTable, ProviderRow>,
          ),
          ProviderRow,
          PrefetchHooks Function()
        > {
  $$ProviderRowsTableTableManager(_$AppDatabase db, $ProviderRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<ModelProvider> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderRowsCompanion(
                id: id,
                sortOrder: sortOrder,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int sortOrder,
                required ModelProvider data,
                Value<int> rowid = const Value.absent(),
              }) => ProviderRowsCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderRowsTable,
      ProviderRow,
      $$ProviderRowsTableFilterComposer,
      $$ProviderRowsTableOrderingComposer,
      $$ProviderRowsTableAnnotationComposer,
      $$ProviderRowsTableCreateCompanionBuilder,
      $$ProviderRowsTableUpdateCompanionBuilder,
      (
        ProviderRow,
        BaseReferences<_$AppDatabase, $ProviderRowsTable, ProviderRow>,
      ),
      ProviderRow,
      PrefetchHooks Function()
    >;
typedef $$GroupRowsTableCreateCompanionBuilder =
    GroupRowsCompanion Function({
      required String id,
      required int orderIndex,
      required Group data,
      Value<int> rowid,
    });
typedef $$GroupRowsTableUpdateCompanionBuilder =
    GroupRowsCompanion Function({
      Value<String> id,
      Value<int> orderIndex,
      Value<Group> data,
      Value<int> rowid,
    });

class $$GroupRowsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupRowsTable> {
  $$GroupRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Group, Group, String> get data =>
      $composableBuilder(
        column: $table.data,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$GroupRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupRowsTable> {
  $$GroupRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupRowsTable> {
  $$GroupRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Group, String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$GroupRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupRowsTable,
          GroupRow,
          $$GroupRowsTableFilterComposer,
          $$GroupRowsTableOrderingComposer,
          $$GroupRowsTableAnnotationComposer,
          $$GroupRowsTableCreateCompanionBuilder,
          $$GroupRowsTableUpdateCompanionBuilder,
          (GroupRow, BaseReferences<_$AppDatabase, $GroupRowsTable, GroupRow>),
          GroupRow,
          PrefetchHooks Function()
        > {
  $$GroupRowsTableTableManager(_$AppDatabase db, $GroupRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<Group> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupRowsCompanion(
                id: id,
                orderIndex: orderIndex,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int orderIndex,
                required Group data,
                Value<int> rowid = const Value.absent(),
              }) => GroupRowsCompanion.insert(
                id: id,
                orderIndex: orderIndex,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupRowsTable,
      GroupRow,
      $$GroupRowsTableFilterComposer,
      $$GroupRowsTableOrderingComposer,
      $$GroupRowsTableAnnotationComposer,
      $$GroupRowsTableCreateCompanionBuilder,
      $$GroupRowsTableUpdateCompanionBuilder,
      (GroupRow, BaseReferences<_$AppDatabase, $GroupRowsTable, GroupRow>),
      GroupRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingRowsTableCreateCompanionBuilder =
    AppSettingRowsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingRowsTableUpdateCompanionBuilder =
    AppSettingRowsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingRowsTable> {
  $$AppSettingRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingRowsTable> {
  $$AppSettingRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingRowsTable> {
  $$AppSettingRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingRowsTable,
          AppSettingRow,
          $$AppSettingRowsTableFilterComposer,
          $$AppSettingRowsTableOrderingComposer,
          $$AppSettingRowsTableAnnotationComposer,
          $$AppSettingRowsTableCreateCompanionBuilder,
          $$AppSettingRowsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingRowsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingRowsTableTableManager(
    _$AppDatabase db,
    $AppSettingRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  AppSettingRowsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingRowsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingRowsTable,
      AppSettingRow,
      $$AppSettingRowsTableFilterComposer,
      $$AppSettingRowsTableOrderingComposer,
      $$AppSettingRowsTableAnnotationComposer,
      $$AppSettingRowsTableCreateCompanionBuilder,
      $$AppSettingRowsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingRowsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TopicRowsTableTableManager get topicRows =>
      $$TopicRowsTableTableManager(_db, _db.topicRows);
  $$MessageRowsTableTableManager get messageRows =>
      $$MessageRowsTableTableManager(_db, _db.messageRows);
  $$MessageBlockRowsTableTableManager get messageBlockRows =>
      $$MessageBlockRowsTableTableManager(_db, _db.messageBlockRows);
  $$AssistantRowsTableTableManager get assistantRows =>
      $$AssistantRowsTableTableManager(_db, _db.assistantRows);
  $$ProviderRowsTableTableManager get providerRows =>
      $$ProviderRowsTableTableManager(_db, _db.providerRows);
  $$GroupRowsTableTableManager get groupRows =>
      $$GroupRowsTableTableManager(_db, _db.groupRows);
  $$AppSettingRowsTableTableManager get appSettingRows =>
      $$AppSettingRowsTableTableManager(_db, _db.appSettingRows);
}
