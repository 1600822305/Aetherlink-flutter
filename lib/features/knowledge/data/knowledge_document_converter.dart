import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:flutter/foundation.dart';

/// 富文档 → 纯文本的转换层（设计文档 §5.2 本地解析轨）：把 DOCX 等格式转成
/// Markdown 后再交给 `KnowledgeService.addFile` 走通用摄取管线。

/// 文件名（或路径）是否为 DOCX。
bool isDocxFileName(String name) => name.trim().toLowerCase().endsWith('.docx');

/// 在后台 isolate 中把 DOCX 字节转成 Markdown。
///
/// 无效包或解析失败抛 [DocxParseException]，内容为空（如纯图片文档）由调用方
/// 按空文本处理。
Future<String> convertDocxBytesToMarkdown(Uint8List bytes) =>
    compute(DocxToMarkdown.convert, bytes);
