
## xterm3

<p>
    <a href="https://pub.dev/packages/xterm3">
      <img alt="Package version" src="https://img.shields.io/pub/v/xterm3?color=blue&include_prereleases">
    </a>
    <a href="https://pub.dev/packages/xterm3/score">
      <img alt="Pub points" src="https://img.shields.io/pub/points/xterm3?color=blue">
    </a>
    <a href="https://pub.dev/packages/xterm3/publisher">
      <img alt="Pub likes" src="https://img.shields.io/pub/likes/xterm3?color=blue">
    </a>
    <a href="LICENSE">
      <img alt="License: AGPL-3.0-or-later" src="https://img.shields.io/badge/license-AGPL--3.0--or--later-blue">
    </a>
</p>

**[pub.dev/packages/xterm3](https://pub.dev/packages/xterm3)** ·
[API reference](https://pub.dev/documentation/xterm3/latest/) ·
[Changelog](https://pub.dev/packages/xterm3/changelog) ·
[Source](https://github.com/klc/xterm3)

**xterm3** is a terminal emulator for Flutter applications, on mobile and
desktop. It ships a headless emulation core with no Flutter dependency and a
renderer on top of it, so the terminal can be driven — and tested — without a
widget tree.

It continues the line that started with
[`xterm`](https://pub.dev/packages/xterm) from
[`TerminalStudio/xterm.dart`](https://github.com/TerminalStudio/xterm.dart) and
was kept alive as [`xterm2`](https://pub.dev/packages/xterm2). The original
package is unmaintained, and `xterm2` has since diverged far enough —
rewritten renderer, reworked buffer and reflow, new input and search paths —
that it continues here under its own name. `xterm2` users migrate by changing
the dependency and the package in imports; the public API is unchanged.

> Requires Flutter >= 3.19.0

## Built with xterm3

**[ShellVibe](https://shellvibe.dev)** is a cross-platform terminal, SSH/SFTP
client and remote infrastructure workstation for iOS, Android, macOS, Windows
and Linux, from the same author. Every terminal pane in it is an xterm3
`TerminalView`, so it is where this package is exercised daily against real
shells, TUIs and IMEs. [shellvibe.dev](https://shellvibe.dev) ·
[GitHub](https://github.com/klc/shellvibe)

<a href="https://shellvibe.dev">
  <img width="760px" alt="ShellVibe with two split terminal panes running a git log and htop side by side"
       src="https://raw.githubusercontent.com/klc/shellvibe/main/docs/screenshots/terminal-split.png">
</a>

## Performance

Same workloads, same harness, three packages. Every number below is
reproducible from `script/cross_bench/`, which depends on all three at once and
drives each through its headless `core.dart` — so nothing per-package sits in
the measured path.

`xterm` 4.0.0 · `xterm2` 5.2.0 · `xterm3` 6.5.0. Grid 170x50, 10000 lines of
scrollback, 32 MiB per workload in 8 KiB chunks, AOT-compiled, one package per
process, three interleaved rounds. Apple M1 Pro, macOS 26.6.2, Dart 3.13.4.

**Write throughput, MiB/s** — higher is better:

| workload | `xterm` | `xterm2` | `xterm3` | vs `xterm` |
|---|---|---|---|---|
| plain ASCII output | 20.3 | 97.4 | **144.1** | **7.1x** |
| lines wider than the window | 21.5 | 134.1 | **156.7** | **7.3x** |
| SGR-heavy (coloured) output | 24.3 | **77.0** | 71.8 | 3.0x |
| UTF-8 (Turkish) | 19.2 | 17.6 | **135.8** | **7.1x** |
| Cyrillic | 18.9 | 7.0 | **116.0** | **6.1x** |
| alt-screen TUI redraw | 25.3 | 174.7 | **181.4** | **7.2x** |

**Scrollback residency, MiB** — 10000 lines of `ls -l`-shaped output retained
at a 170-column window; lower is better:

| | `xterm` | `xterm2` | `xterm3` |
|---|---|---|---|
| resident scrollback | 86.3 | 78.3 | **52.8** |

**Resize reflow, ms** — one 170 → 80 → 170 column pair with the scrollback
full, rewrapping all 10000 retained lines twice; lower is better:

| | `xterm` | `xterm2` | `xterm3` |
|---|---|---|---|
| per resize | 9.8 | 4.2 | **4.0** |

Two rows are worth reading honestly rather than as a scoreboard. **SGR output
is 7% slower than `xterm2`** — a known price of sizing line storage from what a
line actually writes, which is what buys the scrollback row; the alternatives
were measured at -22% and -14% elsewhere. And **reflow is level with `xterm2`**;
the 2.5x there is against `xterm`, not against the immediate predecessor.

The large gaps are on non-ASCII text, and they are structural: both older
packages leave the batched write path at the first accented letter, so a
language not written in ASCII never batches at all. `xterm2` is *slower* than
`xterm` on Cyrillic for that reason — the rest of its write path got faster
around a per-code-point loop that did not.

Renderer frame times, the workloads behind them, and every change that was
measured and **rejected** are in [BENCHMARKS.md](BENCHMARKS.md). Nothing in
this package is accepted on the argument that it ought to be faster.

## Screenshots

Every image below is a real frame painted by `TerminalView`, produced by
`example/lib/screenshot.dart` from PTY recordings in
`example/assets/screenshots/` — so they can be regenerated rather than
retouched. Grid 100x30, Cascadia Mono at 13pt.

<table>
  <tr>
    <td align="center">
      <a href="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-shell.png">
        <img width="380px" alt="A zsh session showing a coloured git graph, CJK and emoji, combining marks and Cyrillic"
             src="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-shell.png">
      </a>
      <br><sub>Shell — SGR colour, CJK, emoji, combining marks, Cyrillic</sub>
    </td>
    <td align="center">
      <a href="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-htop.png">
        <img width="380px" alt="htop drawing CPU and memory meters with block elements and 256-colour bars"
             src="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-htop.png">
      </a>
      <br><sub>htop — block elements and meters, drawn procedurally</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <a href="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-vim.png">
        <img width="380px" alt="vim editing a Dart source file with syntax highlighting and a status line"
             src="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-vim.png">
      </a>
      <br><sub>vim — full-screen redraw on the alternate screen</sub>
    </td>
    <td align="center">
      <a href="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-search.png">
        <img width="380px" alt="The same shell session with search matches highlighted and one active match"
             src="https://raw.githubusercontent.com/klc/xterm3/master/media/demo-search.png">
      </a>
      <br><sub>Search — every match in the scrollback, one of them active</sub>
    </td>
  </tr>
</table>

## Features

- 📦 **Works out of the box.** No special configuration required.
- ✔ **Frontend independent.** The emulation core runs without Flutter —
  `package:xterm3/core.dart` has no `dart:ui` on any path.
- 😀 **Unicode 17.** Wide characters, grapheme clusters, emoji sequences, and
  a batched write path that covers Latin, Greek, Cyrillic and Armenian rather
  than ASCII alone.
- 🔍 **Search.** Bounded, Unicode-aware, across soft wraps, with a distinct
  active match — `Terminal.search`.
- 🔗 **Hyperlinks.** OSC 8, plus plain `http(s)://` and `www.` text detected in
  the buffer. Modifier-click on desktop, tap on touch.
- 🎨 **Procedural glyphs.** Box drawing, blocks, mosaics, Braille and Powerline
  drawn directly, so they tile without font seams at any cell size.
- 🔤 **Ligatures.** Opt-in via `TerminalStyle(enableLigatures: true)` with a
  ligature-capable font such as Fira Code, JetBrains Mono or Iosevka. A
  ligature is drawn only where it fills exactly the cells it covers, so the
  grid never shifts; anything else falls back to per-cell painting.
- 🖱 **Mouse reporting.** DEC modes 1000/1002/1003 with normal, UTF-8, SGR,
  SGR-pixel and urxvt encodings; extended buttons, horizontal wheel, and
  Shift+wheel scrollback that survives an application grabbing the mouse.
- ⌨️ **Modern key encoding.** Kitty keyboard protocol, fixterms chords, and
  correct modified arrows, function keys, Enter and Escape.
- 🈂️ **IME-aware.** Composition is held back until the keyboard commits it, in
  both delete-detection modes — Turkish and CJK text arrives once, correctly.
- 🧭 **Semantic prompts.** OSC 133/633 anchors tracked across scrollback and
  reflow, with shortcuts to jump between them.
- ⏱ **Paced writing.** `PacedTerminalWriter` feeds PTY output a frame's worth
  at a time: a burst drains ~50% slower and stays at 75fps instead of 37.
- 🎛 **Runtime theming**, synchronized output (DEC 2026), DECSCUSR cursor
  shapes, focus reporting, and OSC 7 working-directory updates.

## Getting Started

**1.** Add the [package from pub.dev](https://pub.dev/packages/xterm3):

```sh
flutter pub add xterm3
```

or add it to your package's pubspec.yaml file by hand:

```yml
dependencies:
  ...
  xterm3: ^6.3.0
```

**2.** Create the terminal:

```dart
import 'package:xterm3/xterm.dart';
...
terminal = Terminal();
```

Listen to user interaction with the terminal by simply adding a `onOutput` callback:

```dart
terminal = Terminal();

terminal.onOutput = (output) {
  print('output: $output');
}
```

**3.** Create the view, attach the terminal to the view:

```dart
import 'package:xterm3/flutter.dart';
...
child: TerminalView(terminal),
```

**4.** Write something to the terminal:

```dart
terminal.write('Hello, world!');
```

**Done!**

## More examples

- Write a simple terminal in ~100 lines of code:
  https://github.com/klc/xterm3/blob/master/example/lib/main.dart

- Write a SSH client in ~100 lines of code with [dartssh2]:
  https://github.com/klc/xterm3/blob/master/example/lib/ssh.dart

- Regenerate the screenshots above:
  `python3 script/screenshots/record.py`, then
  `cd example && flutter run --release -d macos -t lib/screenshot.dart`

For the original package history, see [TerminalStudio/xterm.dart].

## Migrating from `xterm2`

The public API is unchanged. Three mechanical edits:

- `xterm2: ^5.3.0` becomes `xterm3: ^6.3.0` in `pubspec.yaml`.
- `package:xterm2/...` becomes `package:xterm3/...` in imports. The entry point
  keeps its name: `import 'package:xterm3/xterm.dart';`.
- `XTERM2_FUZZ_ROUNDS` becomes `XTERM3_FUZZ_ROUNDS`.

Note the licence change below: `xterm2` 5.3.0 and earlier are MIT, `xterm3`
6.0.0 and later are AGPL.

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/klc/xterm3/issues).
For anything that does not belong in a public issue, write to
[mustafa@shellvibe.dev](mailto:mustafa@shellvibe.dev).

Contributions are always welcome! See [CONTRIBUTING.md](CONTRIBUTING.md); pull
requests need a one-time signature of the [Contributor License Agreement](CLA.md).

## License

`xterm3` is licensed under the [GNU Affero General Public License v3.0 or
later](LICENSE) (AGPL-3.0-or-later). Linking it into an application makes that
application a work covered by the AGPL: if you distribute it, or let users
interact with it over a network, you must offer them its complete corresponding
source under the same license.

The `xterm` and `xterm2` work this package is derived from is MIT licensed and
stays available under those terms; that notice is kept in [LICENSE.MIT](LICENSE.MIT)
and [NOTICE](NOTICE). Versions up to `xterm2` 5.3.0 are unaffected by this
change — the AGPL applies from `xterm3` 6.0.0 onward.

[dartssh2]: https://pub.dev/packages/dartssh2
[TerminalStudio/xterm.dart]: https://github.com/TerminalStudio/xterm.dart
