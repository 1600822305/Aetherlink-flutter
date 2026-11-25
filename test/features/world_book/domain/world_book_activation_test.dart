import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

void main() {
  const entry = WorldBookEntry(
    id: 'entry',
    content: 'LORE',
    keywords: ['dragon'],
    scanDepth: 1,
  );

  test('sticky, cooldown and delay survive JSON and copyWith', () {
    final book = WorldBook(
      id: 'book',
      entries: [entry.copyWith(sticky: 3, cooldown: 2, delay: 2)],
    );
    final decoded = WorldBook.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.entries.single.copyWith(name: 'renamed').toJson(), {
      ...book.entries.single.toJson(),
      'name': 'renamed',
    });
    expect(WorldBookEntry.fromJson({'id': 'default'}).sticky, 0);
    expect(WorldBookEntry.fromJson({'id': 'negative', 'delay': -10}).delay, 0);
  });

  test(
    'sticky expires into cooldown without refreshing on repeated matches',
    () {
      final timed = entry.copyWith(sticky: 3, cooldown: 2, delay: 2);
      final history = <Map<String, dynamic>>[];
      var state = <String, dynamic>{};
      final active = <bool>[];
      for (var i = 0; i < 8; i++) {
        history.add({
          'role': i.isEven ? 'user' : 'assistant',
          'content': 'dragon',
        });
        final result = WorldBookActivation.evaluate(
          books: [
            WorldBook(id: 'book', entries: [timed]),
          ],
          scanMessages: history,
          history: history,
          previous: state,
        );
        active.add(result.entries.isNotEmpty);
        state = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(result.state)) as Map<dynamic, dynamic>,
        );
        final retry = WorldBookActivation.evaluate(
          books: [
            WorldBook(id: 'book', entries: [timed]),
          ],
          scanMessages: history,
          history: history,
          previous: state,
        );
        expect(
          retry.entries.isNotEmpty,
          active.last,
          reason: 'retry at message ${i + 1}',
        );
        expect(retry.state, state);
      }
      expect(active, [false, true, true, true, true, false, false, true]);
    },
  );

  test('sticky remains active after the keyword leaves the scan window', () {
    final timed = entry.copyWith(sticky: 2);
    final history = <Map<String, dynamic>>[
      {'role': 'user', 'content': 'dragon'},
    ];
    var state = WorldBookActivation.evaluate(
      books: [
        WorldBook(id: 'book', entries: [timed]),
      ],
      scanMessages: history,
      history: history,
    ).state;
    for (var i = 1; i <= 3; i++) {
      history.add({
        'role': i.isOdd ? 'assistant' : 'user',
        'content': 'unrelated',
      });
      final result = WorldBookActivation.evaluate(
        books: [
          WorldBook(id: 'book', entries: [timed]),
        ],
        scanMessages: history,
        history: history,
        previous: state,
      );
      expect(result.entries.isNotEmpty, i <= 2);
      state = result.state;
    }
  });

  test('cooldown alone allows the triggering request and its retry', () {
    final timed = entry.copyWith(cooldown: 2);
    final history = <Map<String, dynamic>>[];
    var state = <String, dynamic>{};
    for (var i = 0; i < 4; i++) {
      history.add({'role': 'user', 'content': 'dragon'});
      final result = WorldBookActivation.evaluate(
        books: [
          WorldBook(id: 'book', entries: [timed]),
        ],
        scanMessages: history,
        history: history,
        previous: state,
      );
      expect(result.entries.isNotEmpty, i == 0 || i == 3);
      state = result.state;
    }
  });

  test(
    'history edits, rewinds and entry edits invalidate existing effects',
    () {
      final timed = entry.copyWith(sticky: 5);
      final books = [
        WorldBook(id: 'book', entries: [timed]),
      ];
      final history = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'dragon'},
      ];
      final initial = WorldBookActivation.evaluate(
        books: books,
        scanMessages: history,
        history: history,
      );
      final progressed = [
        ...history,
        {'role': 'assistant', 'content': 'away'},
      ];
      final active = WorldBookActivation.evaluate(
        books: books,
        scanMessages: progressed,
        history: progressed,
        previous: initial.state,
      );
      expect(active.entries, hasLength(1));
      final changed = [
        {'role': 'user', 'content': 'away'},
        progressed.last,
      ];
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: changed,
          history: changed,
          previous: active.state,
        ).entries,
        isEmpty,
      );
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: changed.take(1).toList(),
          history: changed.take(1).toList(),
          previous: active.state,
        ).entries,
        isEmpty,
      );
      expect(
        WorldBookActivation.evaluate(
          books: [
            WorldBook(
              id: 'book',
              entries: [timed.copyWith(content: 'edited')],
            ),
          ],
          scanMessages: progressed,
          history: progressed,
          previous: active.state,
        ).entries,
        isEmpty,
      );
      expect(
        WorldBookActivation.evaluate(
          books: [],
          scanMessages: progressed,
          history: progressed,
          previous: active.state,
        ).state['effects'],
        isEmpty,
      );
    },
  );

  test(
    'timed effects are isolated by book and the conversation state supplied',
    () {
      final books = [
        WorldBook(id: 'a', entries: [entry.copyWith(sticky: 3)]),
        WorldBook(
          id: 'b',
          entries: [
            entry.copyWith(content: 'other', keywords: ['castle']),
          ],
        ),
      ];
      final history = [
        {'role': 'user', 'content': 'dragon'},
      ];
      final activated = WorldBookActivation.evaluate(
        books: books,
        scanMessages: history,
        history: history,
      );
      final next = [
        ...history,
        {'role': 'assistant', 'content': 'away'},
      ];
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: next,
          history: next,
          previous: activated.state,
        ).entries.map((e) => e.content),
        ['LORE'],
      );
      expect(
        WorldBookActivation.evaluate(
          books: books,
          scanMessages: next,
          history: next,
        ).entries,
        isEmpty,
      );
    },
  );

  test('default matching and priority ordering remain stable', () {
    final items = [
      entry.copyWith(id: 'low', constantActive: true),
      entry.copyWith(
        id: 'first',
        priority: 10,
        keywords: ['[', 'DRAGON'],
        useRegex: true,
      ),
      entry.copyWith(id: 'second', priority: 10),
      entry.copyWith(id: 'disabled', constantActive: true, enabled: false),
      entry.copyWith(id: 'empty', content: '', constantActive: true),
      entry.copyWith(id: 'case', caseSensitive: true, keywords: ['DRAGON']),
    ];
    final messages = [
      {'role': 'user', 'content': 'dragon'},
    ];
    expect(
      WorldBookActivation.evaluate(
        books: [WorldBook(id: 'book', entries: items)],
        scanMessages: messages,
        history: messages,
      ).entries.map((e) => e.id),
      ['first', 'second', 'low'],
    );
  });
  test('scanDepth limits the scanned window to the newest messages', () {
    final messages = [
      {'role': 'user', 'content': 'dragon'},
      {'role': 'assistant', 'content': 'unrelated'},
      {'role': 'user', 'content': 'still unrelated'},
    ];
    List<String> triggered(int depth) => WorldBookActivation.evaluate(
      books: [
        WorldBook(id: 'book', entries: [entry.copyWith(scanDepth: depth)]),
      ],
      scanMessages: messages,
      history: messages,
    ).entries.map((e) => e.id).toList();
    expect(triggered(1), isEmpty);
    expect(triggered(2), isEmpty);
    expect(triggered(3), ['entry']);
  });

  test('scan ignores non chat roles and blank messages', () {
    final messages = [
      {'role': 'user', 'content': 'dragon'},
      {'role': 'system', 'content': 'castle'},
      {'role': 'assistant', 'content': '   '},
    ];
    final result = WorldBookActivation.evaluate(
      books: [
        WorldBook(id: 'book', entries: [entry.copyWith(scanDepth: 1)]),
      ],
      scanMessages: messages,
      history: messages,
    );
    expect(result.entries.map((e) => e.id), ['entry']);
  });

  test('regex keywords honour case sensitivity and tolerate invalid ones', () {
    final regex = entry.copyWith(useRegex: true, keywords: ['(', r'dra\w+n']);
    expect(WorldBookActivation.matches(regex, 'A DRAGON'), isTrue);
    expect(
      WorldBookActivation.matches(regex.copyWith(caseSensitive: true), 'A DRAGON'),
      isFalse,
    );
    expect(WorldBookActivation.matches(regex, 'no match'), isFalse);
  });

  test('disabled books never trigger, even constant entries', () {
    final result = WorldBookActivation.evaluate(
      books: [
        WorldBook(
          id: 'book',
          enabled: false,
          entries: [entry.copyWith(constantActive: true)],
        ),
      ],
      scanMessages: const [],
      history: const [],
    );
    expect(result.entries, isEmpty);
    expect(result.state['effects'], isEmpty);
  });

  test('delay holds activation until enough messages exist', () {
    final delayed = entry.copyWith(delay: 2, scanDepth: 5);
    final history = <Map<String, dynamic>>[];
    final active = <bool>[];
    for (var i = 0; i < 3; i++) {
      history.add({'role': 'user', 'content': 'dragon'});
      active.add(
        WorldBookActivation.evaluate(
          books: [
            WorldBook(id: 'book', entries: [delayed]),
          ],
          scanMessages: history,
          history: history,
        ).entries.isNotEmpty,
      );
    }
    expect(active, [false, true, true]);
  });
}
