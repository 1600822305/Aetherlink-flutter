import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

part 'knowledge_providers.g.dart';

/// Loads and mutates the knowledge-base list (轨道 A / UI 的建库入口)。
@riverpod
class KnowledgeBasesController extends _$KnowledgeBasesController {
  @override
  Future<List<KnowledgeBase>> build() =>
      ref.watch(knowledgeServiceProvider).listBases();

  Future<void> createBase(
    String name, {
    String? embeddingModelKey,
    KnowledgeSearchMode searchMode = KnowledgeSearchMode.keyword,
    KnowledgeScope scope = const KnowledgeScope(),
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await ref.read(knowledgeServiceProvider).createBase(
          name: trimmed,
          embeddingModelKey: embeddingModelKey,
          searchMode: searchMode,
          scope: scope,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteBase(String id) async {
    await ref.read(knowledgeServiceProvider).deleteBase(id);
    ref.invalidateSelf();
    await future;
  }
}

/// Loads and mutates the items inside one knowledge base.
@riverpod
class KnowledgeItemsController extends _$KnowledgeItemsController {
  @override
  Future<List<KnowledgeItem>> build(String baseId) =>
      ref.watch(knowledgeServiceProvider).listItems(baseId);

  Future<void> addNote({required String title, required String text}) async {
    if (text.trim().isEmpty) return;
    await ref
        .read(knowledgeServiceProvider)
        .addNote(baseId: baseId, title: title, text: text);
    ref.invalidateSelf();
    await future;
    // Base status flips to completed on first item — refresh the base list too.
    ref.invalidate(knowledgeBasesControllerProvider);
  }

  /// 摄取一个纯文本文件（txt / md）。调用方已把文件读成 UTF-8 文本。
  Future<void> addFile({
    required String fileName,
    required String text,
    String? sourcePath,
  }) async {
    if (text.trim().isEmpty) return;
    await ref.read(knowledgeServiceProvider).addFile(
          baseId: baseId,
          fileName: fileName,
          text: text,
          sourcePath: sourcePath,
        );
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
  }

  /// 抓取一个网页并摄取为条目（type=url）。抓取 + HTML→Markdown 由服务层注入的
  /// 抓取器完成；失败会抛异常交由 UI 提示。
  Future<void> addUrl({required String url, String? title}) async {
    if (url.trim().isEmpty) return;
    await ref.read(knowledgeServiceProvider).addUrl(
          baseId: baseId,
          url: url,
          title: title,
        );
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
  }

  /// 从已存正文原子重建整库派生索引（切块 + 向量），返回重建覆盖的条目数。
  Future<int> refresh() async {
    final count = await ref.read(knowledgeServiceProvider).reindexBase(baseId);
    ref.invalidateSelf();
    await future;
    return count;
  }
}
