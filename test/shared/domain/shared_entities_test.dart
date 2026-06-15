import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/custom_parameter.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);

  test('Model round-trips with capabilities and model types', () {
    const model = Model(
      id: 'gpt-4o',
      name: 'GPT-4o',
      provider: 'openai',
      providerType: 'openai',
      temperature: 0.7,
      maxTokens: 4096,
      capabilities: ModelCapabilities(multimodal: true, vision: true),
      modelTypes: [ModelType.chat, ModelType.vision],
      extraHeaders: {'X-Trace': '1'},
    );
    expect(Model.fromJson(model.toJson()), model);
  });

  test('Assistant round-trips and pins snake_case keys', () {
    final assistant = Assistant(
      id: 'a1',
      name: 'Helper',
      emoji: '🤖',
      tags: const ['general'],
      temperature: 0.5,
      topicIds: const ['t1', 't2'],
      toolChoice: 'auto',
      fileIds: const ['f1'],
      createdAt: createdAt,
      customParameters: const [
        CustomParameter(
          name: 'topK',
          value: '40',
          type: CustomParameterType.number,
        ),
      ],
      regexRules: const [
        AssistantRegex(
          id: 'r1',
          name: 'strip',
          pattern: r'\s+',
          replacement: ' ',
          scopes: [AssistantRegexScope.user],
          visualOnly: true,
          enabled: true,
        ),
      ],
    );
    final json = assistant.toJson();
    expect(json['tool_choice'], 'auto');
    expect(json['file_ids'], const ['f1']);
    expect(json.containsKey('toolChoice'), isFalse);
    expect(Assistant.fromJson(json), assistant);
  });

  test('Topic round-trips and keeps lastMessageTime as a string', () {
    final topic = Topic(
      id: 't1',
      assistantId: 'a1',
      name: 'First topic',
      createdAt: createdAt,
      updatedAt: createdAt,
      isNameManuallyEdited: true,
      messageIds: const ['m1', 'm2'],
      lastMessageTime: '2024-01-02T03:04:05.000Z',
      pinned: true,
    );
    final json = topic.toJson();
    expect(json['lastMessageTime'], isA<String>());
    expect(Topic.fromJson(json), topic);
  });
}
