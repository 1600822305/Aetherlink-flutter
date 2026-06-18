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
      for (final m in request.messages) _toWireMessage(m),
    ];

    final tools = request.tools;
    final body = <String, dynamic>{
      'model': model.id,
      'messages': messages,
      'stream': request.stream,
      'stream_options': {'include_usage': true},
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      if (request.topP != null) 'top_p': request.topP,
      if (tools != null && tools.isNotEmpty)
        'tools': [
          for (final t in tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.inputSchema,
              },
            },
        ],
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
    // Streaming `tool_calls` arrive split across deltas keyed by `index`; merge
    // each call's id/name (sent once) and arguments (concatenated char-by-char)
    // before emitting one event per call after the stream ends.
    final toolCalls = <int, _ToolCallBuilder>{};

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
          final calls = delta['tool_calls'];
          if (calls is List) _accumulateToolCalls(toolCalls, calls);
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

    for (final index in toolCalls.keys.toList()..sort()) {
      final call = toolCalls[index]!;
      if (call.name.isEmpty) continue;
      yield LlmStreamChunk.toolCall(
        LlmToolCall(
          id: call.id,
          name: call.name,
          arguments: call.arguments.toString(),
        ),
      );
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

  /// Translates an [LlmMessage] into an OpenAI wire message. A tool-result turn
  /// ([LlmMessage.toolCallId] set) becomes `role:'tool'` linked by
  /// `tool_call_id`; an assistant turn carrying [LlmMessage.toolCalls] replays
  /// them as a `tool_calls` array (with `content` null when the model emitted
  /// no text); everything else is a plain chat message.
  static Map<String, dynamic> _toWireMessage(LlmMessage m) {
    final toolCallId = m.toolCallId;
    if (toolCallId != null) {
      return {'role': 'tool', 'tool_call_id': toolCallId, 'content': m.content};
    }
    final calls = m.toolCalls;
    if (calls != null && calls.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': m.content.isEmpty ? null : m.content,
        'tool_calls': [
          for (final c in calls)
            {
              'id': c.id,
              'type': 'function',
              'function': {'name': c.name, 'arguments': c.arguments},
            },
        ],
      };
    }
    return {'role': _roleValue(m.role), 'content': m.content};
  }

  /// Merges one delta's `tool_calls` fragments into [acc] by their `index`.
  static void _accumulateToolCalls(
    Map<int, _ToolCallBuilder> acc,
    List<dynamic> calls,
  ) {
    for (final raw in calls) {
      if (raw is! Map<String, dynamic>) continue;
      final index = (raw['index'] as num?)?.toInt() ?? 0;
      final builder = acc.putIfAbsent(index, _ToolCallBuilder.new);
      final id = raw['id'];
      if (id is String && id.isNotEmpty) builder.id = id;
      final fn = raw['function'];
      if (fn is Map<String, dynamic>) {
        final name = fn['name'];
        if (name is String && name.isNotEmpty) builder.name = name;
        final args = fn['arguments'];
        if (args is String) builder.arguments.write(args);
      }
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

/// Mutable scratch for merging a single streamed OpenAI `tool_calls[index]`
/// across deltas (id + name sent once, arguments concatenated).
class _ToolCallBuilder {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}
