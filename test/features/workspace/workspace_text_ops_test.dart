// Unit tests for the backend-neutral file-text helpers
// (lib/features/workspace/domain/workspace_text_ops.dart). These are pure
// functions, so the coverage here is the highest-ROI safety net for the SSH
// backend's read → transform → write path (it has no native plugin to lean on).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_text_ops.dart'
    as ops;

void main() {
  group('countLines', () {
    test('empty input is zero lines', () {
      expect(ops.countLines(''), 0);
    });

    test('a trailing newline does not add a phantom empty line', () {
      expect(ops.countLines('a\nb\nc'), 3);
      expect(ops.countLines('a\nb\nc\n'), 3);
    });

    test('single line without terminator counts as one', () {
      expect(ops.countLines('hello'), 1);
    });

    test('CRLF terminators count like LF', () {
      expect(ops.countLines('a\r\nb\r\nc'), 3);
    });
  });

  group('rangeHash / fileHash', () {
    test('rangeHash hashes exactly the slice bytes with terminators kept', () {
      const content = 'one\ntwo\nthree\nfour\n';
      // lines 2..3 inclusive == "two\nthree\n"
      final expected =
          sha256.convert(utf8.encode('two\nthree\n')).toString();
      expect(ops.rangeHash(content, 2, 3), expected);
    });

    test('rangeHash preserves CRLF (no normalization)', () {
      const lf = 'a\nb\n';
      const crlf = 'a\r\nb\r\n';
      expect(ops.rangeHash(lf, 1, 2), isNot(ops.rangeHash(crlf, 1, 2)));
    });

    test('whole-file rangeHash equals fileHash', () {
      const content = 'x\ny\nz\n';
      expect(ops.rangeHash(content, 1, ops.countLines(content)),
          ops.fileHash(content));
    });

    test('out-of-range bounds clamp to the file', () {
      const content = 'a\nb\n';
      expect(ops.rangeHash(content, 1, 99), ops.fileHash(content));
    });
  });

  group('readFileRange', () {
    test('returns the slice, total lines and a matching hash', () {
      const content = 'l1\nl2\nl3\nl4\nl5';
      final r = ops.readFileRange(content, 2, 4);
      expect(r.content, 'l2\nl3\nl4\n');
      expect(r.totalLines, 5);
      expect(r.startLine, 2);
      expect(r.endLine, 4);
      expect(r.rangeHash, ops.rangeHash(content, 2, 4));
    });

    test('rejects invalid ranges', () {
      expect(() => ops.readFileRange('a\nb', 0, 1), throwsArgumentError);
      expect(() => ops.readFileRange('a\nb', 3, 1), throwsArgumentError);
    });
  });

  group('insertContent', () {
    test('inserts before the given 1-based line', () {
      const content = 'a\nb\nc\n';
      expect(ops.insertContent(content, 2, 'X\n'), 'a\nX\nb\nc\n');
    });

    test('inserts at the top', () {
      expect(ops.insertContent('a\nb\n', 1, 'first\n'), 'first\na\nb\n');
    });

    test('appending past the end gives the last line a terminator first', () {
      // last line "b" has no newline; inserting at line 3 (append) must not
      // glue "c" onto "b".
      expect(ops.insertContent('a\nb', 3, 'c\n'), 'a\nb\nc\n');
    });

    test('rejects line < 1', () {
      expect(() => ops.insertContent('a', 0, 'x'), throwsArgumentError);
    });
  });

  group('replaceInFile', () {
    test('literal replace-all counts every occurrence', () {
      final r = ops.replaceInFile('foo foo foo', 'foo', 'bar');
      expect(r.newContent, 'bar bar bar');
      expect(r.replacements, 3);
    });

    test('replaceAll=false replaces only the first match', () {
      final r =
          ops.replaceInFile('foo foo', 'foo', 'bar', replaceAll: false);
      expect(r.newContent, 'bar foo');
      expect(r.replacements, 1);
    });

    test('case-insensitive literal matching', () {
      final r = ops.replaceInFile('Foo foo FOO', 'foo', 'x',
          caseSensitive: false);
      expect(r.replacements, 3);
      expect(r.newContent, 'x x x');
    });

    test('regex with backreferences', () {
      final r = ops.replaceInFile('a1 b2', r'([a-z])(\d)', r'$2$1',
          isRegex: true);
      expect(r.newContent, '1a 2b');
      expect(r.replacements, 2);
    });

    test('no match leaves content untouched', () {
      final r = ops.replaceInFile('hello', 'zzz', 'x');
      expect(r.newContent, 'hello');
      expect(r.replacements, 0);
    });
  });

  group('applyDiff — search/replace', () {
    test('applies a single block', () {
      const content = 'line1\nline2\nline3\n';
      const diff = '<<<<<<< SEARCH\n'
          'line2\n'
          '=======\n'
          'CHANGED\n'
          '>>>>>>> REPLACE';
      final r = ops.applyDiff(content, diff);
      expect(r.success, isTrue);
      expect(r.newContent, 'line1\nCHANGED\nline3\n');
    });

    test('applies multiple blocks in order', () {
      const content = 'a\nb\nc\n';
      const diff = '<<<<<<< SEARCH\n'
          'a\n'
          '=======\n'
          'A\n'
          '>>>>>>> REPLACE\n'
          '<<<<<<< SEARCH\n'
          'c\n'
          '=======\n'
          'C\n'
          '>>>>>>> REPLACE';
      final r = ops.applyDiff(content, diff);
      expect(r.success, isTrue);
      expect(r.newContent, 'A\nb\nC\n');
    });

    test('fails when a SEARCH block is not found', () {
      const diff = '<<<<<<< SEARCH\n'
          'nope\n'
          '=======\n'
          'x\n'
          '>>>>>>> REPLACE';
      final r = ops.applyDiff('a\nb\n', diff);
      expect(r.success, isFalse);
      expect(r.conflict, isFalse);
      expect(r.newContent, isNull);
    });

    test('reports added / deleted line counts', () {
      const content = 'keep\nold\n';
      const diff = '<<<<<<< SEARCH\n'
          'old\n'
          '=======\n'
          'new1\n'
          'new2\n'
          '>>>>>>> REPLACE';
      final r = ops.applyDiff(content, diff);
      expect(r.success, isTrue);
      expect(r.linesAdded, 1);
      expect(r.linesChanged, 1);
    });
  });

  group('applyDiff — optimistic lock', () {
    const content = 'l1\nl2\nl3\n';
    const diff = '<<<<<<< SEARCH\n'
        'l2\n'
        '=======\n'
        'X\n'
        '>>>>>>> REPLACE';

    test('passes when the range hash still matches', () {
      final hash = ops.rangeHash(content, 2, 2);
      final r = ops.applyDiff(content, diff,
          expectedRangeHash: hash, rangeStartLine: 2, rangeEndLine: 2);
      expect(r.success, isTrue);
      expect(r.newContent, 'l1\nX\nl3\n');
    });

    test('reports a conflict when the range changed', () {
      final r = ops.applyDiff(content, diff,
          expectedRangeHash: 'deadbeef', rangeStartLine: 2, rangeEndLine: 2);
      expect(r.success, isFalse);
      expect(r.conflict, isTrue);
      expect(r.newContent, isNull);
    });

    test('whole-file lock when no range is given', () {
      final r = ops.applyDiff(content, diff,
          expectedRangeHash: ops.fileHash(content));
      expect(r.success, isTrue);
    });
  });

  group('applyDiff — unified', () {
    test('applies a hunk that replaces a line', () {
      const content = 'a\nb\nc\n';
      const diff = '--- a/file\n'
          '+++ b/file\n'
          '@@ -2,1 +2,1 @@\n'
          '-b\n'
          '+B\n';
      final r = ops.applyDiff(content, diff,
          format: WorkspaceDiffFormat.unified);
      expect(r.success, isTrue);
      expect(r.newContent, 'a\nB\nc\n');
    });

    test('applies a hunk with context and an insertion', () {
      const content = 'a\nb\nc\n';
      const diff = '@@ -1,3 +1,4 @@\n'
          ' a\n'
          ' b\n'
          '+inserted\n'
          ' c\n';
      final r = ops.applyDiff(content, diff,
          format: WorkspaceDiffFormat.unified);
      expect(r.success, isTrue);
      expect(r.newContent, 'a\nb\ninserted\nc\n');
    });

    test('fails when context does not match the file', () {
      const content = 'a\nb\nc\n';
      const diff = '@@ -2,1 +2,1 @@\n'
          '-WRONG\n'
          '+B\n';
      final r = ops.applyDiff(content, diff,
          format: WorkspaceDiffFormat.unified);
      expect(r.success, isFalse);
    });
  });
}
