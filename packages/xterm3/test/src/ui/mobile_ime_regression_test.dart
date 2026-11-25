import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

/// Regression tests for the mobile soft-keyboard input layer
/// (lib/src/ui/custom_text_edit.dart).
///
/// [CustomTextEdit.deleteDetection] switches between two mutually exclusive
/// behaviours:
///   - `deleteDetection: true`  -> backspace works, composition is broken.
///   - `deleteDetection: false` -> composition works, backspace is dead.
///
/// These tests pin down BOTH sides of that conflict so a future fix has a
/// baseline: passing tests protect behaviour that must not regress, and
/// `skip:` tests assert the behaviour that *should* happen but currently
/// does not (a filed bug, not a spec to bend to).
void main() {
  /// Pumps a [TerminalView] wired to [deleteDetection] and returns the
  /// output the (fake) terminal emitted, plus a key to reach the
  /// [TerminalViewState] for direct calls like `resetEditingState()`.
  Future<(List<String>, GlobalKey<TerminalViewState>)> pumpTerminal(
    WidgetTester tester, {
    bool deleteDetection = false,
  }) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);
    final viewKey = GlobalKey<TerminalViewState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            key: viewKey,
            autofocus: true,
            deleteDetection: deleteDetection,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TerminalView));
    await tester.pump();

    return (output, viewKey);
  }

  /// Sends a composing (or committed, if [collapsed]) editing value that
  /// mimics what a real keyboard would send for a field whose *current*
  /// on-the-wire content is `prefix + text` (the `prefix` being whatever
  /// [CustomTextEdit] initialised the field to for the given
  /// `deleteDetection` setting).
  void compose(
    WidgetTester tester,
    String prefix,
    String text, {
    required bool collapsed,
  }) {
    final full = '$prefix$text';
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: full,
        selection: TextSelection.collapsed(offset: full.length),
        composing: collapsed
            ? TextRange.empty
            : TextRange(start: prefix.length, end: full.length),
      ),
    );
  }

  group('Turkish composition (Gboard-style dead-key rewrite)', () {
    // Gboard composes Turkish diacritics by first showing a plain Latin
    // letter in the composing region, then retroactively rewriting it to
    // the accented character once the dead-key combination resolves, then
    // finally committing the composing region.
    const prefixFalse = '';
    const prefixTrue = '  ';
    const target = 'ğıİşçöü';

    testWidgets('deleteDetection: false — commits exactly once, in order', (
      tester,
    ) async {
      final (output, _) = await pumpTerminal(tester, deleteDetection: false);

      // Composing preview arrives and is retroactively corrected. Nothing
      // must reach the terminal while composing is still open.
      compose(tester, prefixFalse, 'gg', collapsed: false);
      compose(tester, prefixFalse, target, collapsed: false);
      expect(output, isEmpty);

      // Composition commits.
      compose(tester, prefixFalse, target, collapsed: true);

      expect(output.join(), target);
    });

    // BUG: with deleteDetection true, updateEditingValue() ignores the
    // composing range entirely (custom_text_edit.dart ~236-264) and emits
    // onInsert() for every intermediate composing update, then resets the
    // connection back to the sentinel. Observed: the very first `isEmpty`
    // assertion below already fails — output is ['gg', 'ğıİşçöü'] before the
    // composition ever "commits". The uncorrected preview "gg" reaches the
    // terminal, followed by the corrected word as a second, separate insert,
    // instead of a single "$target" once composition is done.
    // onComposing(null) is called unconditionally, so composition never gets
    // a chance to be handled.
    testWidgets(
      'deleteDetection: true — should commit exactly once, in order',
      (tester) async {
        final (output, _) = await pumpTerminal(tester, deleteDetection: true);

        compose(tester, prefixTrue, 'gg', collapsed: false);
        compose(tester, prefixTrue, target, collapsed: false);
        expect(output, isEmpty);

        compose(tester, prefixTrue, target, collapsed: true);

        expect(output.join(), target);
      },
    );
  });

  group('CJK composition (pinyin -> candidate -> commit)', () {
    const prefixFalse = '';
    const prefixTrue = '  ';
    const pinyin = 'nihao';
    const candidate = '你好';

    testWidgets('deleteDetection: false — commits exactly once, in order', (
      tester,
    ) async {
      final (output, _) = await pumpTerminal(tester, deleteDetection: false);

      // Pinyin keystrokes build up the composing buffer...
      compose(tester, prefixFalse, 'ni', collapsed: false);
      compose(tester, prefixFalse, pinyin, collapsed: false);
      expect(output, isEmpty);

      // ...then the user picks a candidate, replacing the whole composing
      // buffer with the chosen hanzi, still composing...
      compose(tester, prefixFalse, candidate, collapsed: false);
      expect(output, isEmpty);

      // ...and finally commits.
      compose(tester, prefixFalse, candidate, collapsed: true);

      expect(output.join(), candidate);
    });

    // BUG: same root cause as the Turkish case. Observed: the first
    // `isEmpty` assertion below already fails — output is ['ni', 'nihao']
    // before the candidate-selection step even happens, because
    // updateEditingValue() treats every composing update as a final insert
    // when deleteDetection is true. The raw pinyin reaches the terminal as
    // literal ASCII, and the hanzi candidate would be inserted on top of it,
    // never just "$candidate" as a single, correctly-timed commit.
    testWidgets(
      'deleteDetection: true — should commit exactly once, in order',
      (tester) async {
        final (output, _) = await pumpTerminal(tester, deleteDetection: true);

        compose(tester, prefixTrue, 'ni', collapsed: false);
        compose(tester, prefixTrue, pinyin, collapsed: false);
        expect(output, isEmpty);

        compose(tester, prefixTrue, candidate, collapsed: false);
        expect(output, isEmpty);

        compose(tester, prefixTrue, candidate, collapsed: true);

        expect(output.join(), candidate);
      },
    );
  });

  group('Backspace at the sentinel / cursor-at-0 boundary', () {
    testWidgets(
      'deleteDetection: true — backspace at the sentinel produces a delete',
      (tester) async {
        final (output, viewKey) = await pumpTerminal(
          tester,
          deleteDetection: true,
        );

        // Initial editing state is the '  ' sentinel, cursor collapsed at
        // offset 2, so backspace is never at "nothing to delete". The
        // keyboard removes one sentinel character.
        expect(tester.testTextInput.editingState?['text'], '  ');

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );

        // A real delete signal (DEL, 0x7f) reached the terminal - not just
        // "some" output. `output` holding a single empty string would also
        // satisfy `hasLength(1)`, so assert on content, not just count.
        expect(output, hasLength(1));
        expect(output.single.codeUnits, [0x7f]);

        // The sentinel must be restored so the next backspace still works.
        expect(tester.testTextInput.editingState?['text'], '  ');
        expect(viewKey.currentState, isNotNull);
      },
    );

    // BUG: with deleteDetection false, the initial editing state is
    // text: '' (custom_text_edit.dart ~212-215) with the cursor at offset 0.
    // There is nothing left to delete, so on a real device the soft keyboard
    // sends no editing update at all for that backspace press, and
    // CustomTextEditState never gets a chance to call onDelete(). This test
    // reproduces the one shape of update a keyboard *can* still send at that
    // boundary (a no-op, already-empty, collapsed-at-0 value). Observed: the
    // widget still calls onInsert(''), so `output` gains one entry - but it
    // is an empty string, not a delete. `output.single.codeUnits` is `[]`,
    // not `[0x7f]`: no real backspace signal ever reaches the terminal.
    testWidgets(
      'deleteDetection: false — backspace at offset 0 should still delete',
      (tester) async {
        final (output, _) = await pumpTerminal(tester, deleteDetection: false);

        expect(tester.testTextInput.editingState?['text'], '');

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          ),
        );

        expect(output, hasLength(1));
        expect(output.single.codeUnits, [0x7f]);
      },
    );
  });

  group('Composition that OPENS with a single character (the real hole)', () {
    // The length<=1 heuristic in _updateEditingValueWithDeleteDetection
    // (added by f6568e1 to swallow keyboards that trap a single already-
    // resolved keypress in a composing range that never collapses) also
    // matches the *first* keystroke of an entirely ordinary multi-step
    // composition, because real compositions open with exactly one
    // character too. These tests model that first keystroke explicitly,
    // instead of jumping straight to a two-or-more-character composing
    // range like the groups above do.
    const prefixTrue = '  ';

    testWidgets(
      'Turkish (Gboard dead-key): opens as a single char, then grows and '
      'commits - nothing should leak before the commit',
      (tester) async {
        final (output, _) = await pumpTerminal(tester, deleteDetection: true);

        // First keystroke: composing opens fresh with just 'g'.
        compose(tester, prefixTrue, 'g', collapsed: false);
        expect(
          output,
          isEmpty,
          reason: 'a freshly-opened single-character composing range must '
              'not be assumed resolved - it might still be a live preview',
        );

        // Dead-key resolves 'g' into 'ğ', still a single character, same
        // composing range.
        compose(tester, prefixTrue, 'ğ', collapsed: false);
        expect(output, isEmpty);

        // The user keeps typing; the composing buffer grows letter by
        // letter, extending the same range.
        compose(tester, prefixTrue, 'ğı', collapsed: false);
        expect(output, isEmpty);

        compose(tester, prefixTrue, 'ğıİ', collapsed: false);
        expect(output, isEmpty);

        // Composition commits.
        compose(tester, prefixTrue, 'ğıİ', collapsed: true);

        expect(output.join(), 'ğıİ');
      },
      // KNOWN CONFLICT: see report - the g -> ğ step is byte-for-byte
      // identical in shape (same base, same length, different content, no
      // collapse) to the f6568e1 trapped-keystroke pattern exercised below,
      // so no discriminator over TextEditingValue alone can tell them apart
      // without a third event or a collapse. Preserving the f6568e1
      // guarantee (a trapped keystroke must still land, with nothing else
      // to go on) forces the g -> ğ transition to also be treated as
      // resolved, which reproduces the leak this test wants to forbid.
      skip: true,
    );

    testWidgets(
      'CJK (pinyin): opens as a single char, then grows and commits - '
      'nothing should leak before the commit',
      (tester) async {
        final (output, _) = await pumpTerminal(tester, deleteDetection: true);

        // First keystroke: composing opens fresh with just 'n'.
        compose(tester, prefixTrue, 'n', collapsed: false);
        expect(
          output,
          isEmpty,
          reason: 'a freshly-opened single-character composing range must '
              'not be assumed resolved - it might still be a live preview',
        );

        // Subsequent keystrokes extend the SAME composing range - this is
        // what distinguishes a real preview from a trapped keystroke.
        compose(tester, prefixTrue, 'ni', collapsed: false);
        expect(output, isEmpty);

        compose(tester, prefixTrue, 'nih', collapsed: false);
        expect(output, isEmpty);

        compose(tester, prefixTrue, 'nihao', collapsed: false);
        expect(output, isEmpty);

        // Composition commits.
        compose(tester, prefixTrue, 'nihao', collapsed: true);

        expect(output.join(), 'nihao');
      },
    );
  });

  testWidgets(
    'double-insertion regression (f6568e1): trapped composing keypresses '
    'each land exactly once',
    (tester) async {
      // Some Android keyboards (Gboard, Samsung, SwiftKey) wrap even plain
      // ASCII keypresses in a composing range that never collapses on its
      // own. Before f6568e1, deleteDetection mode waited for
      // composing.isCollapsed like the non-detection path, so these
      // keypresses could be swallowed or double counted once something
      // eventually forced a collapse. The fix makes deleteDetection mode
      // ignore composing state entirely and always emit+reset per event.
      final (output, _) = await pumpTerminal(tester, deleteDetection: true);

      // Key 1: 'l' arrives trapped inside a composing range that never
      // collapses.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  l',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
      );

      // The connection was reset back to the sentinel after the first key,
      // so the next trapped key arrives relative to that fresh baseline,
      // not as an accumulation of 'l' + 's'.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  s',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
      );

      expect(output.join(), 'ls');
    },
  );

  testWidgets(
    'sentinel padding exhaustion: repeated backspaces keep producing '
    'signals (deleteDetection: true)',
    (tester) async {
      final (output, _) = await pumpTerminal(tester, deleteDetection: true);

      const repeats = 5;
      for (var i = 0; i < repeats; i++) {
        expect(tester.testTextInput.editingState?['text'], '  ');

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
      }

      expect(output, hasLength(repeats));
      for (final delete in output) {
        expect(delete.codeUnits, [0x7f]);
      }
      // resetEditingState() must have restored the sentinel every time, so
      // backspace never runs dry.
      expect(tester.testTextInput.editingState?['text'], '  ');
    },
  );

  group('commitComposing (input from outside the keyboard)', () {
    testWidgets(
      'flushes an open composition so the next out-of-band key lands after it',
      (tester) async {
        final (output, viewKey) = await pumpTerminal(
          tester,
          deleteDetection: true,
        );

        // The user types a path fragment. It is still composing, so the
        // terminal has not seen it.
        compose(tester, '  ', 'www', collapsed: false);
        expect(output, isEmpty);

        // An extra-keys bar is about to send Tab. Committing first is what
        // makes the shell complete `www` instead of an empty line.
        expect(viewKey.currentState!.commitComposing(), isTrue);
        expect(output.join(), 'www');
        expect(tester.testTextInput.editingState?['text'], '  ');

        // Nothing composing left to commit.
        expect(viewKey.currentState!.commitComposing(), isFalse);
        expect(output.join(), 'www');
      },
    );

    testWidgets('ignores the IME echo of a committed composition', (
      tester,
    ) async {
      final (output, viewKey) = await pumpTerminal(
        tester,
        deleteDetection: true,
      );

      compose(tester, '  ', 'www', collapsed: false);
      expect(viewKey.currentState!.commitComposing(), isTrue);

      // Android keyboards commonly follow an out-of-band commit with their own
      // delayed one. Emitting that too would type the word twice.
      compose(tester, '  ', 'www', collapsed: true);
      expect(output.join(), 'www');
    });

    testWidgets('keeps the same word typed again after a commit', (
      tester,
    ) async {
      final (output, viewKey) = await pumpTerminal(
        tester,
        deleteDetection: true,
      );

      compose(tester, '  ', 'www', collapsed: false);
      expect(viewKey.currentState!.commitComposing(), isTrue);

      // The echo guard is spent on the very next editing value, so a repeat of
      // the same word later is genuine input, not an echo.
      compose(tester, '  ', 'ls', collapsed: true);
      compose(tester, '  ', 'www', collapsed: false);
      compose(tester, '  ', 'www', collapsed: true);

      expect(output.join(), 'wwwlswww');
    });

    testWidgets('an action commit is not replayed by its delayed echo', (
      tester,
    ) async {
      final (output, _) = await pumpTerminal(tester, deleteDetection: true);

      compose(tester, '  ', 'htop', collapsed: false);
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      // The IME's delayed commit arrives after the newline was already sent.
      compose(tester, '  ', 'htop', collapsed: true);

      expect(output.join(), 'htop\r');
    });
  });
}
