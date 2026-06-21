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
/// When [LlmChatRequest.useResponsesAPI] is set it instead speaks OpenAI's
/// `/responses` protocol (typed `input` items + `response.*` stream events);
/// see [_streamResponses].
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
    if (request.useResponsesAPI) {
      yield* _streamResponses(request);
      return;
    }

    final model = request.model;

    final messages = <Map<String, dynamic>>[
      if (request.system != null) {'role': 'system', 'content': request.system},
      for (final m in request.messages) _toWireMessage(m),
    ];

    final tools = request.tools;
    final nativeSearchTools =
        request.extraBody?['_nativeSearchTools'] as List<dynamic>?;
    final extraBodyClean = request.extraBody != null
        ? (Map<String, dynamic>.of(request.extraBody!)
          ..remove('_nativeSearchTools'))
        : null;

    final toolsArray = <Map<String, dynamic>>[
      if (tools != null)
        for (final t in tools)
          {
            'type': 'function',
            'function': {
              'name': t.name,
              'description': t.description,
              'parameters': t.inputSchema,
            },
          },
      if (nativeSearchTools != null)
        for (final entry in nativeSearchTools)
          if (entry is Map<String, dynamic>) entry,
    ];

    final body = <String, dynamic>{
      'model': model.id,
      'messages': messages,
      'stream': request.stream,
      'stream_options': {'include_usage': true},
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      if (request.topP != null) 'top_p': request.topP,
      if (toolsArray.isNotEmpty) 'tools': toolsArray,
      ...?extraBodyClean,
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
          final content = _extractOpenAiTextDelta(delta);
          if (content.isNotEmpty) {
            yield LlmStreamChunk.textDelta(content);
          }
          final calls = delta['tool_calls'];
          if (calls is List) _accumulateToolCalls(toolCalls, calls);
        } else {
          // No `delta` in this chunk. Some compatible gateways instead send a
          // non-stream-shaped `message` object (or content parts), or a legacy
          // `text` field. Treat these as fallbacks so those responses do not
          // finalize as blank. Only used when `delta` is absent so a single
          // chunk never double-counts the same text / tool-call fragments.
          final message = choice['message'];
          if (message is Map<String, dynamic>) {
            final reasoning =
                message['reasoning_content'] ?? message['reasoning'];
            if (reasoning is String && reasoning.isNotEmpty) {
              yield LlmStreamChunk.reasoningDelta(reasoning);
            }
            final content = _extractTextContent(message['content']);
            if (content.isNotEmpty) yield LlmStreamChunk.textDelta(content);
            final calls = message['tool_calls'];
            if (calls is List) _accumulateToolCalls(toolCalls, calls);
          } else {
            final text = choice['text'];
            if (text is String && text.isNotEmpty) {
              yield LlmStreamChunk.textDelta(text);
            }
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

  /// Streams a chat turn over OpenAI's `/responses` endpoint.
  ///
  /// Differs from Chat Completions in three places: messages become typed
  /// `input` items (`_toResponsesInput`), the body uses `instructions` /
  /// `max_output_tokens` / flat function `tools`, and the SSE carries
  /// `response.*` event objects (`{type, ...}`) rather than `choices[].delta`.
  /// Text/reasoning deltas map straight through; `function_call` items are
  /// accumulated across `output_item.added` → `function_call_arguments.delta`
  /// → `output_item.done` and emitted once each, mirroring the
  /// Chat-Completions tool-call merge.
  Stream<LlmStreamChunk> _streamResponses(LlmChatRequest request) async* {
    final model = request.model;

    final input = <Map<String, dynamic>>[
      for (final m in request.messages) ..._toResponsesInput(m),
    ];

    final tools = request.tools;
    final hasTools = tools != null && tools.isNotEmpty;
    final nativeSearchToolsR =
        request.extraBody?['_nativeSearchTools'] as List<dynamic>?;
    final extraBodyCleanR = request.extraBody != null
        ? (Map<String, dynamic>.of(request.extraBody!)
          ..remove('_nativeSearchTools'))
        : null;

    final responsesToolsArray = <Map<String, dynamic>>[
      if (hasTools)
        for (final t in tools)
          {
            'type': 'function',
            'name': t.name,
            'description': t.description,
            'parameters': t.inputSchema,
          },
      if (nativeSearchToolsR != null)
        for (final entry in nativeSearchToolsR)
          if (entry is Map<String, dynamic>) entry,
    ];

    final system = request.system;
    final body = <String, dynamic>{
      'model': model.id,
      'input': input,
      'stream': request.stream,
      if (system != null && system.isNotEmpty) 'instructions': system,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.topP != null) 'top_p': request.topP,
      if (request.maxTokens != null) 'max_output_tokens': request.maxTokens,
      if (responsesToolsArray.isNotEmpty) ...{
        'tools': responsesToolsArray,
        'tool_choice': 'auto',
        'parallel_tool_calls': true,
      },
      ...?extraBodyCleanR,
    };

    final headers = <String, dynamic>{
      'Authorization': 'Bearer ${model.apiKey ?? ''}',
      ...?model.extraHeaders,
      ...?request.extraHeaders,
    };

    final byteStream = await _openStream(
      _responsesUrl(model.baseUrl),
      headers: headers,
      body: body,
    );

    Usage? usage;
    String? finishReason;
    var emittedText = false;
    // function_call items keyed by their `output_index` (one entry per parallel
    // call), accumulating call_id + name + arguments across the stream.
    final toolCalls = <String, _ToolCallBuilder>{};

    await for (final event in decodeSse(byteStream)) {
      final data = event.data;
      if (data.isEmpty) continue;
      if (data == '[DONE]') break;

      final json = jsonDecode(data) as Map<String, dynamic>;

      switch (json['type']) {
        case 'response.output_text.delta':
          final delta = json['delta'];
          if (delta is String && delta.isNotEmpty) {
            emittedText = true;
            yield LlmStreamChunk.textDelta(delta);
          }
        case 'response.reasoning.delta':
        case 'response.reasoning_text.delta':
        case 'response.reasoning_summary_text.delta':
          final delta = json['delta'];
          if (delta is String && delta.isNotEmpty) {
            yield LlmStreamChunk.reasoningDelta(delta);
          }
        case 'response.output_item.added':
          _responsesItemBoundary(toolCalls, json);
        case 'response.function_call_arguments.delta':
          final delta = json['delta'];
          if (delta is String) {
            toolCalls
                .putIfAbsent(_responsesItemKey(json), _ToolCallBuilder.new)
                .arguments
                .write(delta);
          }
        case 'response.function_call_arguments.done':
          final args = json['arguments'];
          if (args is String) {
            final builder = toolCalls.putIfAbsent(
              _responsesItemKey(json),
              _ToolCallBuilder.new,
            );
            builder.arguments
              ..clear()
              ..write(args);
          }
        case 'response.output_item.done':
          _responsesItemBoundary(toolCalls, json);
        case 'response.function_call.delta':
          _responsesInlineFunctionCall(toolCalls, json, replaceArgs: false);
        case 'response.function_call.done':
          _responsesInlineFunctionCall(toolCalls, json, replaceArgs: true);
        case 'response.completed':
          final response = json['response'];
          if (response is Map<String, dynamic>) {
            usage = _responsesUsage(response['usage']) ?? usage;
            if (!emittedText) {
              final content = _extractResponsesOutputText(response);
              if (content.isNotEmpty) {
                emittedText = true;
                yield LlmStreamChunk.textDelta(content);
              }
            }
          }
          finishReason ??= 'stop';
      }

      // Some gateways attach usage at the top level of any event.
      usage = _responsesUsage(json['usage']) ?? usage;
    }

    for (final key in toolCalls.keys.toList()..sort()) {
      final call = toolCalls[key]!;
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
    final images = m.images;
    if (images != null && images.isNotEmpty) {
      return {
        'role': _roleValue(m.role),
        'content': [
          if (m.content.isNotEmpty) {'type': 'text', 'text': m.content},
          for (final image in images)
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${image.mimeType};base64,${image.base64Data}',
              },
            },
        ],
      };
    }
    return {'role': _roleValue(m.role), 'content': m.content};
  }

  /// Translates an [LlmMessage] into one or more `/responses` `input` items.
  ///
  /// A tool-result turn ([LlmMessage.toolCallId] set) becomes a
  /// `function_call_output` item linked by `call_id`; an assistant turn
  /// carrying [LlmMessage.toolCalls] emits one typed `function_call` item per
  /// call (plus an `assistant` message when it also has text). Plain turns map
  /// to a role message — assistant as a string, user/system as an
  /// `input_text` content part (a stray system turn is folded to `user`, since
  /// the real system prompt rides in `instructions`).
  static List<Map<String, dynamic>> _toResponsesInput(LlmMessage m) {
    final toolCallId = m.toolCallId;
    if (toolCallId != null) {
      return [
        {
          'type': 'function_call_output',
          'call_id': toolCallId,
          'output': m.content,
        },
      ];
    }
    final calls = m.toolCalls;
    if (calls != null && calls.isNotEmpty) {
      return [
        if (m.content.isNotEmpty) {'role': 'assistant', 'content': m.content},
        for (final c in calls)
          {
            'type': 'function_call',
            'call_id': c.id,
            'name': c.name,
            'arguments': c.arguments,
          },
      ];
    }
    if (m.role == MessageRole.assistant) {
      return [
        {'role': 'assistant', 'content': m.content},
      ];
    }
    return [
      {
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': m.content},
          for (final image in m.images ?? const [])
            {
              'type': 'input_image',
              'image_url': 'data:${image.mimeType};base64,${image.base64Data}',
            },
        ],
      },
    ];
  }

  /// Stable per-call key for a `/responses` function-call event, preferring the
  /// `output_index` (shared by `output_item.*` and `function_call_arguments.*`)
  /// and falling back to the item id.
  static String _responsesItemKey(Map<String, dynamic> json) {
    final outputIndex = json['output_index'];
    if (outputIndex is num) return 'idx:${outputIndex.toInt()}';
    final item = json['item'];
    final itemId =
        json['item_id'] ?? (item is Map<String, dynamic> ? item['id'] : null);
    if (itemId is String && itemId.isNotEmpty) return 'item:$itemId';
    return 'idx:0';
  }

  /// Folds a `response.output_item.{added,done}` event into [acc] when its item
  /// is a `function_call` (capturing call_id / name / arguments).
  static void _responsesItemBoundary(
    Map<String, _ToolCallBuilder> acc,
    Map<String, dynamic> json,
  ) {
    final item = json['item'];
    if (item is! Map<String, dynamic> || item['type'] != 'function_call') {
      return;
    }
    final builder = acc.putIfAbsent(
      _responsesItemKey(json),
      _ToolCallBuilder.new,
    );
    final callId = item['call_id'] ?? item['id'];
    if (callId is String && callId.isNotEmpty) builder.id = callId;
    final name = item['name'];
    if (name is String && name.isNotEmpty) builder.name = name;
    final args = item['arguments'];
    if (args is String && args.isNotEmpty) {
      builder.arguments
        ..clear()
        ..write(args);
    }
  }

  /// Folds the non-standard `response.function_call.{delta,done}` variant (a
  /// bare `function_call` object) into [acc]. [replaceArgs] overwrites the
  /// accumulated arguments with the complete value carried by the `done` event.
  static void _responsesInlineFunctionCall(
    Map<String, _ToolCallBuilder> acc,
    Map<String, dynamic> json, {
    required bool replaceArgs,
  }) {
    final fc = json['function_call'];
    if (fc is! Map<String, dynamic>) return;
    final builder = acc.putIfAbsent(
      _responsesItemKey(json),
      _ToolCallBuilder.new,
    );
    final callId = fc['call_id'] ?? fc['id'];
    if (callId is String && callId.isNotEmpty) builder.id = callId;
    final name = fc['name'];
    if (name is String && name.isNotEmpty) builder.name = name;
    final args = fc['arguments'];
    if (args is String && args.isNotEmpty) {
      if (replaceArgs) builder.arguments.clear();
      builder.arguments.write(args);
    }
  }

  /// Parses a `/responses` usage block (`input_tokens` / `output_tokens` /
  /// `total_tokens`) into [Usage], or null if absent.
  static Usage? _responsesUsage(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return Usage(
      promptTokens: (raw['input_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (raw['output_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (raw['total_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// Extracts assistant text from the shapes returned by OpenAI-compatible
  /// stream deltas. Besides the common string value, a few vendors send
  /// content parts such as `{type:"text", text:"..."}`.
  static String _extractOpenAiTextDelta(Map<String, dynamic>? delta) {
    if (delta == null) return '';
    if (delta['type'] == 'response.audio.delta') return '';
    return _extractTextContent(delta['content']);
  }

  /// Extracts text from string content, content-part arrays, or a single
  /// content-part map. This intentionally ignores image/audio/tool parts.
  static String _extractTextContent(Object? raw) {
    if (raw is String) return raw;
    if (raw is List) {
      final buffer = StringBuffer();
      for (final item in raw) {
        final text = _extractTextContent(item);
        if (text.isNotEmpty) buffer.write(text);
      }
      return buffer.toString();
    }
    if (raw is Map) {
      final type = (raw['type'] ?? '').toString();
      if (!_isTextContentType(type)) return '';
      final text = raw['text'] ?? raw['delta'];
      if (text is String) return text;
      final content = raw['content'];
      if (content != null) return _extractTextContent(content);
    }
    return '';
  }

  static bool _isTextContentType(String type) =>
      type.isEmpty ||
      type == 'text' ||
      type == 'output_text' ||
      type == 'input_text';

  /// Extracts the final text from a `/responses` completion event. Some
  /// gateways only send the completed response object and never emit
  /// `response.output_text.delta`, so this is a last-resort fallback.
  static String _extractResponsesOutputText(Object? raw) {
    if (raw is List) {
      final buffer = StringBuffer();
      for (final item in raw) {
        final text = _extractResponsesOutputText(item);
        if (text.isNotEmpty) buffer.write(text);
      }
      return buffer.toString();
    }
    if (raw is! Map) return '';

    final outputText = raw['output_text'];
    if (outputText is String && outputText.isNotEmpty) return outputText;

    final type = (raw['type'] ?? '').toString();
    if (type == 'output_text') return _extractTextContent(raw);
    if (type == 'message' || type.isEmpty) {
      final content = _extractTextContent(raw['content']);
      if (content.isNotEmpty) return content;
    }

    return _extractResponsesOutputText(raw['output']);
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

  static String _responsesUrl(String? baseUrl) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://api.openai.com/v1'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/responses';
  }
}

/// Mutable scratch for merging a single streamed OpenAI `tool_calls[index]`
/// across deltas (id + name sent once, arguments concatenated).
class _ToolCallBuilder {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}
