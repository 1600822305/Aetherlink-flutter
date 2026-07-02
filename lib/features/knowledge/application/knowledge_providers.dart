import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_dao.dart'
    show KnowledgeStorageStats;
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart'
    show KnowledgeChunkPreview;
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
    await ref
        .read(knowledgeServiceProvider)
        .createBase(
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

  /// 设置某库的所属分组（功能缺口⑦）；传 null / 空白移出分组。
  Future<void> setBaseGroup(String id, String? groupName) async {
    await ref.read(knowledgeServiceProvider).setBaseGroup(id, groupName);
    ref.invalidateSelf();
    await future;
  }

  /// 重命名分组：组内所有库改挂到新名字。
  Future<void> renameGroup(String from, String to) async {
    await ref.read(knowledgeServiceProvider).renameGroup(from, to);
    ref.invalidateSelf();
    await future;
  }

  /// 解散分组：组内所有库移回未分组（库本身保留）。
  Future<void> dissolveGroup(String name) async {
    await ref.read(knowledgeServiceProvider).dissolveGroup(name);
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
    await ref
        .read(knowledgeServiceProvider)
        .addFile(
          baseId: baseId,
          fileName: fileName,
          text: text,
          sourcePath: sourcePath,
        );
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
  }

  /// 把一个富文档（PDF / DOCX）交给库配置的云端解析器转 Markdown 后摄取
  /// （§5.2 云端预处理轨）。失败抛异常交由 UI 提示。
  Future<void> addProcessedFile({
    required String fileName,
    required Uint8List bytes,
    String? sourcePath,
  }) async {
    await ref
        .read(knowledgeServiceProvider)
        .addProcessedFile(
          baseId: baseId,
          fileName: fileName,
          bytes: bytes,
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
    await ref
        .read(knowledgeServiceProvider)
        .addUrl(baseId: baseId, url: url, title: title);
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
  }

  /// 摄取一个工作区目录（type=workspace）：遍历目录下文本文件逐个建索引，并记录来源
  /// 指纹供 staleness 检测。遍历 + 读文件由服务层注入的工作区源完成；失败抛异常交由
  /// UI 提示。返回成功摄取的条目数。
  Future<int> addWorkspace({required String workspaceId}) async {
    if (workspaceId.trim().isEmpty) return 0;
    final items = await ref
        .read(knowledgeServiceProvider)
        .addWorkspace(baseId: baseId, workspaceId: workspaceId);
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
    return items.length;
  }

  /// 从已存正文原子重建整库派生索引（切块 + 向量），返回重建覆盖的条目数。
  Future<int> refresh() async {
    final count = await ref.read(knowledgeServiceProvider).reindexBase(baseId);
    ref.invalidateSelf();
    await future;
    return count;
  }

  /// 重建单个条目的派生索引（功能缺口⑪），返回重建出的切块数。
  Future<int> reindexItem(String itemId) async {
    final count = await ref
        .read(knowledgeServiceProvider)
        .reindexItem(itemId);
    ref.invalidate(knowledgeItemChunksProvider(itemId));
    ref.invalidate(knowledgePendingEmbeddingCountProvider(baseId));
    return count;
  }

  /// 把条目移入回收站（功能缺口⑩）：软删除，可从回收站恢复。
  Future<void> deleteItem(String itemId) async {
    await ref.read(knowledgeServiceProvider).trashItem(itemId);
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
    ref.invalidate(knowledgeTrashProvider(baseId));
  }

  /// 从回收站恢复条目（重建切块 + 嵌入）。
  Future<void> restoreItem(String itemId) async {
    await ref.read(knowledgeServiceProvider).restoreItem(itemId);
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeTrashProvider(baseId));
    ref.invalidate(knowledgePendingEmbeddingCountProvider(baseId));
  }

  /// 彻底删除回收站里的单个条目，不可恢复。
  Future<void> purgeItem(String itemId) async {
    await ref.read(knowledgeServiceProvider).deleteItem(itemId);
    ref.invalidate(knowledgeTrashProvider(baseId));
  }

  /// 清空回收站，返回清理的条目数。
  Future<int> emptyTrash() async {
    final count = await ref.read(knowledgeServiceProvider).emptyTrash(baseId);
    ref.invalidate(knowledgeTrashProvider(baseId));
    return count;
  }

  /// 只补嵌本库里嵌入失败/中断留下的待补切块（失败恢复，§11），已嵌入的不重算。
  /// 返回本次补嵌成功的切块数。
  Future<int> retryEmbeddings() async {
    final count = await ref
        .read(knowledgeServiceProvider)
        .retryPendingEmbeddings(baseId);
    ref.invalidate(knowledgePendingEmbeddingCountProvider(baseId));
    return count;
  }
}

/// 单个知识库的元数据（驱动详情页的云端解析配置入口，§5.2）。
@riverpod
class KnowledgeBaseController extends _$KnowledgeBaseController {
  @override
  Future<KnowledgeBase?> build(String baseId) =>
      ref.watch(knowledgeServiceProvider).getBase(baseId);

  /// 更新库级云端文件预处理器；传 null 回到本地解析轨。
  Future<void> setFileProcessor(String? processorId) async {
    await ref
        .read(knowledgeServiceProvider)
        .setFileProcessor(baseId, processorId);
    ref.invalidateSelf();
    await future;
  }

  /// 更新库的重排序模型（功能缺口⑥）；传 null 关闭重排。
  Future<void> setRerankModel(String? rerankModelKey) async {
    await ref
        .read(knowledgeServiceProvider)
        .updateBaseRerankModel(baseId, rerankModelKey);
    ref.invalidateSelf();
    await future;
  }

  /// 更新库的可编辑配置（名称 + RAG 参数）。名称同时显示在列表页，一并刷新。
  Future<void> updateConfig({
    required String name,
    required int chunkSize,
    required int chunkOverlap,
    required int topK,
    required double? threshold,
  }) async {
    await ref
        .read(knowledgeServiceProvider)
        .updateBaseConfig(
          baseId,
          name: name,
          chunkSize: chunkSize,
          chunkOverlap: chunkOverlap,
          topK: topK,
          threshold: threshold,
        );
    ref.invalidateSelf();
    await future;
    ref.invalidate(knowledgeBasesControllerProvider);
  }
}

/// 探测某嵌入模型的向量维度（功能缺口⑨）：真实调一次嵌入 API 取向量长度，
/// 无效模型 / 调用失败返 null。驱动建库面板的维度提示。
@riverpod
Future<int?> knowledgeEmbeddingDimensions(Ref ref, String modelKey) =>
    ref.watch(knowledgeServiceProvider).detectEmbeddingDimensions(modelKey);

/// 某库回收站里的条目（功能缺口⑩），按删除时间倒序。
@riverpod
Future<List<KnowledgeItem>> knowledgeTrash(Ref ref, String baseId) =>
    ref.watch(knowledgeServiceProvider).listTrash(baseId);

/// 某条目的全部切块（驱动条目切块详情面板）。
@riverpod
Future<List<KnowledgeChunkPreview>> knowledgeItemChunks(
  Ref ref,
  String itemId,
) => ref.watch(knowledgeServiceProvider).itemChunks(itemId);

/// 某库当前待补嵌入的切块数（驱动详情页的「重试嵌入」入口，关键词库恒为 0）。
@riverpod
Future<int> knowledgePendingEmbeddingCount(Ref ref, String baseId) =>
    ref.watch(knowledgeServiceProvider).pendingEmbeddingCount(baseId);

/// 知识库整体存储占用 + 软配额判定（§11.1，驱动列表页的占用提示）。
@riverpod
Future<({KnowledgeStorageStats stats, bool overSoftLimit})>
knowledgeStorageUsage(Ref ref) =>
    ref.watch(knowledgeServiceProvider).storageUsage();
