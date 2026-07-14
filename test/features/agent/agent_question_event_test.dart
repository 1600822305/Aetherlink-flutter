import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

void main() {
  test('结构化提问和回答元数据可持久化往返', () {
    final at = DateTime(2026, 7, 14);
    final question = UserQuestionEvent(
      id: 'question-1',
      seq: 1,
      at: at,
      toolCallId: 'call-1',
      argsJson: '{"questions":[]}',
      questions: const [
        AgentUserQuestion(question: '选择环境', options: ['测试', '生产']),
        AgentUserQuestion(
          question: '选择检查项',
          options: ['日志', '指标'],
          allowMultiple: true,
        ),
      ],
    );
    final decodedQuestion = decodeAgentEvent(
      id: question.id,
      seq: question.seq,
      at: question.at,
      kind: agentEventKind(question),
      payloadJson: encodeAgentEventPayload(question),
    ) as UserQuestionEvent;

    expect(decodedQuestion.toolCallId, 'call-1');
    expect(decodedQuestion.questions, hasLength(2));
    expect(decodedQuestion.questions.last.allowMultiple, isTrue);

    final answer = UserMessageEvent(
      id: 'answer-1',
      seq: 2,
      at: at,
      text: '测试；日志、指标',
      replyToQuestionId: question.id,
      questionAnswers: const [
        AgentUserQuestionAnswer(questionIndex: 0, values: ['测试']),
        AgentUserQuestionAnswer(questionIndex: 1, values: ['日志', '指标']),
      ],
    );
    final decodedAnswer = decodeAgentEvent(
      id: answer.id,
      seq: answer.seq,
      at: answer.at,
      kind: agentEventKind(answer),
      payloadJson: encodeAgentEventPayload(answer),
    ) as UserMessageEvent;

    expect(decodedAnswer.replyToQuestionId, question.id);
    expect(decodedAnswer.questionAnswers.last.values, ['日志', '指标']);
    expect(
      userQuestionAnswer(decodedQuestion, [decodedQuestion, decodedAnswer]),
      same(decodedAnswer),
    );
  });

  test('旧版单问题 payload 仍可读取', () {
    final event = decodeAgentEvent(
      id: 'legacy-question',
      seq: 1,
      at: DateTime(2026, 7, 14),
      kind: 'user_question',
      payloadJson: jsonEncode({
        'question': '是否继续？',
        'options': ['继续', '停止'],
      }),
    ) as UserQuestionEvent;

    expect(event.questions, hasLength(1));
    expect(event.question, '是否继续？');
    expect(event.options, ['继续', '停止']);
  });
}
