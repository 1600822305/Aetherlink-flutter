import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/features/chat/data/datasources/remote/media/media_generation_api.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A dio [HttpClientAdapter] that replays a FIFO list of JSON bodies (no
/// network) and records every outgoing request so URL / headers / body
/// construction can be asserted.
class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<Map<String, dynamic>> responses;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = utf8.encode(jsonEncode(responses.removeAt(0)));
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Dio _dioWith(_QueueAdapter adapter) => Dio()..httpClientAdapter = adapter;

Map<String, dynamic> _decodedBody(RequestOptions request) =>
    request.data is String
    ? jsonDecode(request.data as String) as Map<String, dynamic>
    : Map<String, dynamic>.from(request.data as Map);

void main() {
  const base = 'https://api.example.com';

  group('MediaGenerationApi — OpenAI-compatible image route', () {
    test(
      'posts to /images/generations with auth + merged provider extras',
      () async {
        final adapter = _QueueAdapter([
          {
            'data': [
              {'url': 'https://cdn.example.com/i/1.png'},
            ],
          },
        ]);
        final api = MediaGenerationApi(_dioWith(adapter));
        const model = Model(
          id: 'dall-e-3',
          name: 'DALL·E 3',
          provider: 'openai',
          apiKey: 'sk-test',
          baseUrl: base,
          extraHeaders: {'X-Model-Trace': 'model'},
          extraBody: {'quality': 'hd'},
          providerExtraHeaders: {'X-Provider-Key': 'provider'},
          providerExtraBody: {'n': 2},
        );

        final urls = await api.generateImages(model: model, prompt: 'a cat');

        expect(urls, ['https://cdn.example.com/i/1.png']);
        final request = adapter.requests.single;
        expect(request.uri.toString(), '$base/v1/images/generations');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer sk-test');
        expect(request.headers['X-Model-Trace'], 'model');
        expect(request.headers['X-Provider-Key'], 'provider');
        final body = _decodedBody(request);
        expect(body['model'], 'dall-e-3');
        expect(body['prompt'], 'a cat');
        expect(body['response_format'], 'url');
        expect(body['size'], '1024x1024');
        // Custom body fields merge (provider-level wins over model-level).
        expect(body['quality'], 'hd');
        expect(body['n'], 2);
      },
    );
  });

  group('MediaGenerationApi — Gemini image route', () {
    test(
      'posts generateContent with x-goog-api-key and responseModalities',
      () async {
        final adapter = _QueueAdapter([
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {
                        'data': 'aGVsbG8=',
                        'mimeType': 'image/png',
                      },
                    },
                  ],
                },
              },
            ],
          },
        ]);
        final api = MediaGenerationApi(_dioWith(adapter));
        const model = Model(
          id: 'gemini-2.5-flash-image',
          name: 'Gemini Image',
          provider: 'google',
          providerType: 'gemini',
          apiKey: 'goog-key',
          baseUrl: base,
          providerExtraHeaders: {'X-Provider-Key': 'provider'},
        );

        final urls = await api.generateImages(model: model, prompt: 'a cat');

        expect(urls, ['data:image/png;base64,aGVsbG8=']);
        final request = adapter.requests.single;
        expect(
          request.uri.toString(),
          '$base/models/gemini-2.5-flash-image:generateContent',
        );
        expect(request.headers['x-goog-api-key'], 'goog-key');
        expect(request.headers['X-Provider-Key'], 'provider');
        final body = _decodedBody(request);
        expect((body['generationConfig'] as Map)['responseModalities'], [
          'TEXT',
          'IMAGE',
        ]);
      },
    );
  });

  group('MediaGenerationApi — DashScope image route', () {
    test(
      'dashscope + qwen-image posts the native multimodal endpoint',
      () async {
        final adapter = _QueueAdapter([
          {
            'output': {
              'choices': [
                {
                  'message': {
                    'content': [
                      {'image': 'https://cdn.example.com/i/qwen.png'},
                    ],
                  },
                },
              ],
            },
          },
        ]);
        final api = MediaGenerationApi(_dioWith(adapter));
        const model = Model(
          id: 'qwen-image',
          name: 'Qwen Image',
          provider: 'dashscope',
          providerType: 'dashscope',
          apiKey: 'sk-dash',
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          extraBody: {'negative_prompt': 'blur'},
        );

        final urls = await api.generateImages(model: model, prompt: 'a cat');

        expect(urls, ['https://cdn.example.com/i/qwen.png']);
        final request = adapter.requests.single;
        expect(
          request.uri.toString(),
          'https://dashscope.aliyuncs.com'
          '/api/v1/services/aigc/multimodal-generation/generation',
        );
        expect(request.headers['Authorization'], 'Bearer sk-dash');
        final body = _decodedBody(request);
        expect(body['model'], 'qwen-image');
        expect(body['negative_prompt'], 'blur');
      },
    );
  });

  group('MediaGenerationApi — video routes', () {
    test(
      'siliconflow-style submit merges extras; status poll stays clean',
      () async {
        final adapter = _QueueAdapter([
          {'requestId': 'req-1'},
          {
            'status': 'Succeed',
            'results': {
              'videos': [
                {'url': 'https://cdn.example.com/v/1.mp4'},
              ],
            },
          },
        ]);
        final api = MediaGenerationApi(_dioWith(adapter));
        const model = Model(
          id: 'Wan-AI/Wan2.1-T2V-720P',
          name: 'Wan2.1 T2V',
          provider: 'siliconflow',
          apiKey: 'sk-sf',
          baseUrl: base,
          extraHeaders: {'X-Model-Trace': 'model'},
          providerExtraBody: {'image_size': '1280x720'},
        );

        // Shrink polling to zero for the test.
        final url = await api
            .generateVideo(model: model, prompt: 'waves')
            .timeout(const Duration(seconds: 60));

        expect(url, 'https://cdn.example.com/v/1.mp4');
        expect(adapter.requests, hasLength(2));

        final submit = adapter.requests.first;
        expect(submit.uri.toString(), '$base/v1/video/submit');
        expect(submit.headers['Authorization'], 'Bearer sk-sf');
        expect(submit.headers['X-Model-Trace'], 'model');
        final submitBody = _decodedBody(submit);
        expect(submitBody['model'], 'Wan-AI/Wan2.1-T2V-720P');
        expect(submitBody['prompt'], 'waves');
        expect(submitBody['image_size'], '1280x720');

        // The status poll must keep the protocol-defined body — no injected
        // extras — while still carrying custom headers.
        final poll = adapter.requests.last;
        expect(poll.uri.toString(), '$base/v1/video/status');
        expect(poll.headers['X-Model-Trace'], 'model');
        expect(_decodedBody(poll), {'requestId': 'req-1'});
      },
    );

    test('veo submits predictLongRunning then polls the operation', () async {
      final adapter = _QueueAdapter([
        {'name': 'operations/op-1'},
        {
          'done': true,
          'response': {
            'generateVideoResponse': {
              'generatedSamples': [
                {
                  'video': {'uri': 'https://cdn.example.com/v/veo.mp4'},
                },
              ],
            },
          },
        },
      ]);
      final api = MediaGenerationApi(_dioWith(adapter));
      const model = Model(
        id: 'veo-2.0-generate-001',
        name: 'Veo 2',
        provider: 'google',
        providerType: 'gemini',
        apiKey: 'goog-key',
        baseUrl: base,
        providerExtraHeaders: {'X-Provider-Key': 'provider'},
      );

      final url = await api
          .generateVideo(model: model, prompt: 'waves')
          .timeout(const Duration(seconds: 60));

      expect(url, 'https://cdn.example.com/v/veo.mp4?key=goog-key');
      expect(adapter.requests, hasLength(2));

      final submit = adapter.requests.first;
      expect(
        submit.uri.toString(),
        '$base/models/veo-2.0-generate-001:predictLongRunning',
      );
      expect(submit.headers['x-goog-api-key'], 'goog-key');
      expect(submit.headers['X-Provider-Key'], 'provider');
      final submitBody = _decodedBody(submit);
      expect((submitBody['instances'] as List).first['prompt'], 'waves');

      // Operation poll is a GET with headers only — no extra body injected.
      final poll = adapter.requests.last;
      expect(poll.method, 'GET');
      expect(poll.uri.toString(), '$base/operations/op-1');
      expect(poll.headers['x-goog-api-key'], 'goog-key');
    });
  });
}
