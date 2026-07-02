import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_to_markdown/pdf_to_markdown.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxFlutterInitialize;

/// 富文档 → 纯文本的转换层（设计文档 §5.2 本地解析轨）：把 DOCX / PDF 等格式
/// 转成 Markdown 后再交给 `KnowledgeService.addFile` 走通用摄取管线。

/// 文件名（或路径）是否为 DOCX。
bool isDocxFileName(String name) => name.trim().toLowerCase().endsWith('.docx');

/// 文件名（或路径）是否为 PDF。
bool isPdfFileName(String name) => name.trim().toLowerCase().endsWith('.pdf');

/// 仅云端预处理轨支持的富文档扩展名（功能缺口④）：本地解析轨暂无对应转换器，
/// 只有库配置了云端解析器（MinerU / Doc2X 等）时才放开选择。
const List<String> kCloudOnlyKnowledgeExtensions = [
  'doc',
  'ppt',
  'pptx',
  'xls',
  'xlsx',
  'epub',
];

/// 文件名（或路径）是否为「仅云端轨」富文档（见 [kCloudOnlyKnowledgeExtensions]）。
bool isCloudOnlyKnowledgeFileName(String name) {
  final lower = name.trim().toLowerCase();
  return kCloudOnlyKnowledgeExtensions.any((ext) => lower.endsWith('.$ext'));
}

/// 在后台 isolate 中把 DOCX 字节转成 Markdown。
///
/// 无效包或解析失败抛 [DocxParseException]，内容为空（如纯图片文档）由调用方
/// 按空文本处理。
Future<String> convertDocxBytesToMarkdown(Uint8List bytes) =>
    compute(DocxToMarkdown.convert, bytes);

/// 抽取 PDF 字节的文本层并重排为段落文本。
///
/// PDFium 解析在引擎的原生 worker 中执行，不阻塞 UI isolate。扫描件（无文本层）
/// 返回空字符串，由调用方提示；打开失败抛 [PdfParseException]。
Future<String> convertPdfBytesToMarkdown(Uint8List bytes) async {
  await pdfrxFlutterInitialize();
  return PdfToMarkdown.convert(bytes);
}
