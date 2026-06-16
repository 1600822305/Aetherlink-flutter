import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/model_catalog.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A dio [HttpClientAdapter] that replays a fixed JSON body (no network). It
/// captures the outgoing request so url / header construction can be asserted
/// and can simulate a non-2xx response to exercise the error path.
class _JsonReplayAdapter implements HttpClientAdapter {
  _JsonReplayAdapter(this.json, {this.statusCode = 200});

  final String json;
  final int statusCode;
  RequestOptions? request;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final bytes = utf8.encode(json);
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Dio _dioWith(_JsonReplayAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  group('LlmModelCatalogImpl', () {
    test('OpenAI-compatible: parses the standard {data:[...]} list', () async {
      final adapter = _JsonReplayAdapter(
        jsonEncode({
          'object': 'list',
          'data': [
            {'id': 'gpt-4o', 'owned_by': 'openai'},
            {'id': 'gpt-4o-mini', 'name': 'GPT-4o mini'},
            {'id': ''}, // dropped: empty id
          ],
        }),
      );
      final catalog = LlmModelCatalogImpl(dio: _dioWith(adapter));

      final models = await catalog.listModels(
        const LlmModelQuery(
          providerType: 'openai',
          apiKey: 'sk-test',
          baseUrl: 'https://api.example.test/v1',
        ),
      );

      expect(models.map((m) => m.id), ['gpt-4o', 'gpt-4o-mini']);
      expect(models.first.ownedBy, 'openai');
      expect(models[1].name, 'GPT-4o mini');

      // Endpoint + auth: base already has /v1, so just append /models.
      expect(
        adapter.request!.uri.toString(),
        'https://api.example.test/v1/models',
      );
      expect(adapter.request!.headers['Authorization'], 'Bearer sk-test');
    });

    test('OpenAI-compatible: adds /v1 when the base lacks it', () async {
      final adapter = _JsonReplayAdapter(
        jsonEncode({'data': <Map<String, dynamic>>[]}),
      );
      final catalog = LlmModelCatalogImpl(dio: _dioWith(adapter));

      await catalog.listModels(
        const LlmModelQuery(
          providerType: 'openai',
          baseUrl: 'https://proxy.test',
        ),
      );

      expect(adapter.request!.uri.toString(), 'https://proxy.test/v1/models');
    });

    test(
      'OpenAI-compatible: tolerates a bare array and {models:[...]}',
      () async {
        final arrayCatalog = LlmModelCatalogImpl(
          dio: _dioWith(
            _JsonReplayAdapter(
              jsonEncode([
                {'id': 'm1'},
              ]),
            ),
          ),
        );
        expect(
          (await arrayCatalog.listModels(
            const LlmModelQuery(providerType: 'openai'),
          )).map((m) => m.id),
          ['m1'],
        );

        final modelsKeyCatalog = LlmModelCatalogImpl(
          dio: _dioWith(
            _JsonReplayAdapter(
              jsonEncode({
                'models': [
                  {'id': 'm2'},
                ],
              }),
            ),
          ),
        );
        expect(
          (await modelsKeyCatalog.listModels(
            const LlmModelQuery(providerType: 'openai'),
          )).map((m) => m.id),
          ['m2'],
        );
      },
    );

    test('Anthropic: x-api-key header + /v1/models endpoint', () async {
      final adapter = _JsonReplayAdapter(
        jsonEncode({
          'data': [
            {'id': 'claude-3-5-sonnet', 'display_name': 'Claude 3.5 Sonnet'},
          ],
        }),
      );
      final catalog = LlmModelCatalogImpl(dio: _dioWith(adapter));

      final models = await catalog.listModels(
        const LlmModelQuery(providerType: 'anthropic', apiKey: 'sk-ant'),
      );

      expect(models.single.id, 'claude-3-5-sonnet');
      expect(models.single.name, 'Claude 3.5 Sonnet');
      expect(
        adapter.request!.uri.toString(),
        'https://api.anthropic.com/v1/models',
      );
      expect(adapter.request!.headers['x-api-key'], 'sk-ant');
      expect(adapter.request!.headers['anthropic-version'], '2023-06-01');
    });

    test(
      'Gemini: strips models/ prefix and passes key as a query param',
      () async {
        final adapter = _JsonReplayAdapter(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-1.5-pro',
                'displayName': 'Gemini 1.5 Pro',
              },
            ],
          }),
        );
        final catalog = LlmModelCatalogImpl(dio: _dioWith(adapter));

        final models = await catalog.listModels(
          const LlmModelQuery(providerType: 'gemini', apiKey: 'g-key'),
        );

        expect(models.single.id, 'gemini-1.5-pro');
        expect(models.single.name, 'Gemini 1.5 Pro');
        expect(models.single.ownedBy, 'google');
        expect(adapter.request!.uri.path, contains('/v1beta/models'));
        expect(adapter.request!.uri.queryParameters['key'], 'g-key');
      },
    );

    test('maps a non-2xx response onto a NetworkFailure', () async {
      final catalog = LlmModelCatalogImpl(
        dio: _dioWith(
          _JsonReplayAdapter(jsonEncode({'error': 'nope'}), statusCode: 401),
        ),
      );

      expect(
        () => catalog.listModels(const LlmModelQuery(providerType: 'openai')),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
