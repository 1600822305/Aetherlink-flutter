import 'dart:convert';

import 'package:aetherlink_flutter/core/error/network_error_mapper.dart';
import 'package:aetherlink_flutter/core/network/sse_decoder.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:dio/dio.dart';

/// Speaks the OpenAI Chat Completions wire protocol: `POST /chat/completions`
/// with `stream: true`, an SSE body of `data: {json}` chunks terminated by
/// `data: [DONE]`.
///
/// One adapter serves every OpenAI-compatible vendor (OpenAI, DashScope, Grok,
/// DeepSeek, Moonshot, OpenRouter, Ollama, …); they vary only by
/// [Model.baseUrl] / model id / params and ride on [LlmChatRequest.extraBody]
/// — no per-vendor subclasses (ADR-0006). Self-contained: it builds its own
/// body, sets its own auth header and parses its own event schema.
class OpenAiCompatibleAdapter implements LlmGateway {
  const OpenAiCompatibleAdapter(this._dio);

  final Dio _dio;

  @override
  Stream<LlmStreamChunk> streamChat(LlmChatRequest request) async* {
    final model = request.model;

    final messages = <Map<String, dynamic>>[
      if (request.system != null) {'role': 'system', 'content': request.system},
      for (final m in request.messages)
        {'role': _roleValue(m.role), 'content': m.content},
    ];

    final body = <String, dynamic>{
      'model': model.id,
      'messages': messages,
      'stream': request.stream,
      'stream_options': {'include_usage': true},
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      if (request.topP != null) 'top_p': request.topP,
      ...?request.extraBody,
    };

    final headers = <String, dynamic>{
      'Authorization': 'Bearer ${model.apiKey ?? ''}',
      ...?model.extraHeaders,
      ...?request.extraHeaders,
    };

    final byteStream = await _openStream(
      _chatCompletionsUrl(model.baseUrl),
      headers: headers,
      body: body,
    );

    Usage? usage;
    String? finishReason;

    await for (final event in decodeSse(byteStream)) {
      final data = event.data;
      if (data.isEmpty) continue;
      if (data == '[DONE]') break;

      final json = jsonDecode(data) as Map<String, dynamic>;

      final choices = json['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final choice = choices.first as Map<String, dynamic>;
        final delta = choice['delta'] as Map<String, dynamic>?;
        if (delta != null) {
          final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
          if (reasoning is String && reasoning.isNotEmpty) {
            yield LlmStreamChunk.reasoningDelta(reasoning);
          }
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            yield LlmStreamChunk.textDelta(content);
          }
        }
        final reason = choice['finish_reason'];
        if (reason is String) finishReason = reason;
      }

      final u = json['usage'];
      if (u is Map<String, dynamic>) {
        usage = Usage(
          promptTokens: (u['prompt_tokens'] as num?)?.toInt() ?? 0,
          completionTokens: (u['completion_tokens'] as num?)?.toInt() ?? 0,
          totalTokens: (u['total_tokens'] as num?)?.toInt() ?? 0,
        );
      }
    }

    yield LlmStreamChunk.done(usage: usage, finishReason: finishReason);
  }

  Future<Stream<List<int>>> _openStream(
    String url, {
    required Map<String, dynamic> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(responseType: ResponseType.stream, headers: headers),
      );
      return response.data!.stream;
    } on DioException catch (e) {
      throw networkFailureFromDio(e);
    }
  }

  static String _roleValue(MessageRole role) => switch (role) {
    MessageRole.user => 'user',
    MessageRole.assistant => 'assistant',
    MessageRole.system => 'system',
  };

  static String _chatCompletionsUrl(String? baseUrl) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://api.openai.com/v1'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/chat/completions';
  }
}
