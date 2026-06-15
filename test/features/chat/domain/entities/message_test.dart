import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);

  test('Message round-trips fromJson(toJson(x)) == x', () {
    final message = Message(
      id: 'msg1',
      role: MessageRole.assistant,
      assistantId: 'a1',
      topicId: 't1',
      createdAt: createdAt,
      updatedAt: createdAt,
      status: MessageStatus.success,
      modelId: 'gpt-4o',
      model: const Model(id: 'gpt-4o', name: 'GPT-4o', provider: 'openai'),
      askId: 'q1',
      usage: const Usage(
        promptTokens: 10,
        completionTokens: 20,
        totalTokens: 30,
      ),
      metrics: const Metrics(latency: 120, firstTokenLatency: 40),
      blocks: const ['b1', 'b2'],
      versions: [
        MessageVersion(id: 'v1', messageId: 'msg1', createdAt: createdAt),
      ],
      currentVersionId: 'v1',
      multiModelMessageStyle: MultiModelMessageStyle.grid,
    );

    expect(Message.fromJson(message.toJson()), message);
  });

  test('Message defaults blocks to an empty list when absent', () {
    final json = <String, dynamic>{
      'id': 'msg2',
      'role': 'user',
      'assistantId': 'a1',
      'topicId': 't1',
      'createdAt': '2024-01-02T03:04:05.000Z',
      'status': 'sending',
    };
    final message = Message.fromJson(json);
    expect(message.blocks, isEmpty);
    expect(message.role, MessageRole.user);
    expect(message.status, MessageStatus.sending);
  });
}
