import 'package:aetherlink_flutter/core/error/network_error_mapper.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/llm_protocol.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
import 'package:dio/dio.dart';

/// The single entry point for the `自动获取模型` feature: lists a provider's
/// models by hitting its catalog endpoint. Selects the wire by protocol
/// ([protocolForProviderKey]); a sibling of `LlmProviderFactory` for the
/// streaming path. Shares one [Dio] (mechanical plumbing); tests inject a [Dio]
/// whose [Dio.httpClientAdapter] replays recorded JSON.
class LlmModelCatalogImpl implements LlmModelCatalog {
  LlmModelCatalogImpl({Dio? dio, NetworkProxyConfig? proxy})
    : _dio = dio ?? buildLlmDio(proxy: proxy);

  final Dio _dio;

  @override
  Future<List<LlmModelInfo>> listModels(LlmModelQuery query) {
    return switch (protocolForProviderKey(query.providerType)) {
      LlmProtocol.openaiCompatible => _openaiCompatible(query),
      LlmProtocol.anthropic => _anthropic(query),
      LlmProtocol.gemini => _gemini(query),
    };
  }

  Future<List<LlmModelInfo>> _openaiCompatible(LlmModelQuery query) async {
    final data = await _get(
      _openaiModelsUrl(query.baseUrl),
      headers: {
        'Authorization': 'Bearer ${query.apiKey ?? ''}',
        'Accept': 'application/json',
        ...?query.extraHeaders,
      },
    );
    return _parseList(
      data,
    ).map(_normalize).whereType<LlmModelInfo>().toList(growable: false);
  }

  Future<List<LlmModelInfo>> _anthropic(LlmModelQuery query) async {
    final data = await _get(
      _anthropicModelsUrl(query.baseUrl),
      headers: {
        'x-api-key': query.apiKey ?? '',
        'anthropic-version': '2023-06-01',
        'Accept': 'application/json',
        ...?query.extraHeaders,
      },
    );
    return _parseList(
      data,
    ).map(_normalize).whereType<LlmModelInfo>().toList(growable: false);
  }

  Future<List<LlmModelInfo>> _gemini(LlmModelQuery query) async {
    final data = await _get(
      _geminiModelsUrl(query.baseUrl, query.apiKey),
      headers: {'Accept': 'application/json', ...?query.extraHeaders},
    );
    return _parseList(
      data,
    ).map(_normalizeGemini).whereType<LlmModelInfo>().toList(growable: false);
  }

  Future<dynamic> _get(
    String url, {
    required Map<String, dynamic> headers,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        url,
        options: Options(headers: headers, responseType: ResponseType.json),
      );
      return response.data;
    } on DioException catch (e) {
      throw networkFailureFromDio(e);
    }
  }

  /// Pulls the model array out of the many shapes vendors / proxies return
  /// (`{data: []}`, a bare array, `{models: []}`, `{result|results|items|list:
  /// []}`), mirroring the original app's tolerant parser.
  static List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'models',
        'result',
        'results',
        'items',
        'list',
      ]) {
        final value = data[key];
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
        // Nested one level, e.g. {data: {models: [...]}}.
        if (value is Map<String, dynamic>) {
          for (final nestedKey in const ['models', 'data']) {
            final nested = value[nestedKey];
            if (nested is List) {
              return nested.whereType<Map<String, dynamic>>().toList();
            }
          }
        }
      }
    }
    return const [];
  }

  static LlmModelInfo? _normalize(Map<String, dynamic> raw) {
    final id = (raw['id'] ?? raw['model'] ?? raw['name'] ?? '')
        .toString()
        .trim();
    if (id.isEmpty) return null;
    final name = (raw['name'] ?? raw['display_name'])?.toString();
    return LlmModelInfo(
      id: id,
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      ownedBy: (raw['owned_by'] ?? raw['owner'])?.toString(),
      description: raw['description']?.toString(),
    );
  }

  /// Gemini reports `name: "models/gemini-1.5-pro"`; strip the prefix for the id
  /// and prefer `displayName` for the label.
  static LlmModelInfo? _normalizeGemini(Map<String, dynamic> raw) {
    final rawName = (raw['name'] ?? raw['id'] ?? '').toString().trim();
    if (rawName.isEmpty) return null;
    final id = rawName.startsWith('models/')
        ? rawName.substring('models/'.length)
        : rawName;
    final display = (raw['displayName'] ?? raw['display_name'])?.toString();
    return LlmModelInfo(
      id: id,
      name: (display != null && display.trim().isNotEmpty)
          ? display.trim()
          : null,
      ownedBy: 'google',
      description: raw['description']?.toString(),
    );
  }

  static String _openaiModelsUrl(String? baseUrl) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://api.openai.com/v1'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return base.contains('/v1') ? '$base/models' : '$base/v1/models';
  }

  static String _anthropicModelsUrl(String? baseUrl) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://api.anthropic.com'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return base.contains('/v1') ? '$base/models' : '$base/v1/models';
  }

  static String _geminiModelsUrl(String? baseUrl, String? apiKey) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://generativelanguage.googleapis.com/v1beta'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/models?key=${apiKey ?? ''}';
  }
}
