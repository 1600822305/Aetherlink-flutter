import 'package:aetherlink_flutter/features/chat/domain/entities/citation_metadata.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/citation_source.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/chart_type.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_file_reference.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_reference_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);

  group('MessageBlock round-trips fromJson(toJson(x)) == x', () {
    test('main_text', () {
      final block = MessageBlock.mainText(
        id: 'b1',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: 'hello world',
      );
      expect(MessageBlock.fromJson(block.toJson()), block);
    });

    test('thinking (pinned snake_case key thinking_millsec)', () {
      final block = MessageBlock.thinking(
        id: 'b2',
        messageId: 'm1',
        status: MessageBlockStatus.streaming,
        createdAt: createdAt,
        content: 'let me think',
        thinkingMillsec: 1200,
        thinkingStartTime: 1700000000000,
      );
      final json = block.toJson();
      expect(json['thinking_millsec'], 1200);
      expect(json.containsKey('thinkingMillsec'), isFalse);
      expect(MessageBlock.fromJson(json), block);
    });

    test('image with shared file value object', () {
      final block = MessageBlock.image(
        id: 'b3',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        url: 'https://example.com/a.png',
        mimeType: 'image/png',
        width: 640,
        height: 480,
        file: const MessageFileReference(
          id: 'f1',
          name: 'stored.png',
          originName: 'photo.png',
          size: 1024,
          mimeType: 'image/png',
        ),
      );
      final json = block.toJson();
      expect(
        (json['file'] as Map<String, dynamic>)['origin_name'],
        'photo.png',
      );
      expect(MessageBlock.fromJson(json), block);
    });

    test('tool (string content + dynamic arguments map)', () {
      final block = MessageBlock.tool(
        id: 'b4',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        toolId: 't1',
        toolName: 'search',
        arguments: const {'query': 'dart', 'limit': 5},
        content: 'tool output text',
      );
      expect(MessageBlock.fromJson(block.toJson()), block);
    });

    test('citation (typed knowledge / webSearch / sources / metadata)', () {
      final block = MessageBlock.citation(
        id: 'b5',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: 'see sources',
        sources: const [CitationSource(title: 'Doc', url: 'https://d')],
        knowledge: const [
          KnowledgeReferenceItem(index: 1, content: 'kb', similarity: 0.91),
        ],
        webSearch: const [
          WebSearchReferenceItem(index: 1, title: 'Hit', url: 'https://w'),
        ],
        citationMetadata: const CitationMetadata(searchQuery: 'dart'),
      );
      expect(MessageBlock.fromJson(block.toJson()), block);
    });

    test('context_summary (numbers + extra compressedAt timestamp)', () {
      final block = MessageBlock.contextSummary(
        id: 'b6',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: 'summary',
        originalMessageCount: 10,
        originalTokens: 5000,
        compressedTokens: 800,
        tokensSaved: 4200,
        cost: 0.0123,
        compressedAt: DateTime.utc(2024, 1, 2, 4, 0, 0),
        modelId: 'gpt',
      );
      expect(MessageBlock.fromJson(block.toJson()), block);
    });

    test('translation', () {
      final block = MessageBlock.translation(
        id: 'b7',
        messageId: 'm1',
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: '你好',
        sourceContent: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(MessageBlock.fromJson(block.toJson()), block);
    });
  });

  group('MessageBlock JSON discriminator', () {
    test('type key drives the variant and round-trips at JSON level', () {
      final json = <String, dynamic>{
        'type': 'chart',
        'id': 'b8',
        'messageId': 'm1',
        'status': 'success',
        'createdAt': '2024-01-02T03:04:05.000Z',
        'chartType': 'bar',
        'data': <String, dynamic>{'x': 1, 'y': 2},
      };
      final decoded = MessageBlock.fromJson(json);
      expect(decoded, isA<ChartBlock>());
      expect((decoded as ChartBlock).chartType, ChartType.bar);
      expect(decoded.toJson(), json);
    });

    test('unrecognised type falls back to UnknownBlock', () {
      final json = <String, dynamic>{
        'type': 'some_future_type',
        'id': 'b9',
        'messageId': 'm1',
        'status': 'pending',
        'createdAt': '2024-01-02T03:04:05.000Z',
        'content': 'placeholder',
      };
      expect(MessageBlock.fromJson(json), isA<UnknownBlock>());
    });
  });

  test('kTerminalBlockStatuses matches the source terminal set', () {
    expect(kTerminalBlockStatuses, {
      MessageBlockStatus.success,
      MessageBlockStatus.error,
      MessageBlockStatus.paused,
    });
  });
}
