import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Drift [TypeConverter]s that store a whole domain entity as a JSON blob in a
/// single text column — the document-storage strategy carried over from the
/// original IndexedDB schema (see `docs/adr/0003-drift-for-persistence.md`).
///
/// Each converter round-trips through the entity's own `toJson` / `fromJson`,
/// so the persisted shape stays identical to the web app's stored records.

/// Stores a [Topic] as a JSON blob.
class TopicConverter extends TypeConverter<Topic, String> {
  const TopicConverter();

  @override
  Topic fromSql(String fromDb) =>
      Topic.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(Topic value) => jsonEncode(value.toJson());
}

/// Stores a [Message] as a JSON blob.
class MessageConverter extends TypeConverter<Message, String> {
  const MessageConverter();

  @override
  Message fromSql(String fromDb) =>
      Message.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(Message value) => jsonEncode(value.toJson());
}

/// Stores a [MessageBlock] (any of the 15 union variants) as a JSON blob.
class MessageBlockConverter extends TypeConverter<MessageBlock, String> {
  const MessageBlockConverter();

  @override
  MessageBlock fromSql(String fromDb) =>
      MessageBlock.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(MessageBlock value) => jsonEncode(value.toJson());
}

/// Stores an [Assistant] as a JSON blob.
class AssistantConverter extends TypeConverter<Assistant, String> {
  const AssistantConverter();

  @override
  Assistant fromSql(String fromDb) =>
      Assistant.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(Assistant value) => jsonEncode(value.toJson());
}
