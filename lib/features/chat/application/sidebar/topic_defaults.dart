import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// A blank topic seeded like the web `getDefaultTopic`: name "新的对话",
/// `lastMessageTime` = now (ISO), no messages.
Topic newDefaultTopic({
  required String id,
  required String assistantId,
  required DateTime now,
}) => Topic(
  id: id,
  assistantId: assistantId,
  name: '新的对话',
  createdAt: now,
  updatedAt: now,
  lastMessageTime: now.toIso8601String(),
);

/// Sort comparator matching the web `sortedTopics`: pinned first, then by
/// `lastMessageTime || updatedAt || createdAt` descending.
int compareTopicsByRecency(Topic a, Topic b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  return _topicMillis(b).compareTo(_topicMillis(a));
}

int _topicMillis(Topic t) {
  final last = t.lastMessageTime;
  if (last != null) {
    final parsed = DateTime.tryParse(last);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return t.updatedAt.millisecondsSinceEpoch;
}
