import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:office_to_markdown/office_to_markdown.dart';
import 'package:pdf_to_markdown/pdf_to_markdown.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxFlutterInitialize;

/// 富文档 → 纯文本的转换层（设计文档 §5.2 本地解析轨）：把 DOCX / PDF / PPTX /
/// XLSX / EPUB 等格式转成 Markdown 后再交给 `KnowledgeService.addFile` 走通用
/// 摄取管线。

/// 文件名（或路径）是否为 DOCX。
bool isDocxFileName(String name) => name.trim().toLowerCase().endsWith('.docx');

/// 文件名（或路径）是否为 PDF。
bool isPdfFileName(String name) => name.trim().toLowerCase().endsWith('.pdf');

/// 文件名（或路径）是否为 PPTX。
bool isPptxFileName(String name) => name.trim().toLowerCase().endsWith('.pptx');

/// 文件名（或路径）是否为 XLSX。
bool isXlsxFileName(String name) => name.trim().toLowerCase().endsWith('.xlsx');

/// 文件名（或路径）是否为 EPUB。
bool isEpubFileName(String name) => name.trim().toLowerCase().endsWith('.epub');

/// 本地解析轨支持的 Office / 电子书扩展名（功能缺口④）：无需云端解析器即可
/// 摄取，库配置了云端解析器时仍优先走云端轨。
const List<String> kLocalOfficeKnowledgeExtensions = ['pptx', 'xlsx', 'epub'];

/// 仅云端预处理轨支持的富文档扩展名（功能缺口④）：本地解析轨暂无对应转换器
/// （旧版二进制格式），只有库配置了云端解析器（MinerU / Doc2X 等）时才放开选择。
const List<String> kCloudOnlyKnowledgeExtensions = ['doc', 'ppt', 'xls'];

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

/// 在后台 isolate 中把 PPTX 字节转成 Markdown（每页幻灯片一节）。
///
/// 无效包或解析失败抛 [OfficeParseException]，内容为空（如纯图片幻灯片）由
/// 调用方按空文本处理。
Future<String> convertPptxBytesToMarkdown(Uint8List bytes) =>
    compute(PptxToMarkdown.convert, bytes);

/// 在后台 isolate 中把 XLSX 字节转成 Markdown（每个工作表一张表格）。
///
/// 无效包或解析失败抛 [OfficeParseException]，空表格由调用方按空文本处理。
Future<String> convertXlsxBytesToMarkdown(Uint8List bytes) =>
    compute(XlsxToMarkdown.convert, bytes);

/// 在后台 isolate 中把 EPUB 字节转成 Markdown（按 spine 顺序拼接各章节）。
///
/// 无效包或解析失败抛 [OfficeParseException]。
Future<String> convertEpubBytesToMarkdown(Uint8List bytes) =>
    compute(EpubToMarkdown.convert, bytes);
