import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

/// Builds the markdown document sent to Notion for a topic export.
///
/// Pure function over chat `domain` entities; the Notion API converts markdown
/// to blocks server-side (`POST /v1/pages` `markdown` body param), so this only
/// needs to produce plain GFM-style markdown.
String buildNotionMarkdown({
  required List<Message> messages,
  required Map<String, List<MessageBlock>> blocksByMessageId,
  required bool includeReasoning,
}) {
  final sections = <String>[];
  for (final message in messages) {
    if (message.role == MessageRole.system) continue;
    final blocks = blocksByMessageId[message.id] ?? const [];
    final parts = <String>[_roleHeading(message)];

    if (includeReasoning) {
      final thinking = blocks
          .whereType<ThinkingBlock>()
          .map((b) => b.content.trim())
          .where((c) => c.isNotEmpty)
          .join('\n\n');
      if (thinking.isNotEmpty) {
        parts.add('### 思考过程\n\n${_quote(thinking)}');
      }
    }

    for (final block in blocks) {
      final rendered = switch (block) {
        MainTextBlock(:final content) => content.trim(),
        CodeBlock(:final content, :final language) =>
          '```${language ?? ''}\n${content.trimRight()}\n```',
        ToolBlock(:final toolName, :final toolId) =>
          '> 🔧 工具调用：${toolName ?? toolId}',
        ImageBlock(:final url) =>
          url.startsWith('http') ? '![图片]($url)' : '*[图片]*',
        FileBlock(:final name) => '*[文件] $name*',
        _ => '',
      };
      if (rendered.isNotEmpty) parts.add(rendered);
    }

    if (parts.length > 1) sections.add(parts.join('\n\n'));
  }
  return sections.isEmpty ? '*此话题暂无消息*' : sections.join('\n\n---\n\n');
}

String _roleHeading(Message message) {
  if (message.role == MessageRole.user) return '## 用户';
  final model = message.model?.name ?? message.modelId;
  return model == null || model.isEmpty ? '## 助手' : '## 助手（$model）';
}

String _quote(String text) =>
    text.split('\n').map((line) => '> $line').join('\n');
