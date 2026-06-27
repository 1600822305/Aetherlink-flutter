import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

void main() {
  group('processIncomingContent — code fence stripping', () {
    test('strips a fence wrapping the whole payload', () {
      expect(
        processIncomingContent('```dart\nvoid main() {}\n```'),
        'void main() {}',
      );
      expect(processIncomingContent('```\nplain\n```'), 'plain');
    });

    test('keeps trailing blank lines after the closing fence', () {
      expect(processIncomingContent('```\nbody\n```\n'), 'body\n');
    });

    test('leaves a Markdown doc that merely contains fenced blocks intact', () {
      const md = '# Title\n\n```dart\ncode\n```\n\nmore text';
      expect(processIncomingContent(md), md);
    });

    test('does not strip an unmatched leading fence', () {
      const text = '```dart\nstuff without a closing fence';
      expect(processIncomingContent(text), text);
    });

    test('does not strip when the opener line has extra content', () {
      const text = '```dart and notes\ncode\n```';
      expect(processIncomingContent(text), text);
    });
  });

  group('processIncomingContent — HTML entity unescaping', () {
    test('un-escapes content that is fully escaped (no raw angle brackets)', () {
      expect(
        processIncomingContent('if (a &lt; b &amp;&amp; c &gt; d) {}'),
        'if (a < b && c > d) {}',
      );
    });

    test('leaves content that already has real angle brackets untouched', () {
      const html = '<p>x &amp; y</p>';
      expect(processIncomingContent(html), html);
    });

    test('leaves an entity-only file (no angle entities) untouched', () {
      const text = 'rights &amp; duties';
      expect(processIncomingContent(text), text);
    });
  });

  group('countLines', () {
    test('empty string is zero lines', () {
      expect(countLines(''), 0);
    });

    test('single line without trailing newline', () {
      expect(countLines('abc'), 1);
    });

    test('a trailing newline does not add a phantom line', () {
      expect(countLines('a\nb'), 2);
      expect(countLines('a\nb\n'), 2);
      expect(countLines('a\nb\n\n'), 3);
    });
  });

  group('omission detection', () {
    test('strong markers are flagged on their own', () {
      expect(detectStrongCodeOmission('// rest of code unchanged'), isTrue);
      expect(detectStrongCodeOmission('# ... remaining code'), isTrue);
      expect(detectStrongCodeOmission('/* existing code */'), isTrue);
      expect(detectStrongCodeOmission('// same as before'), isTrue);
    });

    test('a bare ellipsis is only a weak marker', () {
      expect(detectStrongCodeOmission('// ...'), isFalse);
      expect(detectCodeOmission('// ...'), isTrue);
    });

    test('ordinary code is not flagged', () {
      const code = 'final x = 1;\nprint(x);';
      expect(detectStrongCodeOmission(code), isFalse);
      expect(detectCodeOmission(code), isFalse);
    });
  });

  group('pathUnderRoot', () {
    const root = 'content://docs/tree/primary%3ADownload';

    test('matches the root itself and its children', () {
      expect(pathUnderRoot(root, root), isTrue);
      expect(pathUnderRoot('$root/document/foo.txt', root), isTrue);
    });

    test('rejects a sibling sharing a name prefix', () {
      expect(pathUnderRoot('${root}Old/document/x', root), isFalse);
      expect(pathUnderRoot('content://docs/tree/primary%3ADown', root), isFalse);
    });
  });
}
