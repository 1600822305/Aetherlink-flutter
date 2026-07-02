import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';

import 'text_reflow.dart';

/// PDF 打开/解析失败（损坏、加密无密码等）。
class PdfParseException implements Exception {
  PdfParseException(this.message);

  final String message;

  @override
  String toString() => 'PdfParseException: $message';
}

/// PDF → 文本转换入口（知识库 §5.2 本地解析轨）。
///
/// 调用前必须完成 PDFium 初始化：纯 Dart 环境 `await pdfrxInitialize()`，
/// Flutter 应用 `await pdfrxFlutterInitialize()`（由 pdfrx 插件打包原生库）。
abstract final class PdfToMarkdown {
  /// 抽取 [bytes] 的文本层并重排为段落文本。
  ///
  /// 无文本层（如扫描件）返回空字符串，由调用方提示；打开失败抛
  /// [PdfParseException]。
  static Future<String> convert(Uint8List bytes) async {
    final PdfDocument document;
    try {
      document = await PdfDocument.openData(bytes, sourceName: 'memory.pdf');
    } catch (e) {
      throw PdfParseException('无法打开 PDF（损坏或已加密）：$e');
    }
    try {
      final pageTexts = <String>[];
      for (final page in document.pages) {
        final text = await page.loadStructuredText();
        pageTexts.add(text.fullText);
      }
      return reflowPdfPages(pageTexts);
    } finally {
      await document.dispose();
    }
  }
}
