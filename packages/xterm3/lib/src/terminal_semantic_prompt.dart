part of 'terminal.dart';

enum TerminalSemanticPromptContent {
  output,
  prompt,
  input,
}

enum TerminalSemanticPromptKind {
  initial,
  right,
  continuation,
  secondary,
}

enum TerminalSemanticPromptClickMode {
  line,
  multiple,
  eventsAbsolute,
  eventsRelative,
}

enum TerminalSemanticPromptRedraw {
  disabled,
  enabled,
  last,
}

final class TerminalSemanticPromptState {
  const TerminalSemanticPromptState({
    required this.content,
    this.lastCommandExitCode,
    this.aid,
    this.promptKind,
    this.clickMode,
    this.redraw,
    this.specialKey,
    this.commandLine,
  });

  final TerminalSemanticPromptContent content;

  final int? lastCommandExitCode;

  final String? aid;

  final TerminalSemanticPromptKind? promptKind;

  final TerminalSemanticPromptClickMode? clickMode;

  final TerminalSemanticPromptRedraw? redraw;

  final bool? specialKey;

  final String? commandLine;
}

/// Tracks the OSC 133 / OSC 633 semantic-prompt state machine: the current
/// [TerminalSemanticPromptState] and whether semantic input should terminate
/// at the next line feed.
///
/// This class deliberately does NOT own anchor bookkeeping (locating
/// prompts within the scrollback buffer so [Terminal.isSemanticPromptLine]
/// and friends can answer later). That bookkeeping reaches directly into
/// `_mainBuffer` (`createAnchorFromCursor`, `createAnchor`, `anchor.dispose`)
/// and writes `CellAttr.semanticPrompt` into buffer lines; giving this class
/// a buffer dependency to absorb it would only trade one entanglement for
/// another, wider one. What's left here — computing the next
/// [TerminalSemanticPromptState] from an escape sequence and prior state,
/// and the two small pure predicates below — has no such dependency, so it
/// moves cleanly. Anchor management and the OSC dispatch methods that call
/// into it stay on [Terminal] in terminal.dart.
class _SemanticPromptTracker {
  TerminalSemanticPromptState state = const TerminalSemanticPromptState(
    content: TerminalSemanticPromptContent.output,
  );

  bool inputTerminatesAtLineFeed = false;

  void reset() {
    inputTerminatesAtLineFeed = false;
    state = const TerminalSemanticPromptState(
      content: TerminalSemanticPromptContent.output,
    );
  }

  /// Whether [state] represents a primary (as opposed to continuation or
  /// secondary) prompt, i.e. one that should be recorded as a navigable
  /// anchor.
  static bool isPrimaryPrompt(TerminalSemanticPromptState state) {
    if (state.content != TerminalSemanticPromptContent.prompt) return false;
    return switch (state.promptKind) {
      TerminalSemanticPromptKind.continuation ||
      TerminalSemanticPromptKind.secondary =>
        false,
      _ => true,
    };
  }

  /// The [CellAttr] semantic bits to paint into the cursor style for
  /// [content], or 0 when the terminal isn't showing the main buffer (the
  /// alt buffer never carries semantic prompt attributes).
  static int semanticAttributes(
    TerminalSemanticPromptContent content, {
    required bool isMainBuffer,
  }) {
    if (!isMainBuffer) return 0;
    return switch (content) {
      TerminalSemanticPromptContent.prompt => CellAttr.semanticPrompt,
      TerminalSemanticPromptContent.input => CellAttr.semanticInput,
      TerminalSemanticPromptContent.output => 0,
    };
  }
}

Map<String, String> _parseSemanticPromptOptions(List<String> pt) {
  final options = <String, String>{};
  for (var index = 1; index < pt.length; index++) {
    final part = pt[index];
    final separator = part.indexOf('=');
    if (separator <= 0) continue;
    final key = part.substring(0, separator);
    final value = part.substring(separator + 1);
    if (key.isEmpty) continue;
    options[key] = value;
  }
  return options;
}

int? _parseSemanticPromptExitCode(List<String> pt) {
  if (pt.length < 2) return null;
  return int.tryParse(pt[1]);
}

TerminalSemanticPromptKind? _parseSemanticPromptKind(String? value) {
  return switch (value) {
    'i' => TerminalSemanticPromptKind.initial,
    'r' => TerminalSemanticPromptKind.right,
    'c' => TerminalSemanticPromptKind.continuation,
    's' => TerminalSemanticPromptKind.secondary,
    _ => null,
  };
}

TerminalSemanticPromptClickMode? _parseSemanticPromptClickMode(
  Map<String, String> options,
) {
  final clickEvents = switch (options['click_events']) {
    '1' => TerminalSemanticPromptClickMode.eventsAbsolute,
    '2' => TerminalSemanticPromptClickMode.eventsRelative,
    _ => null,
  };
  if (clickEvents != null) return clickEvents;

  return switch (options['cl']) {
    'line' => TerminalSemanticPromptClickMode.line,
    'm' => TerminalSemanticPromptClickMode.multiple,
    _ => null,
  };
}

TerminalSemanticPromptRedraw? _parseSemanticPromptRedraw(String? value) {
  return switch (value) {
    '0' => TerminalSemanticPromptRedraw.disabled,
    '1' => TerminalSemanticPromptRedraw.enabled,
    'last' => TerminalSemanticPromptRedraw.last,
    _ => null,
  };
}

bool? _parseSemanticPromptBoolean(String? value) {
  return switch (value) {
    '0' => false,
    '1' => true,
    _ => null,
  };
}

String? _parseSemanticPromptCommandLine(Map<String, String> options) {
  final commandLine = options['cmdline'];
  if (commandLine != null) {
    return _decodeSemanticPromptPrintfQ(commandLine);
  }

  final commandLineUrl = options['cmdline_url'];
  if (commandLineUrl == null) return null;

  try {
    return Uri.decodeFull(commandLineUrl);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

String? _decodeSemanticPromptPrintfQ(String value) {
  final data = switch (value) {
    final text when text.startsWith(r"$'") => switch (text.endsWith("'")) {
        true => text.substring(2, text.length - 1),
        false => null,
      },
    final text when text.startsWith("'") => switch (text.endsWith("'")) {
        true => text.substring(1, text.length - 1),
        false => null,
      },
    _ => value,
  };
  if (data == null) return null;

  final result = StringBuffer();
  var index = 0;
  while (index < data.length) {
    final codeUnit = data.codeUnitAt(index);
    if (codeUnit != 0x5c) {
      result.writeCharCode(codeUnit);
      index++;
      continue;
    }

    if (index + 1 >= data.length) return null;
    final escaped = switch (data.codeUnitAt(index + 1)) {
      0x20 => 0x20,
      0x5c => 0x5c,
      0x22 => 0x22,
      0x27 => 0x27,
      0x24 => 0x24,
      0x65 => Ascii.ESC,
      0x6e => Ascii.LF,
      0x72 => Ascii.CR,
      0x74 => Ascii.HT,
      0x76 => Ascii.VT,
      _ => null,
    };
    if (escaped == null) return null;

    result.writeCharCode(escaped);
    index += 2;
  }
  return result.toString();
}
