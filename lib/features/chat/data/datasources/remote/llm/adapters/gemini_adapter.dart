import 'dart:convert';

import 'package:aetherlink_flutter/core/error/network_error_mapper.dart';
import 'package:aetherlink_flutter/core/network/sse_decoder.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:dio/dio.dart';

/// Speaks the Gemini wire protocol: `POST
/// /v1beta/models/{model}:streamGenerateContent?alt=sse`, an SSE body of
/// `data: {json}` chunks (no `[DONE]` sentinel — the stream simply ends).
///
/// Gemini uses `contents` with `role: user|model`, carries the system prompt in
/// `systemInstruction`, and marks reasoning parts with `thought: true`. Usage
/// arrives in `usageMetadata`. Self-contained per ADR-0006.
class GeminiAdapter implements LlmGateway {
  const GeminiAdapter(this._dio);

  final Dio _dio;

  @override
  Stream<LlmStreamChunk> streamChat(LlmChatRequest request) async* {
    final model = request.model;

    final contents = <Map<String, dynamic>>[
      for (final m in request.messages)
        if (m.role != MessageRole.system) _toWireContent(m),
    ];

    final tools = request.tools;
    final body = <String, dynamic>{
      'contents': contents,
      if (request.system != null)
        'systemInstruction': {
          'parts': [
            {'text': request.system},
          ],
        },
      'generationConfig': <String, dynamic>{
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.maxTokens != null) 'maxOutputTokens': request.maxTokens,
        if (request.topP != null) 'topP': request.topP,
      },
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final t in tools)
                {
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.inputSchema,
                },
            ],
          },
        ],
      ...?request.extraBody,
    };

    final headers = <String, dynamic>{
      'x-goog-api-key': model.apiKey ?? '',
      ...?model.extraHeaders,
      ...?request.extraHeaders,
    };

    final byteStream = await _openStream(
      _streamUrl(model.baseUrl, model.id),
      headers: headers,
      body: body,
    );

    Usage? usage;
    String? finishReason;

    await for (final event in decodeSse(byteStream)) {
      if (event.data.isEmpty) continue;
      final json = jsonDecode(event.data) as Map<String, dynamic>;

      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final candidate = candidates.first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null) {
          for (final raw in parts) {
            final part = raw as Map<String, dynamic>;
            // Gemini emits a function call as a complete object in one part
            // (never streamed incrementally) and issues no call id, so results
            // are matched back by name.
            final fn = part['functionCall'];
            if (fn is Map<String, dynamic>) {
              final name = fn['name'];
              if (name is String && name.isNotEmpty) {
                final args = fn['args'];
                yield LlmStreamChunk.toolCall(
                  LlmToolCall(
                    id: '',
                    name: name,
                    arguments: jsonEncode(args ?? const <String, dynamic>{}),
                  ),
                );
              }
              continue;
            }
            final text = part['text'];
            if (text is! String || text.isEmpty) continue;
            if (part['thought'] == true) {
              yield LlmStreamChunk.reasoningDelta(text);
            } else {
              yield LlmStreamChunk.textDelta(text);
            }
          }
        }
        final reason = candidate['finishReason'];
        if (reason is String) finishReason = reason;
      }

      final u = json['usageMetadata'] as Map<String, dynamic>?;
      if (u != null) {
        usage = Usage(
          promptTokens: (u['promptTokenCount'] as num?)?.toInt() ?? 0,
          completionTokens: (u['candidatesTokenCount'] as num?)?.toInt() ?? 0,
          totalTokens: (u['totalTokenCount'] as num?)?.toInt() ?? 0,
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

  /// Translates an [LlmMessage] into a Gemini `contents` entry. Tool round-trip
  /// turns map onto Gemini's part shapes: an assistant turn carrying
  /// [LlmMessage.toolCalls] becomes `functionCall` parts (arguments string
  /// decoded back to the `args` object); a tool-result turn
  /// ([LlmMessage.toolCallId] set) becomes a `user` turn with a
  /// `functionResponse` part keyed by [LlmMessage.toolName]. Plain turns carry
  /// a single `text` part.
  static Map<String, dynamic> _toWireContent(LlmMessage m) {
    if (m.toolCallId != null) {
      return {
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': m.toolName ?? '',
              'response': {'result': m.content},
            },
          },
        ],
      };
    }
    final calls = m.toolCalls;
    if (calls != null && calls.isNotEmpty) {
      return {
        'role': 'model',
        'parts': [
          if (m.content.isNotEmpty) {'text': m.content},
          for (final c in calls)
            {
              'functionCall': {
                'name': c.name,
                'args': _decodeArguments(c.arguments),
              },
            },
        ],
      };
    }
    return {
      'role': _roleValue(m.role),
      'parts': [
        {'text': m.content},
      ],
    };
  }

  /// Decodes a tool-call arguments string into the object Gemini's `args`
  /// expects, tolerating an empty/blank string (→ `{}`) or non-object JSON.
  static Map<String, dynamic> _decodeArguments(String arguments) {
    if (arguments.trim().isEmpty) return const {};
    final decoded = jsonDecode(arguments);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  static String _roleValue(MessageRole role) => switch (role) {
    MessageRole.assistant => 'model',
    _ => 'user',
  };

  static String _streamUrl(String? baseUrl, String modelId) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://generativelanguage.googleapis.com/v1beta'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/models/$modelId:streamGenerateContent?alt=sse';
  }
}
