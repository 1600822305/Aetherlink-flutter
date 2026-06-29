import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';

void main() {
  Message msg(String id, DateTime createdAt) => Message(
    id: id,
    role: MessageRole.user,
    assistantId: 'a1',
    topicId: 't1',
    createdAt: createdAt,
    status: MessageStatus.success,
  );

  test('orders by createdAt first', () {
    final a = msg('z', DateTime(2024, 1, 1));
    final b = msg('a', DateTime(2024, 1, 2));
    expect(compareMessagesChronologically(a, b), lessThan(0));
    expect(compareMessagesChronologically(b, a), greaterThan(0));
  });

  test('breaks createdAt ties deterministically by id', () {
    final t = DateTime(2024, 1, 1);
    final a = msg('msg-a', t);
    final b = msg('msg-b', t);
    expect(compareMessagesChronologically(a, b), lessThan(0));
    expect(compareMessagesChronologically(b, a), greaterThan(0));
    expect(compareMessagesChronologically(a, a), 0);
  });

  test('sorting a tied list is stable regardless of input order', () {
    final t = DateTime(2024, 1, 1);
    final forward = [msg('msg-a', t), msg('msg-b', t), msg('msg-c', t)]
      ..sort(compareMessagesChronologically);
    final shuffled = [msg('msg-c', t), msg('msg-a', t), msg('msg-b', t)]
      ..sort(compareMessagesChronologically);
    expect(forward.map((m) => m.id).toList(), ['msg-a', 'msg-b', 'msg-c']);
    expect(shuffled.map((m) => m.id).toList(), ['msg-a', 'msg-b', 'msg-c']);
  });
}
