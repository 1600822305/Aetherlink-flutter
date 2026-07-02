/// PDF → Markdown-ish text conversion on top of pdfrx_engine (PDFium).
library;

export 'src/converter.dart' show PdfToMarkdown, PdfParseException;
export 'src/text_reflow.dart' show reflowPdfPages;
