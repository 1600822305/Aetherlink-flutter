/// 把文本转成嵌入向量供知识库使用（设计文档 §5 摄取 / §6 检索）。
///
/// 实现封装应用的 `EmbeddingService` + 模型解析，知识库核心不感知模型选择 / HTTP。
/// [embed] 返回与 [texts] 对齐的向量列表；某条无法嵌入时对应内层列表为空。摄取与
/// 检索都把嵌入当作 best-effort：抛错由调用方回退到关键词检索，绝不中断对话。
abstract class KnowledgeEmbedder {
  Future<List<List<double>>> embed(List<String> texts);
}

/// 把某库的 `embeddingModelKey` 解析为就绪的 [KnowledgeEmbedder]；无有效嵌入模型
/// （key 为空 / 解析不到模型）时返回 null，检索与摄取据此回退到关键词。
///
/// 由组合根（`app/di/knowledge_access.dart`）提供：读 `ref` → model providers →
/// 构造 `EmbeddingService`。知识库核心只持有这个函数指针，保持可测（测试传假实现）。
typedef KnowledgeEmbedderResolver =
    Future<KnowledgeEmbedder?> Function(String? embeddingModelKey);
