import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/shared/domain/model.dart';

/// Calls a Jina/Cohere-compatible `/rerank` endpoint to score documents by
/// relevance to a query（功能缺口⑥，设计文档 §6）. Protocol-only：不含检索逻辑
/// 与模型选择——调用方解析好 rerank [Model]（endpoint + 凭据已经
/// `effectiveModelFor` 合并）再传入。
///
/// 认证 / baseUrl 处理与 `embedding_service.dart` 同款：`Authorization: Bearer
/// apiKey` + 模型附加请求头，POST 到 `baseUrl/rerank`。请求体
/// `{model, query, documents}`、响应 `results: [{index, relevance_score}]` 是
/// Jina / Cohere / 硅基流动 / 火山方舟等主流 rerank API 的公共子集。
class KnowledgeRerankService {
  KnowledgeRerankService(this._dio);

  final Dio _dio;

  /// 给 [documents] 逐条打相关性分（与入参对齐，越大越相关）。响应缺分数的
  /// 文档补 `double.negativeInfinity`（排到最后）；响应完全不含有效结果返回
  /// null。传输 / HTTP 错误上抛，由调用方按 best-effort 保持原排序。
  Future<List<double>?> rerank(
    Model model, {
    required String query,
    required List<String> documents,
  }) async {
    if (documents.isEmpty) return const <double>[];
    final response = await _dio.post<Map<String, dynamic>>(
      _rerankUrl(model.baseUrl),
      data: <String, dynamic>{
        'model': model.id,
        'query': query,
        'documents': documents,
      },
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer ${model.apiKey ?? ''}',
          ...?model.providerExtraHeaders,
          ...?model.extraHeaders,
        },
      ),
    );
    final results = response.data?['results'];
    if (results is! List) return null;
    final scores = List<double>.filled(
      documents.length,
      double.negativeInfinity,
    );
    var any = false;
    for (final entry in results) {
      if (entry is! Map) continue;
      final index = entry['index'];
      final score = entry['relevance_score'] ?? entry['score'];
      if (index is! int || index < 0 || index >= scores.length) continue;
      if (score is! num) continue;
      scores[index] = score.toDouble();
      any = true;
    }
    return any ? scores : null;
  }

  static String _rerankUrl(String? baseUrl) {
    final base = (baseUrl == null || baseUrl.isEmpty)
        ? 'https://api.jina.ai/v1'
        : baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/rerank';
  }
}
