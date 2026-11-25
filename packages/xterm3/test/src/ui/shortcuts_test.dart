import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/shortcut/shortcuts.dart';

void main() {
  test('non-Apple clipboard shortcuts preserve terminal control keys', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final shortcuts = defaultTerminalShortcuts;
    final pasteShortcuts = shortcuts.entries
        .where((entry) => entry.value is PasteTextIntent)
        .map((entry) => entry.key)
        .whereType<SingleActivator>()
        .toList();
    final copyShortcuts = shortcuts.entries
        .where((entry) => entry.value is CopySelectionTextIntent)
        .map((entry) => entry.key)
        .whereType<SingleActivator>()
        .toList();
    final selectAllShortcut = shortcuts.entries
        .where((entry) => entry.value is SelectAllTextIntent)
        .map((entry) => entry.key)
        .whereType<SingleActivator>()
        .single;

    expect(
      pasteShortcuts,
      contains(
        isA<SingleActivator>()
            .having(
              (shortcut) => shortcut.trigger,
              'trigger',
              LogicalKeyboardKey.keyV,
            )
            .having((shortcut) => shortcut.control, 'control', isTrue)
            .having((shortcut) => shortcut.shift, 'shift', isTrue),
      ),
    );
    expect(
      pasteShortcuts,
      contains(
        isA<SingleActivator>()
            .having(
              (shortcut) => shortcut.trigger,
              'trigger',
              LogicalKeyboardKey.insert,
            )
            .having((shortcut) => shortcut.control, 'control', isFalse)
            .having((shortcut) => shortcut.shift, 'shift', isTrue),
      ),
    );
    expect(
      copyShortcuts,
      contains(
        isA<SingleActivator>()
            .having(
              (shortcut) => shortcut.trigger,
              'trigger',
              LogicalKeyboardKey.insert,
            )
            .having((shortcut) => shortcut.control, 'control', isTrue)
            .having((shortcut) => shortcut.shift, 'shift', isFalse),
      ),
    );
    expect(selectAllShortcut.trigger, LogicalKeyboardKey.keyA);
    expect(selectAllShortcut.control, isTrue);
    expect(selectAllShortcut.shift, isTrue);
  });
}
