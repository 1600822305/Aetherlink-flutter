import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

void main() {
  test('提问和回答元数据可持久化往返', () {
    final at = DateTime(2026, 7, 14);
    final question = UserQuestionEvent(
      id: 'question-1',
      seq: 1,
      at: at,
      toolCallId: 'call-1',
      argsJson: '{"question":"选择发布环境","follow_up":["测试","生产"]}',
      question: '选择发布环境',
      suggestions: const ['测试', '生产'],
    );
    final decodedQuestion = decodeAgentEvent(
      id: question.id,
      seq: question.seq,
      at: question.at,
      kind: agentEventKind(question),
      payloadJson: encodeAgentEventPayload(question),
    ) as UserQuestionEvent;

    expect(decodedQuestion.toolCallId, 'call-1');
    expect(decodedQuestion.argsJson, question.argsJson);
    expect(decodedQuestion.question, '选择发布环境');
    expect(decodedQuestion.suggestions, ['测试', '生产']);

    final answer = UserMessageEvent(
      id: 'answer-1',
      seq: 2,
      at: at,
      text: '测试',
      replyToQuestionId: question.id,
    );
    final decodedAnswer = decodeAgentEvent(
      id: answer.id,
      seq: answer.seq,
      at: answer.at,
      kind: agentEventKind(answer),
      payloadJson: encodeAgentEventPayload(answer),
    ) as UserMessageEvent;

    expect(decodedAnswer.replyToQuestionId, question.id);
    expect(decodedAnswer.text, '测试');
    expect(
      userQuestionAnswer(decodedQuestion, [decodedQuestion, decodedAnswer]),
      same(decodedAnswer),
    );
  });

  test('未回答的提问是最新待答项', () {
    final at = DateTime(2026, 7, 14);
    final question = UserQuestionEvent(
      id: 'question-1',
      seq: 1,
      at: at,
      toolCallId: 'call-1',
      question: '是否继续？',
      suggestions: const ['继续', '停止'],
    );

    expect(latestPendingUserQuestion([question]), same(question));
    expect(
      latestPendingUserQuestion([
        question,
        UserMessageEvent(
          id: 'answer-1',
          seq: 2,
          at: at,
          text: '继续',
          replyToQuestionId: question.id,
        ),
      ]),
      isNull,
    );
  });
}
