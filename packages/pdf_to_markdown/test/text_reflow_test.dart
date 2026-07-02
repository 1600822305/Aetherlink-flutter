import 'package:pdf_to_markdown/pdf_to_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('reflowPdfPages', () {
    test('merges wrapped English lines into a paragraph with spaces', () {
      final result = reflowPdfPages([
        'This is a long sentence that\nwraps across several lines in\nthe PDF text layer.',
      ]);
      expect(
        result,
        'This is a long sentence that wraps across several lines in the PDF text layer.',
      );
    });

    test('joins CJK lines without inserting spaces', () {
      final result = reflowPdfPages(['这是一段被 PDF 文本层\n硬换行切开的中文内容。']);
      expect(result, '这是一段被 PDF 文本层硬换行切开的中文内容。');
    });

    test('de-hyphenates English words broken across lines', () {
      final result = reflowPdfPages(['The imple-\nmentation is simple.']);
      expect(result, 'The implementation is simple.');
    });

    test('keeps bullet lines separate and normalizes bullets', () {
      final result = reflowPdfPages(['• first item\n• second item']);
      expect(result, '- first item\n\n- second item');
    });

    test('keeps numbered list lines separate', () {
      final result = reflowPdfPages(['1. alpha\n2. beta']);
      expect(result, '1. alpha\n\n2. beta');
    });

    test('splits paragraphs on terminal punctuation and blank lines', () {
      final result = reflowPdfPages(['First paragraph ends here.\nSecond starts\n\nThird paragraph']);
      expect(result, 'First paragraph ends here.\n\nSecond starts\n\nThird paragraph');
    });

    test('separates pages with blank lines and skips empty pages', () {
      final result = reflowPdfPages(['page one.', '', '   \n  ', 'page two.']);
      expect(result, 'page one.\n\npage two.');
    });

    test('returns empty string when all pages are empty (scanned PDF)', () {
      expect(reflowPdfPages(['', '  \n ']), '');
    });
  });
}
