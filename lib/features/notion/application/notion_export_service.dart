import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/notion/application/notion_markdown_builder.dart';
import 'package:aetherlink_flutter/features/notion/data/notion_client.dart';
import 'package:aetherlink_flutter/features/notion/domain/notion_entities.dart';
import 'package:aetherlink_flutter/features/notion/domain/notion_settings.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Exports chat content to the configured Notion data source as new pages.
///
/// Composition (the [ChatRepository] instance) is injected by `app/di`
/// (`notion_access.dart`); this class itself stays framework-free.
class NotionExportService {
  const NotionExportService({required ChatRepository repository})
    : _repository = repository;

  final ChatRepository _repository;

  /// Exports a whole topic (its current conversation branch) as one page.
  Future<NotionPageResult> exportTopic(
    Topic topic,
    NotionSettings settings,
  ) async {
    final messages = await _repository.getBranchMessages(topic.id);
    final blocksByMessageId = <String, List<MessageBlock>>{
      for (final Message message in messages)
        if (message.blocks.isNotEmpty)
          message.id: await _repository.getMessageBlocksByIds(message.blocks),
    };
    final markdown = buildNotionMarkdown(
      messages: messages,
      blocksByMessageId: blocksByMessageId,
      includeReasoning: settings.includeReasoning,
    );
    return exportMarkdown(
      settings: settings,
      title: topic.name.isEmpty ? '未命名对话' : topic.name,
      markdown: markdown,
      date: topic.createdAt,
    );
  }

  /// Exports an arbitrary markdown document (e.g. the 消息导出 sheet's
  /// selection) as one page.
  Future<NotionPageResult> exportMarkdown({
    required NotionSettings settings,
    required String title,
    required String markdown,
    DateTime? date,
  }) async {
    if (!settings.isConfigured) {
      throw const NotionApiException('Notion 集成未配置，请先在设置中连接数据库');
    }
    final client = NotionClient(apiKey: settings.apiKey);
    try {
      return await client.createPage(
        dataSourceId: settings.dataSourceId,
        titleProperty: settings.titleProperty,
        title: title,
        dateProperty: settings.dateProperty,
        date: date,
        markdown: markdown,
      );
    } finally {
      client.close();
    }
  }
}
