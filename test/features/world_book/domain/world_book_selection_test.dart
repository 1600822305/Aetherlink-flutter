import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_selection.dart';

List<String> ids(List<WorldBook> books, List<String> texts) => [
  for (final e in selectTriggeredWorldBookEntries(books: books, scanTexts: texts))
    e.id,
];

void main() {
  const base = WorldBookEntry(id: 'e', content: 'C', keywords: ['dragon']);

  test('constant entries and keyword hits trigger; timers are ignored', () {
    final books = [
      WorldBook(
        id: 'b',
        entries: [
          base.copyWith(id: 'const', keywords: [], constantActive: true),
          base.copyWith(id: 'hit', sticky: 3, cooldown: 5, delay: 99),
          base.copyWith(id: 'miss', keywords: ['castle']),
        ],
      ),
    ];
    expect(ids(books, ['a dragon']), ['const', 'hit']);
  });

  test('scanDepth looks at the newest N texts only', () {
    final books = [
      WorldBook(id: 'b', entries: [base.copyWith(scanDepth: 1)]),
    ];
    expect(ids(books, ['dragon', 'other']), isEmpty);
    expect(ids(books, ['other', 'dragon']), ['e']);
    expect(
      ids([
        WorldBook(id: 'b', entries: [base.copyWith(scanDepth: 2)]),
      ], ['dragon', 'other']),
      ['e'],
    );
  });

  test('blank scan texts do not consume scan depth', () {
    final books = [
      WorldBook(id: 'b', entries: [base.copyWith(scanDepth: 1)]),
    ];
    expect(ids(books, ['dragon', '   ']), ['e']);
  });

  test('invalid regex keywords do not block the valid ones', () {
    final books = [
      WorldBook(
        id: 'b',
        entries: [
          base.copyWith(useRegex: true, keywords: ['(', r'dra\w+n']),
        ],
      ),
    ];
    expect(ids(books, ['DRAGON']), ['e']);
  });

  test('priority descending, then book order, then entry order', () {
    final books = [
      WorldBook(
        id: 'b1',
        entries: [
          base.copyWith(id: 'b1-low'),
          base.copyWith(id: 'b1-high', priority: 5),
        ],
      ),
      WorldBook(
        id: 'b2',
        entries: [
          base.copyWith(id: 'b2-high', priority: 5),
          base.copyWith(id: 'b2-low'),
        ],
      ),
      WorldBook(
        id: 'off',
        enabled: false,
        entries: [base.copyWith(id: 'off', priority: 9)],
      ),
    ];
    expect(ids(books, ['dragon']), ['b1-high', 'b2-high', 'b1-low', 'b2-low']);
  });

  test('disabled and empty entries never trigger', () {
    final books = [
      WorldBook(
        id: 'b',
        entries: [
          base.copyWith(id: 'off', enabled: false, constantActive: true),
          base.copyWith(id: 'blank', content: '  ', constantActive: true),
        ],
      ),
    ];
    expect(ids(books, ['dragon']), isEmpty);
  });
}
