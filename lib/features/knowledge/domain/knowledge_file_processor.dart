import 'dart:typed_data';

/// 知识库级云端文件预处理器（设计文档 §5.2 云端预处理轨）。库配置了
/// [KnowledgeBase.fileProcessorId] 后，PDF / DOCX 上传改走所选云端服务
/// 转 Markdown 权威快照，再复用通用摄取管线；未配置则默认本地解析轨。
enum KnowledgeFileProcessor {
  mineru('mineru', 'MinerU', 'https://mineru.net'),
  doc2x('doc2x', 'Doc2X', 'https://v2.doc2x.noedgeai.com'),
  mistral('mistral', 'Mistral OCR', 'https://api.mistral.ai');

  const KnowledgeFileProcessor(this.id, this.label, this.defaultApiHost);

  /// 持久化到 `knowledge_base.fileProcessorId` 的稳定标识。
  final String id;
  final String label;
  final String defaultApiHost;

  /// 解析持久化 id；未配置 / 不认识（如降级旧版本）返回 null → 本地解析轨。
  static KnowledgeFileProcessor? fromId(String? id) {
    for (final p in KnowledgeFileProcessor.values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 把一个文件交给云端服务解析成 Markdown。具体实现（HTTP 上传 + 轮询 + 结果
/// 下载）由组合根注入，知识核心只持有这个函数，与 [KnowledgeUrlFetcher] 一样
/// 保持可测。失败（无 Key / 网络 / 服务端出错）抛异常交由调用方提示。
typedef KnowledgeFilePreprocessor = Future<String> Function({
  required KnowledgeFileProcessor processor,
  required String fileName,
  required Uint8List bytes,
});
