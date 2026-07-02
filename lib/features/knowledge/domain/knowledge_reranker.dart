/// 检索结果重排序器（功能缺口⑥，设计文档 §6）。
///
/// 实现封装应用的 rerank HTTP 调用 + 模型解析，知识库核心不感知模型选择 / 协议。
/// [rerank] 返回与 [documents] 对齐的相关性分数列表（越大越相关）；无法给出
/// 有效分数时返回 null。调用方把重排当作 best-effort：抛错 / 返 null 都保持
/// 原有排序，绝不中断检索。
abstract class KnowledgeReranker {
  Future<List<double>?> rerank({
    required String query,
    required List<String> documents,
  });
}

/// 把某库的 `rerankModelKey` 解析为就绪的 [KnowledgeReranker]；无有效重排模型
/// （key 为空 / 解析不到模型）时返回 null，检索保持原排序。
///
/// 由组合根（`app/di/knowledge_access.dart`）提供，与
/// `KnowledgeEmbedderResolver` 同款，知识库核心只持有函数指针保持可测。
typedef KnowledgeRerankerResolver =
    Future<KnowledgeReranker?> Function(String? rerankModelKey);
