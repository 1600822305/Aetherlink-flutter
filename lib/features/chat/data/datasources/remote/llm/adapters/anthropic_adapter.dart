import 'dart:convert';

import 'package:aetherlink_flutter/core/error/network_error_mapper.dart';
import 'package:aetherlink_flutter/core/network/sse_decoder.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:dio/dio.dart';

/// Speaks the Anthropic Messages wire protocol: `POST /v1/messages` with
/// `stream: true` and an SSE body of named events (`message_start`,
/// `content_block_delta`, `message_delta`, …).
///
/// Anthropic puts the system prompt in a top-level `system` field (not a
/// message) and reports usage split across `message_start` (`input_tokens`) and
/// `message_delta` (`output_tokens`). Self-contained per ADR-0006: its own
/// auth headers, body and event parsing — no shared base class.
class AnthropicAdapter implements LlmGateway {
  const AnthropicAdapter(this._dio);

  final Dio _dio;

  @override
  Stream<LlmStreamChunk> streamChat(LlmChatRequest request) async* {
    final model = request.model;

    final messages = <Map<String, dynamic>>[
      for (final m in request.messages)
        if (m.role != MessageRole.system)
          {'role': _roleValue(m.role), 'content': m.content},
    ];

    final body = <String, dynamic>{
      'model': model.id,
      // Anthropic requires max_tokens; fall back to a sane default.
      'max_tokens': request.maxTokens ?? 4096,
      if (request.system != null) 'system': request.system,
      'messages': messages,
      'stream': request.stream,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.topP != null) 'top_p': request.topP,
      ...?request.extraBody,
    };

    final headers = <String, dynamic>{
      'x-api-key': model.apiKey ?? '',
      'anthropic-version': model.apiVersion ?? '2023-06-01',
      ...?model.extraHeaders,
      ...?request.extraHeaders,
    };

    final byteStream = await _openStream(
      _messagesUrl(model.baseUrl),
      headers: headers,
      body: body,
    );

    int? inputTokens;
    int? outputTokens;
    String? finishReason;

    await for (final event in decodeSse(byteStream)) {
      if (event.data.isEmpty) continue;
      final json = jsonDecode(event.data) as Map<String, dynamic>;

      switch (json['type'] as String?) {
        case 'message_start':
          final message = json['message'] as Map<String, dynamic>?;
          final u = message?['usage'] as Map<String, dynamic>?;
          inputTokens = (u?['input_tokens'] as num?)?.toInt();
        case 'content_block_delta':
          final delta = json['delta'] as Map<String, dynamic>?;
          switch (delta?['type'] as String?) {
            case 'text_delta':
              final text = delta?['text'];
              if (text is String && text.isNotEmpty) {
                yield LlmStreamChunk.textDelta(text);
              }
            case 'thinking_delta':
              final thinking = delta?['thinking'];
              if (thinking is String && thinking.isNotEmpty) {
                yield LlmStreamChunk.reasoningDelta(thinking);
              }
          }
        case 'message_delta':
          final delta = json['delta'] as Map<String, dynamic>?;
          final reason = delta?['stop_reason'];
          if (reason is String) finishReason = reason;
          final u = json['usage'] as Map<String, dynamic>?;
          final out = (u?['output_tokens'] as num?)?.toInt();
          if (out != null) outputTokens = out;
      }
    }

    final usage = (inputTokens != null || outputTokens != null)
        ? Usage(
            promptTokens: inputTokens ?? 0,
            completionTokens: outputTokens ?? 0,
            totalTokens: (inputTokens ?? 0) + (outputTokens ?? 0),
          )
        : null;
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
    MessageRole.assistant => 'assistant',
    _ => 'user',
  };

  static String _messagesUrl(String? baseUrl) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://api.anthropic.com'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/v1/messages';
  }
}
