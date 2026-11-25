import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

/// [Terminal.onReply] separates what the terminal answers by itself from what
/// the user types. Both reach the program over the same wire, so an embedder
/// that needs to tell them apart — one that hands control between a desktop
/// and a mirroring phone, say — cannot do it by inspecting the bytes: an arrow
/// key and a cursor-position report are both an escape sequence.
void main() {
  ({List<String> output, List<String> replies, Terminal terminal}) build() {
    final output = <String>[];
    final replies = <String>[];
    final terminal = Terminal()
      ..onOutput = output.add
      ..onReply = replies.add;
    return (output: output, replies: replies, terminal: terminal);
  }

  test('user input goes to onOutput, never to onReply', () {
    final t = build();

    t.terminal.textInput('ls');
    t.terminal.keyInput(TerminalKey.arrowUp);
    t.terminal.paste('echo hi');
    t.terminal.charInput(0x63, ctrl: true);

    expect(t.output.join(), contains('ls'));
    expect(t.output.join(), contains('echo hi'));
    expect(t.output.join(), contains('\x03'));
    expect(t.replies, isEmpty);
  });

  test('self-initiated replies go to onReply, never to onOutput', () {
    final t = build();

    // Primary device attributes — the first thing a full-screen program asks.
    t.terminal.write('\x1b[c');
    // Cursor position report.
    t.terminal.write('\x1b[6n');

    expect(t.replies, isNotEmpty);
    expect(t.replies.join(), contains('\x1b['));
    expect(t.output, isEmpty);
  });

  test('replies fall back to onOutput when no reply sink is set', () {
    final output = <String>[];
    final terminal = Terminal()..onOutput = output.add;

    terminal.write('\x1b[c');

    expect(output, isNotEmpty);
  });

  test('a reply sink can swallow replies without muting user input', () {
    // What a mirroring client wants: the session already has a terminal
    // answering the program, and a second answer would be a duplicate.
    final output = <String>[];
    final terminal = Terminal()
      ..onOutput = output.add
      ..onReply = (_) {};

    terminal.write('\x1b[c');
    expect(output, isEmpty);

    terminal.textInput('x');
    expect(output, ['x']);
  });
}
