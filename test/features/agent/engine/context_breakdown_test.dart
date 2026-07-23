import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/context_breakdown.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_content_image.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

void main() {
  test('estimateContextTokens：CJK 与拉丁字符按不同密度估算', () {
    expect(estimateContextTokens(''), 0);
    // 8 个拉丁字符 ≈ 2 tokens。
    expect(estimateContextTokens('abcdefgh'), 2);
    // 3 个 CJK 字符 ≈ 2 tokens（3/1.5）。
    expect(estimateContextTokens('你好吗'), 2);
  });

  test('computeContextBreakdown：按组成分类且总和一致', () {
    final breakdown = computeContextBreakdown(
      systemPrompt: 'system prompt here',
      toolDefinitions: const [
        McpToolDefinition(
          name: 'read_file',
          description: 'read a file',
          inputSchema: {'type': 'object'},
        ),
      ],
      messages: const [
        LlmMessage(role: MessageRole.user, content: '帮我修个 bug'),
        LlmMessage(role: MessageRole.assistant, content: '好的，我看看。'),
        LlmMessage(
          role: MessageRole.assistant,
          content: '',
          toolCalls: [
            LlmToolCall(
              id: 't1',
              name: 'read_file',
              arguments: '{"path":"a.dart"}',
            ),
          ],
        ),
        LlmMessage(
          role: MessageRole.user,
          content: 'file contents...',
          toolCallId: 't1',
          toolName: 'read_file',
        ),
        LlmMessage(
          role: MessageRole.user,
          content: '[上下文已压缩]更早的执行过程已压缩为以下摘要：\n摘要',
        ),
      ],
      apiContextTokens: 1234,
    );

    final byLabel = {
      for (final s in breakdown.sections) s.label: s.estimatedTokens,
    };
    expect(byLabel['系统提示'], greaterThan(0));
    expect(byLabel['工具定义'], greaterThan(0));
    expect(byLabel['用户消息'], greaterThan(0));
    expect(byLabel['助手回复'], greaterThan(0));
    expect(byLabel['工具调用与结果'], greaterThan(0));
    expect(byLabel['压缩摘要'], greaterThan(0));
    expect(breakdown.apiContextTokens, 1234);
    expect(
      breakdown.estimatedTotal,
      byLabel.values.fold(0, (a, b) => a + b),
    );
  });

  test('computeContextBreakdown：图片按每张固定估算单列', () {
    final breakdown = computeContextBreakdown(
      systemPrompt: 's',
      toolDefinitions: const [],
      messages: const [
        LlmMessage(
          role: MessageRole.user,
          content: '[上一条 browser_snapshot 工具结果的截图]',
          images: [
            LlmContentImage(mimeType: 'image/jpeg', base64Data: 'aGk='),
            LlmContentImage(mimeType: 'image/png', base64Data: 'aGk='),
          ],
        ),
      ],
    );
    final byLabel = {
      for (final s in breakdown.sections) s.label: s.estimatedTokens,
    };
    expect(byLabel['图片'], 2 * kEstimatedTokensPerImage);
  });

  test('computeContextBreakdown：无压缩摘要时不出该分类', () {
    final breakdown = computeContextBreakdown(
      systemPrompt: 's',
      toolDefinitions: const [],
      messages: const [
        LlmMessage(role: MessageRole.user, content: 'hi'),
      ],
    );
    expect(
      breakdown.sections.map((s) => s.label),
      isNot(contains('压缩摘要')),
    );
  });
}
