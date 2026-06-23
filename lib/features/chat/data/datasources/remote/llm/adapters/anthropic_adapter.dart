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
        if (m.role != MessageRole.system) _toWireMessage(m),
    ];

    final tools = request.tools;
    // Anthropic extended thinking: when thinkingBudget is set and reasoning is
    // enabled, add the thinking block with budget_tokens.
    final hasThinking =
        request.thinkingBudget != null && request.thinkingBudget! > 0;

    final body = <String, dynamic>{
      'model': model.id,
      // Anthropic requires max_tokens; fall back to a sane default.
      'max_tokens': request.maxTokens ?? 4096,
      if (request.system != null)
        'system': request.cacheControl == true
            ? [
                {
                  'type': 'text',
                  'text': request.system,
                  'cache_control': {'type': 'ephemeral'},
                },
              ]
            : request.system,
      'messages': messages,
      'stream': request.stream,
      if (request.temperature != null && !hasThinking)
        'temperature': request.temperature,
      if (request.topP != null) 'top_p': request.topP,
      if (request.topK != null) 'top_k': request.topK,
      if (request.stopSequences != null && request.stopSequences!.isNotEmpty)
        'stop_sequences': request.stopSequences,

      if (request.user != null && request.user!.isNotEmpty)
        'metadata': {'user_id': request.user},
      if (hasThinking)
        'thinking': {
          'type': 'enabled',
          'budget_tokens': request.thinkingBudget,
        },
      if (request.webSearchEnabled == true ||
          request.codeExecutionEnabled == true ||
          (tools != null && tools.isNotEmpty))
        'tools': [
          if (request.webSearchEnabled == true)
            {
              'type': 'web_search_20250305',
              'name': 'web_search',
              'max_uses': 5,
            },
          if (request.codeExecutionEnabled == true)
            {'type': 'code_execution_20250825'},
          if (tools != null)
            for (final t in tools)
              {
                'name': t.name,
                'description': t.description,
                'input_schema': t.inputSchema,
              },
        ],
      ...?request.customParameters,
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
    // `tool_use` blocks stream as content_block_start (id + name) then a run of
    // `input_json_delta` fragments (partial JSON), keyed by the block `index`.
    final toolCalls = <int, _ToolCallBuilder>{};

    await for (final event in decodeSse(byteStream)) {
      if (event.data.isEmpty) continue;
      final json = jsonDecode(event.data) as Map<String, dynamic>;

      switch (json['type'] as String?) {
        case 'message_start':
          final message = json['message'] as Map<String, dynamic>?;
          final u = message?['usage'] as Map<String, dynamic>?;
          inputTokens = (u?['input_tokens'] as num?)?.toInt();
        case 'content_block_start':
          final block = json['content_block'] as Map<String, dynamic>?;
          if (block?['type'] == 'tool_use') {
            final index = (json['index'] as num?)?.toInt() ?? 0;
            final builder = toolCalls.putIfAbsent(index, _ToolCallBuilder.new);
            final id = block?['id'];
            if (id is String) builder.id = id;
            final name = block?['name'];
            if (name is String) builder.name = name;
          }
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
            case 'input_json_delta':
              final partial = delta?['partial_json'];
              if (partial is String) {
                final index = (json['index'] as num?)?.toInt() ?? 0;
                toolCalls
                    .putIfAbsent(index, _ToolCallBuilder.new)
                    .arguments
                    .write(partial);
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

  /// Translates an [LlmMessage] into an Anthropic wire message. Tool round-trip
  /// turns use block content: an assistant turn carrying [LlmMessage.toolCalls]
  /// becomes optional `text` + `tool_use` blocks (with the arguments string
  /// decoded back to the `input` object); a tool-result turn
  /// ([LlmMessage.toolCallId] set) becomes a `user` message holding a
  /// `tool_result` block linked by `tool_use_id`. Plain turns stay a string.
  static Map<String, dynamic> _toWireMessage(LlmMessage m) {
    final toolCallId = m.toolCallId;
    if (toolCallId != null) {
      return {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': toolCallId,
            'content': m.content,
          },
        ],
      };
    }
    final calls = m.toolCalls;
    if (calls != null && calls.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': [
          if (m.content.isNotEmpty) {'type': 'text', 'text': m.content},
          for (final c in calls)
            {
              'type': 'tool_use',
              'id': c.id,
              'name': c.name,
              'input': _decodeArguments(c.arguments),
            },
        ],
      };
    }
    final images = m.images;
    if (images != null && images.isNotEmpty) {
      return {
        'role': _roleValue(m.role),
        'content': [
          if (m.content.isNotEmpty) {'type': 'text', 'text': m.content},
          for (final image in images)
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': image.mimeType,
                'data': image.base64Data,
              },
            },
        ],
      };
    }
    return {'role': _roleValue(m.role), 'content': m.content};
  }

  /// Decodes a tool-call arguments string into the object Anthropic's `input`
  /// expects, tolerating an empty/blank string (→ `{}`) or non-object JSON.
  static Map<String, dynamic> _decodeArguments(String arguments) {
    if (arguments.trim().isEmpty) return const {};
    final decoded = jsonDecode(arguments);
    return decoded is Map<String, dynamic> ? decoded : const {};
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

/// Mutable scratch for merging a single streamed Anthropic `tool_use` block
/// across events (id + name from content_block_start, arguments from the run of
/// `input_json_delta` fragments).
class _ToolCallBuilder {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}
