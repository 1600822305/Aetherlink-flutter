import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedder.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_url_fetcher.dart';
import 'package:aetherlink_flutter/features/memory/data/embedding_service.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/fetch_tool.dart';

part 'knowledge_access.g.dart';

/// App-level composition seam exposing [KnowledgeService].
///
/// Mirrors `memory_access.dart`: the import-boundary rule forbids the knowledge
/// feature from importing chat's `application`, but the single app-wide Drift
/// handle lives behind chat's `appDatabaseProvider`. So the service is composed
/// here in `app/` (the composition root) and the feature reaches it through
/// this seam. The embedder resolver is likewise composed here — the knowledge
/// core only holds the [KnowledgeEmbedderResolver] function, keeping it testable.
@Riverpod(keepAlive: true)
KnowledgeService knowledgeService(Ref ref) => KnowledgeService(
  ref.watch(appDatabaseProvider).knowledgeDao,
  embedderResolver: (embeddingModelKey) =>
      _resolveKnowledgeEmbedder(ref, embeddingModelKey),
  urlFetcher: (url) => _fetchKnowledgeUrl(ref, url),
);

/// 默认 URL 抓取器（设计文档 §5「URL 抓取 → Markdown 快照」）：走应用统一的
/// LLM Dio（含代理配置），HTML 用与 `@aether/fetch` 同一套 [htmlToMarkdown] 转成
/// Markdown，其余内容按纯文本原样返回。标题取转换结果里的首个一级标题（HTML
/// `<title>` 会被 [htmlToMarkdown] 放在正文最前面的 `# ` 行），取不到则留空由
/// 调用方回落到 URL。抓取失败会抛异常，交由 [KnowledgeService.addUrl] 上抛。
Future<KnowledgeFetchedPage> _fetchKnowledgeUrl(Ref ref, String url) async {
  final dio = buildLlmDio(proxy: ref.read(appNetworkProxyConfigProvider));
  final response = await dio.get<String>(
    url,
    options: Options(
      responseType: ResponseType.plain,
      headers: const {
        'User-Agent': 'AetherLink/1.0 (Knowledge Fetch)',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    ),
  );
  final body = response.data ?? '';
  final contentType =
      (response.headers.value('content-type') ?? '').toLowerCase();
  final isHtml = contentType.contains('html') || body.trimLeft().startsWith('<');
  final markdown = isHtml ? htmlToMarkdown(body) : body;
  return KnowledgeFetchedPage(
    markdown: markdown,
    title: isHtml ? _firstMarkdownHeading(markdown) : null,
  );
}

/// 取 Markdown 最前面的一级标题（`# ` 行）作为条目标题；首个非空行不是标题则返回
/// null。[htmlToMarkdown] 会把页面 `<title>` 放到正文最前的 `# ` 行，故此处即页面标题。
String? _firstMarkdownHeading(String markdown) {
  for (final line in markdown.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('# ')) return trimmed.substring(2).trim();
    return null;
  }
  return null;
}

/// Resolves a base's `embeddingModelKey` to a ready [KnowledgeEmbedder], or null
/// when the key is unset/malformed or its provider/model no longer exists (→ the
/// service falls back to keyword search). Reuses memory's key codec + model
/// resolution so the two features address embedding models identically.
Future<KnowledgeEmbedder?> _resolveKnowledgeEmbedder(
  Ref ref,
  String? embeddingModelKey,
) async {
  if (embeddingModelKey == null || embeddingModelKey.isEmpty) return null;
  final providers = await ref.read(appModelProvidersProvider.future);
  final model = _resolveEmbeddingModel(providers, embeddingModelKey);
  if (model == null) return null;
  final service = EmbeddingService(
    buildLlmDio(proxy: ref.read(appNetworkProxyConfigProvider)),
  );
  return _EmbeddingServiceEmbedder(service, model);
}

/// Resolves a `providerId\0modelId` key to a fully-merged [Model] (endpoint +
/// credentials via `effectiveModelFor`), or null when unset/malformed or the
/// provider/model no longer exists.
Model? _resolveEmbeddingModel(List<ModelProvider> providers, String? key) {
  final pair = decodeEmbeddingModelKey(key);
  if (pair == null) return null;
  final (providerId, modelId) = pair;
  for (final provider in providers) {
    if (provider.id != providerId) continue;
    for (final model in provider.models) {
      if (model.id == modelId) {
        return effectiveModelFor(
          CurrentModel(provider: provider, model: model),
        );
      }
    }
  }
  return null;
}

/// Adapts the memory feature's protocol-only [EmbeddingService] (which needs a
/// resolved [Model] per call) to the knowledge core's [KnowledgeEmbedder].
class _EmbeddingServiceEmbedder implements KnowledgeEmbedder {
  _EmbeddingServiceEmbedder(this._service, this._model);

  final EmbeddingService _service;
  final Model _model;

  @override
  Future<List<List<double>>> embed(List<String> texts) =>
      _service.embedAll(_model, texts);
}
