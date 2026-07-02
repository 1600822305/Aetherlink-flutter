import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_file_preprocessing.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedder.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_url_fetcher.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_workspace_source.dart';
import 'package:aetherlink_flutter/features/memory/data/embedding_service.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
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
  workspaceSource: _WorkspaceBackendSource(ref),
  filePreprocessor: ({
    required processor,
    required fileName,
    required bytes,
  }) async {
    final apiKey = await ref
        .read(appDatabaseProvider)
        .appSettingDao
        .getValue(knowledgeFileProcessorApiKeySetting(processor));
    final key = apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('未配置 ${processor.label} 的 API Key，请先在云端解析设置里填写');
    }
    return preprocessFileInCloud(
      dio: buildLlmDio(proxy: ref.read(appNetworkProxyConfigProvider)),
      processor: processor,
      apiKey: key,
      fileName: fileName,
      bytes: bytes,
    );
  },
);

/// 云端解析器 API Key 在 app 设置表里的键（app 级、按服务存一份，§5.2）。
String knowledgeFileProcessorApiKeySetting(KnowledgeFileProcessor processor) =>
    'knowledge.file_processor.${processor.id}.api_key';

/// 读一个云端解析器已保存的 API Key（供设置 UI 回显）。
Future<String?> readKnowledgeFileProcessorApiKey(
  WidgetRef ref,
  KnowledgeFileProcessor processor,
) =>
    ref
        .read(appDatabaseProvider)
        .appSettingDao
        .getValue(knowledgeFileProcessorApiKeySetting(processor));

/// 保存一个云端解析器的 API Key。
Future<void> saveKnowledgeFileProcessorApiKey(
  WidgetRef ref,
  KnowledgeFileProcessor processor,
  String apiKey,
) =>
    ref
        .read(appDatabaseProvider)
        .appSettingDao
        .setValue(knowledgeFileProcessorApiKeySetting(processor), apiKey);

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

/// 组合根里的工作区源实现（设计文档 §8 workspace 目录源）：把知识核心持有的
/// [KnowledgeWorkspaceSource] 落到 workspace 特性的 [WorkspaceBackend] 上——按 id 从
/// [WorkspaceStore] 找回工作区、经 [workspaceBackendProvider] 拿后端，递归遍历目录读
/// 文本。知识核心因此不必导入 workspace 特性，导入边界保持在这一个组合根文件。
class _WorkspaceBackendSource implements KnowledgeWorkspaceSource {
  _WorkspaceBackendSource(this._ref);

  final Ref _ref;

  /// 单文件读取上限：超出的（多为大二进制 / 生成物）跳过，避免撑爆内存与切块。
  static const int _maxFileBytes = 2 * 1024 * 1024;

  /// 单次摄取的文件数上限：目录极大时截断，防止一次性摄取失控。
  static const int _maxFiles = 2000;

  /// 目录遍历深度上限：防御环形 / 超深目录。
  static const int _maxDepth = 24;

  /// 可摄取的文本 / 代码扩展名（小写，不含点）。其余（图片 / 压缩包 / 可执行文件等）
  /// 一律跳过——workspace 源只摄取纯文本，富文档转换是后续 P3e 的事。
  static const Set<String> _textExtensions = {
    'txt', 'text', 'md', 'markdown', 'rst', 'org',
    'json', 'jsonc', 'yaml', 'yml', 'toml', 'ini', 'cfg', 'conf', 'properties',
    'xml', 'html', 'htm', 'csv', 'tsv', 'log',
    'dart', 'js', 'jsx', 'ts', 'tsx', 'py', 'java', 'kt', 'kts', 'swift',
    'c', 'h', 'cc', 'cpp', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'scala',
    'sh', 'bash', 'zsh', 'sql', 'gradle', 'pro', 'cmake', 'make', 'mk',
    'gitignore', 'env', 'lock', 'gql', 'graphql', 'proto', 'vue', 'svelte',
  };

  Future<(Workspace, WorkspaceBackend)> _resolve(String workspaceId) async {
    final workspaces = await _ref.read(workspaceStoreProvider.future);
    Workspace? workspace;
    for (final w in workspaces) {
      if (w.id == workspaceId) {
        workspace = w;
        break;
      }
    }
    if (workspace == null) {
      throw StateError('工作区不存在: $workspaceId');
    }
    final backend = _ref.read(workspaceBackendProvider(workspace));
    return (workspace, backend);
  }

  static bool _isTextFile(String name) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    // 无扩展名的隐藏配置（如 .gitignore）会被 lastIndexOf 取到「gitignore」，仍能命中。
    final ext = dot <= 0 ? lower.replaceFirst('.', '') : lower.substring(dot + 1);
    return _textExtensions.contains(ext);
  }

  @override
  Future<List<KnowledgeWorkspaceFile>> listTextFiles(String workspaceId) async {
    final (workspace, backend) = await _resolve(workspaceId);
    final files = <KnowledgeWorkspaceFile>[];
    // BFS 遍历：从根目录逐层展开，跳过隐藏项、超限文件与非文本扩展名。
    final queue = <(String, int)>[(workspace.root, 0)];
    while (queue.isNotEmpty && files.length < _maxFiles) {
      final (dir, depth) = queue.removeAt(0);
      if (depth > _maxDepth) continue;
      final List<WorkspaceEntry> entries;
      try {
        entries = await backend.listDir(dir);
      } catch (_) {
        // 单个子目录读失败（授权 / 权限）不应中断整次遍历。
        continue;
      }
      for (final entry in entries) {
        if (entry.isHidden) continue;
        if (entry.isDirectory) {
          queue.add((entry.path, depth + 1));
          continue;
        }
        if (!_isTextFile(entry.name)) continue;
        if (entry.size > _maxFileBytes) continue;
        String text;
        try {
          text = await backend.readFile(entry.path);
        } catch (_) {
          continue;
        }
        if (text.trim().isEmpty) continue;
        files.add(
          KnowledgeWorkspaceFile(
            path: entry.path,
            name: entry.name,
            text: text,
            mtime: entry.mtime,
            size: entry.size,
          ),
        );
        if (files.length >= _maxFiles) break;
      }
    }
    return files;
  }

  @override
  Future<KnowledgeWorkspaceStat?> statFile(
    String workspaceId,
    String path,
  ) async {
    try {
      final (_, backend) = await _resolve(workspaceId);
      final info = await backend.getFileInfo(path);
      return KnowledgeWorkspaceStat(mtime: info.mtime, size: info.size);
    } catch (_) {
      // 文件失联 / 授权失效 / 后端不支持 → 交由调用方按「可能已过期」处理。
      return null;
    }
  }
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
