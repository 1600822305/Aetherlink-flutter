import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/utils/api_host.dart';

/// Calls an OpenAI-compatible `/embeddings` endpoint to turn text into vectors
/// for semantic memory retrieval. Protocol-only: it carries no memory logic and
/// no model selection — the caller resolves the embedding [Model] (endpoint +
/// credentials already merged from its provider via `effectiveModelFor`) and
/// passes it in.
///
/// Mirrors the auth / baseUrl handling of `openai_compatible_adapter.dart`:
/// `Authorization: Bearer <apiKey>` plus the model's extra headers, posting to
/// `<formatApiHost(baseUrl)>/embeddings`（裸 host 自动补 `/v1`，末尾 `#` 为
/// 精确地址逃生口，与 CS 的 `formatApiHost` 一致），无 baseUrl 时回落 OpenAI。
class EmbeddingService {
  EmbeddingService(this._dio);

  final Dio _dio;

  /// Embeds a single [text]; returns an empty list when the response carries no
  /// vector.
  Future<List<double>> embed(Model model, String text) async {
    final vectors = await embedAll(model, [text]);
    return vectors.isEmpty ? const <double>[] : vectors.first;
  }

  /// Embeds every entry of [texts] in one request, preserving order. Throws on
  /// transport / HTTP errors (the caller treats embedding as best-effort and
  /// falls back to keyword matching).
  Future<List<List<double>>> embedAll(Model model, List<String> texts) async {
    if (texts.isEmpty) return const <List<double>>[];
    final response = await _dio.post<Map<String, dynamic>>(
      _embeddingsUrl(model.baseUrl),
      data: <String, dynamic>{'model': model.id, 'input': texts},
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer ${model.apiKey ?? ''}',
          ...?model.providerExtraHeaders,
          ...?model.extraHeaders,
        },
      ),
    );
    final data = response.data?['data'];
    if (data is! List) return const <List<double>>[];
    final result = List<List<double>>.filled(texts.length, const <double>[]);
    for (final entry in data) {
      if (entry is! Map) continue;
      final index = entry['index'];
      final embedding = entry['embedding'];
      if (embedding is! List) continue;
      final vector = <double>[
        for (final value in embedding)
          if (value is num) value.toDouble(),
      ];
      if (index is int && index >= 0 && index < result.length) {
        result[index] = vector;
      }
    }
    return result;
  }

  static String _embeddingsUrl(String? baseUrl) {
    final base = formatApiHost(baseUrl);
    return '${base.isEmpty ? 'https://api.openai.com/v1' : base}/embeddings';
  }
}
