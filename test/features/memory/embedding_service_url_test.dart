import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/knowledge/data/knowledge_rerank_service.dart';
import 'package:aetherlink_flutter/features/memory/data/embedding_service.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

/// 记录请求路径并返回固定 JSON 的假适配器。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseBody);

  final Map<String, dynamic> responseBody;
  final List<String> urls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    return ResponseBody.fromString(
      jsonEncode(responseBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Model _model(String? baseUrl) => Model(
  id: 'embed-1',
  name: 'embed-1',
  provider: 'test',
  baseUrl: baseUrl,
  apiKey: 'k',
);

void main() {
  group('EmbeddingService baseUrl 归一化（对齐 CS formatApiHost）', () {
    Future<String> requestUrl(String? baseUrl) async {
      final adapter = _RecordingAdapter({
        'data': [
          {
            'index': 0,
            'embedding': [0.1],
          },
        ],
      });
      final dio = Dio()..httpClientAdapter = adapter;
      await EmbeddingService(dio).embed(_model(baseUrl), 'hi');
      return adapter.urls.single;
    }

    test('裸 host 自动补 /v1', () async {
      expect(
        await requestUrl('https://api.siliconflow.cn'),
        'https://api.siliconflow.cn/v1/embeddings',
      );
    });

    test('已带版本段的 host 保持不变', () async {
      expect(
        await requestUrl('https://api.siliconflow.cn/v1'),
        'https://api.siliconflow.cn/v1/embeddings',
      );
    });

    test('末尾 # 为精确地址逃生口', () async {
      expect(
        await requestUrl('https://my.proxy/custom#'),
        'https://my.proxy/custom/embeddings',
      );
    });

    test('无 baseUrl 回落 OpenAI', () async {
      expect(await requestUrl(null), 'https://api.openai.com/v1/embeddings');
    });
  });

  group('KnowledgeRerankService baseUrl 归一化', () {
    test('裸 host 自动补 /v1', () async {
      final adapter = _RecordingAdapter({
        'results': [
          {'index': 0, 'relevance_score': 0.9},
        ],
      });
      final dio = Dio()..httpClientAdapter = adapter;
      await KnowledgeRerankService(
        dio,
      ).rerank(_model('https://api.jina.ai'), query: 'q', documents: ['d']);
      expect(adapter.urls.single, 'https://api.jina.ai/v1/rerank');
    });
  });
}
