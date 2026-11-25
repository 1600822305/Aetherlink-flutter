## [6.5.0] - 2026-11-16

This release comes out of a review of the package for speed and resource use.
Every number below was measured before and after, ten interleaved rounds of
the old build against the new on an idle Apple M1 Pro, AOT-compiled, 170x50
grid with 10000 lines of scrollback; medians, with the two builds' ranges
disjoint in every row.

### Faster

* Output whose lines end in `ESC[K` - what `grep --color` and compiler
  diagnostics emit on every line - no longer grows each line's storage to the
  full width of the window. Erasing allocated and wrote cells that already
  read as blank, which undid the line storage 6.3.0 sized from the text, for
  exactly the output that is kept in scrollback. Lines ending in `ESC[K` write
  at 130 MiB/s instead of 63.5, `grep --color`-shaped output at 39 instead of
  12, and 10000 such lines hold 14.6 MB of cell storage instead of 29.3
  (9.8 MB for 30-column lines).

* Box drawing, block elements, braille and the dash, quote and bullet
  punctuation (U+2010..U+2027) are written in batched runs. They took the
  per-character path with a full grapheme segmentation each, so a TUI's
  borders and bars were written at 4.6 M characters/s; they now go at 125.5.
  Turkish text with an em dash on each line goes from 82 to 136 MiB/s.

* OSC 8 hyperlinks no longer rescan the whole buffer as they are written.
  With a link on every line (`ls --hyperlink`) and 10000 lines of scrollback,
  writing took 1.8 ms a line; it takes 4.3 us. At 1000 lines, 7.2 us becomes
  3.9 us, and plain output scrolling past a single live link is 17% faster.

* The paragraph cache is sized to the screen. Its keys carry each cell's
  colour, and at a fixed 2048 entries a screen with a colour per cell - a
  truecolor gradient, 256-colour output - missed on nearly every cell of
  every repaint, cursor blink included. It now holds one screen plus a
  quarter, and never less than before.

Plain ASCII, long lines, SGR-heavy output, Cyrillic and alt-screen redraws are
unchanged. CJK text measured about 2% slower (9.3 to 9.1 M characters/s).

### Changed behaviour

* With the OSC 8 registry at its 4096-link ceiling, it is re-checked for
  links that are no longer on screen once per interval rather than on every
  new link. A link opened while the registry is full still gets no link, as
  before; links freed by an erase are picked up within at most 2048 opens
  instead of at the next one.

* The paragraph cache can hold more than 2048 entries per view: about 10800
  at 170x50. Only a screen that needs that many distinct entries reaches it.

### API

* `BufferLine.writtenLength`: the cells from here to `length` hold nothing.
* `TerminalPainter.fitParagraphCacheToGrid`, and `ParagraphCache.maximumSize`
  is now settable.

## [6.4.0] - 2026-11-11

This release comes out of a full review of the package against hostile and
malformed terminal output. Four defaults change; each is listed first.

### Changed defaults

* Applications can no longer resize the terminal through escape sequences
  (`CSI 8 ; rows ; cols t`, `CSI Ps t` with Ps >= 24, DECSCPP, DECSNLS)
  unless the new `Terminal(allowRemoteResize: true)` is set. Any output
  could shrink the terminal to 1x1, where it stayed until the window was
  resized, or grow it to hundreds of thousands of rows. When allowed, sizes
  are clamped to 1..1000, and `CSI 8 ; rows ; cols t` fires `onResize`
  twice (rows, then columns).

* `TerminalView` no longer answers OSC 52 clipboard reads by default. It
  installed its own query handler, so any remote output could read the
  user's clipboard while the view had focus. An embedder that wants this
  sets `Terminal.onClipboardQuery` itself. Clipboard writes are unchanged.

* The window title report (`CSI 21 t`) always returns an empty title. It
  echoed the application-set title into the input stream, which let output
  place text on the shell's command line.

* `TerminalView(readOnly: true)` blocks hardware keyboard input and paste,
  as documented. Only the soft keyboard was blocked before. Copy and
  select-all still work. On web, `readOnly` still opens an input
  connection, so typed text can reach the terminal there.

### Escape parser and terminal

* CSI numeric parameters are capped at 65535. Larger values overflowed,
  threw a `RangeError` out of `write()` and dropped the rest of the chunk
  (`CSI 18446744073709551615 L`); a huge REP count stalled the terminal.
  REP also repeats at most one screenful.

* Malformed OSC 133 `cmdline_url`, XTGETTCAP and OSC colour values no
  longer throw from `write()` or produce negative colours. DECAUPSS ignores
  malformed designators, so DECRQUPSS cannot echo control characters.

* Unrecognised ESC sequences with intermediate bytes (`ESC % G`,
  `ESC SP F`, `ESC $ ( D`) are discarded instead of printing their final
  character.

* Colon-form truecolor SGR without a colour-space field (`38:2:R:G:B`) is
  parsed correctly when more parameters follow.

* An OSC whose terminator arrives exactly at the 8 KiB limit no longer
  swallows the terminator and all following output.

* RIS (`ESC c`) clears OSC colour overrides, DECAC colour assignments and
  saved DEC private modes.

* In origin mode with left/right margins, VPA no longer drifts the cursor
  to the right, and CHA/HPA are relative to the left margin.

* Pasting text with CRLF line endings outside bracketed paste mode sends
  one carriage return per line, not two.

* Search and URL detection no longer see a phantom space where a wide
  character wrapped to the next row.

* XTVERSION and secondary device attributes report the current package
  version; they had been reporting 5.3.0.

### Buffer, reflow and selection

* The cursor stays in place when a resize makes a line exactly fill the new
  width. It was left on its old row, and the next character overwrote the
  last one. A narrowing reflow also no longer pushes the cursor's row into
  scrollback while blank rows remain below it.

* `ESC[K` no longer breaks soft-wrapped lines unless it erases the whole
  row. `grep --color` and compiler diagnostics emit it constantly, which
  split long lines when they were copied or reflowed.

* Erased or reflowed text no longer reappears after shrinking and then
  widening the terminal.

* Copied text keeps the spaces between words when an application left the
  cells blank instead of writing spaces, as ncurses does.
  `BufferLine.getText()` and `toString()` now return a space for a blank
  cell inside the row; trailing blanks are still trimmed.

* Lines scrolled out of a scroll region that starts at the top of the main
  screen are kept in scrollback, so output above a pinned status line (the
  apt/dpkg progress bar layout) is no longer lost.

* Block selections dragged from top-right to bottom-left are highlighted.

* Restoring a saved cursor after the terminal height shrinks and grows
  returns to the right row.

### View and input

* Mouse reports are no longer one row too low once there is scrollback and
  the view height is not a multiple of the cell height. With the view
  scrolled up, a click reports the screen row of the line actually clicked
  instead of the visible row index.

* Scrolling back to the bottom while output is streaming resumes following
  new output.

* With a full scrollback, a scrolled-up view keeps the same text in place
  as new output arrives, until that text is trimmed.

* `TerminalTheme` has value equality, so rebuilding an equal non-const
  theme no longer flushes the render caches or sends an unsolicited
  colour-scheme report.

* With xterm modifyOtherKeys level 2, unmodified and Shift-only printable
  keys are sent as plain text again instead of `CSI 27 ; 1 ; … ~`, and Meta
  is encoded. On macOS this also lets those keys reach the input method.

* Cancelling an IME composition no longer sends a backspace that erased a
  real character on the shell line.

* Output that only looks like a ZModem start no longer freezes the
  session; the bytes are shown and input keeps working.

### Package

* Removed the unused `convert`, `equatable` and `quiver` dependencies.

## [6.3.7] - 2026-10-08

* Auto-scrolling during drag selection uses global pointer coordinates.
  The gesture handler passed local coordinates to the edge auto-scroller,
  which compares the drag target against the scrollable's global bounds.
  When the terminal was placed below the top of the screen (such as under
  an app bar, tab bar, or top padding), dragging in the upper portion of the
  terminal was misinterpreted as being above the viewport, prematurely
  triggering upward auto-scroll.

## [6.3.6] - 2026-10-02

* Input methods compose on macOS. A pressed key that carries its character
  was inserted by the text fallback and reported as handled, and the macOS
  embedder offers a key to the platform input method only when the framework
  leaves it unhandled, so Korean, Japanese and Chinese IMEs never saw it:
  typing `한글테스트` on the 2-Set Korean layout sent
  `ㅎㅏㄴㄱㅡㄹㅌㅔㅅㅡㅌㅡ`. Such keys are now left to the input method while
  an input connection is attached; key repeats, keys without a character
  (shifted symbols) and chords are unchanged. Linux is unchanged for now: its
  embedder does not serialize key events, so this needs a device to verify.

* The macOS Korean input method does not mark the syllable it composes: it
  rewrites the last character of the editing text in place (`ㅎ`, `하`, `한`)
  and reads the previous character from that text. The text is therefore not
  cleared while a Hangul character ends it, and never from inside an editing
  update (an input method may commit and open a new mark in one keystroke);
  what was sent is tracked by content, and the trailing Hangul character is
  shown as the composing preview and sent once something follows it, or
  before a key the terminal handles itself (Enter, arrows, chords, Option,
  Cmd), a paste, on focus loss, when the keyboard is closed or the view is
  disposed. Backspace edits the held character jamo by jamo, and from another
  input source drops it. Latin and other text is still sent at once. Mobile,
  web, Windows, Linux and `deleteDetection` are unchanged.

## [6.3.5] - 2026-09-30

* A drag selection keeps its start where it was pressed while the view
  scrolls. The press was kept as a pixel offset in the viewport and read
  again on every move, so scrolling with the wheel, or through the edge
  auto-scroller, moved the start by as many lines as the view had moved and
  text longer than one screen could not be selected. The start is now held
  as an anchor on its cell, which also survives scrollback being trimmed
  during the drag. Long-press selection on touch is fixed the same way.

* Keypad Enter with a modifier is encoded as the main Enter key under the
  kitty keyboard protocol's "disambiguate" flag: Shift+keypad Enter sends
  `CSI 13;2u` instead of `CSI 57414;2u`. Cursor's agent CLI does not decode
  keypad key codes and inserted U+E046 where Shift+Enter starts a new line.
  With every key reported as an escape code, keypad Enter keeps its own code.

## [6.3.4] - 2026-09-24

* Keypad keys type under the kitty keyboard protocol's "disambiguate" flag.
  Cursor's agent CLI pushes only that flag (`CSI >1u`) and does not decode
  keypad key codes, and every numpad digit or operator went out as
  `CSI 57400;129u` and the like, so the CLI inserted private-use characters
  instead of `1`. The spec encodes only non-text keypad keys under
  disambiguate: digits and operators are now plain text unless Ctrl, Alt or
  Super is held or every key is reported as an escape code.

* Caps Lock, Num Lock and Scroll Lock are reported only when every key is an
  escape code, as kitty does; they count as modifier keys. Num Lock (Clear on
  a Mac keyboard) no longer inserts a character in disambiguate clients.

* Unmodified keypad Enter sends a carriage return like the main Enter key
  unless every key is reported as an escape code. kitty and Ghostty send
  `CSI 57414u` here, which leaves the key dead in clients that only ask for
  disambiguate; with a modifier it is still encoded.

## [6.3.3] - 2026-09-23

* Wide glyphs that overflow their two cells are shrunk to fit instead of
  clipped. A wide character is almost always an emoji, drawn from a color
  emoji font whose advance — about 1.25em for Apple Color Emoji — exceeds two
  cells of most monospace faces, and the painter clipped it to those cells:
  every ✅ and ❌ lost its right edge. The glyph is now scaled down to the
  cells it owns and centred vertically on where it would have been drawn.
  Glyphs that fit, and glyphs in narrow cells, are painted as before.

* U+279C HEAVY ROUND-TIPPED RIGHTWARDS ARROW, the oh-my-zsh prompt symbol,
  is drawn as an arrow. The procedural path was a notched head with no shaft,
  which at terminal sizes read as `>`; it is now a heavy shaft and head with
  round caps and joins, the shape Menlo and the Nerd Fonts give it.

## [6.3.2] - 2026-09-23

* Option-composed characters type under xterm's modifyOtherKeys mode 2 on
  macOS. Option composes characters there unless option-as-meta is on — on a
  Turkish Q layout Option+Q is `@`, Option+8 is `[` — and with mode 2 enabled,
  which Claude Code and other Ink apps turn on to tell Shift+Enter apart, such
  a press was encoded as `CSI 27;3;<char>~`, Alt plus the character. The
  application read a modified key, and the character could not be typed at
  all. The check the kitty encoder already made now lives in one place and
  both encoders use it: an Option-only press that produced a printable
  character other than the key's own is sent as that text. It also covers keys
  with no US-layout character to compare against, such as Turkish `ş`, which
  the kitty encoder previously reported as Alt. Option with Ctrl or Cmd, and
  every other platform, are unchanged.

## [6.3.1] - 2026-09-17

* Text stays selectable on the alternate screen. The three full-width scroll
  paths shifted a block of lines by assigning `lines[to] = lines[from]`, which
  leaves the same `BufferLine` in two slots of the circular buffer; overwriting
  the stale slot later detached a line that was by then on screen at `to` and
  holding anchors. A detached line cannot answer for an anchor, so
  `TerminalController` reported no selection at all — nothing highlighted and
  nothing to copy — and each scrolled line took another one down with it, so a
  session degraded the longer it ran. The main buffer scrolls by pushing lines
  onto the scrollback and never reached this code, which is why the same text
  was selectable out of `cat` but not out of an editor. `IndexAwareCircularBuffer`
  gains `move`, which clears the source slot, and the scroll paths use it.

* A press that lands on blank space starts a selection instead of nothing.
  `selectWord` gave up when the cell under the pointer was a separator or an
  empty cell, and since it is the entry point for touch selection and double
  click, a long press on the empty half of a short line selected nothing and
  could not recover — every later move update re-read the same blank starting
  cell and gave up again. Such a cell now selects itself, at both ends of the
  range.

## [6.3.0] - 2026-08-30

* A `BufferLine` no longer sizes its cell storage to the terminal's width the
  moment it is created. A line is born holding a shared empty list, so
  scrolling allocates nothing per line, and the first write sizes the store to
  what it is about to write; a line that later outgrows that store grows to its
  full length in one step. Output whose lines are shorter than the window —
  which is most output — stops paying for the columns it never reaches.

  Scrollback shrinks with it. At a 170-column window holding 10000 lines,
  90-column output retains 14.6 MB where it used to retain 29.3, and 60-column
  output retains 9.8 MB. Full-width output is unchanged, since there was
  nothing to give back.

  Throughput moves both ways, measured end to end at 170x50 over 32 MiB per
  workload: plain ASCII +18%, Cyrillic +19%, mixed UTF-8 +24%, alt-screen
  unchanged, 170-column lines -3%. SGR-heavy output is **13% slower**, and that
  is a real cost rather than measurement noise: such a line is filled by
  several short runs between colour changes, so the first write sizes the store
  small and a later one has to grow it, which is two allocations where the old
  behaviour needed one. Growing in smaller steps was measured at -22% and
  starting from a larger store at -14%, so this is the least bad of the three.

* `BufferLine.data` — deprecated, and marked visible for testing — now reports
  the storage a line actually holds rather than a list sized to the window. It
  can be empty for a line nothing has written to. Reading cells through the
  accessors is unaffected: a cell with no storage behind it answers with the
  zeros it would have held anyway.

## [6.2.0] - 2026-08-29

* `CursorStyle.isItalic` replaces `isItalis`, which had carried the typo since
  it was introduced. The old name stays as a deprecated alias and will go in
  the next major. `CursorStyle.isStrikethrough` fills the gap beside it: the
  attribute was already tracked, but nothing exposed it.
* Semantic prompt anchors are pruned by a full sweep rather than only from the
  front. Anchors invalidated in the middle of the queue used to survive, and
  since the queue is capped at the buffer's line count and that cap evicts from
  the front, enough stale entries pushed a still-valid prompt out — the
  terminal forgot a prompt that was on screen.
* Escape-heavy output parses faster. `ByteConsumer.consume()` ran the same
  high-surrogate test twice per code point to reach the same conclusion, that a
  unit which does not start a surrogate pair is one unit long and is its own
  code point. Testing once covers everything outside astral text. The gain
  lands where `consume()` is hot: SGR-heavy output goes from 76 to 81 MiB/s end
  to end and 121 to 133 MiB/s through the parser, alt-screen output from 171 to
  178 and 276 to 296. Plain text is unchanged, since it goes through the run
  scan instead.
* `wholeWord` search no longer builds a one-character `String` and runs a
  Unicode regex per side of every candidate match. An ASCII range check up
  front takes the overhead from 10% to 1-3%, and 14.3 ms to 12.9 ms on output
  where matches abut word characters.
* Plain-text URL detection runs only while the hyperlink modifier is held. It
  used to run on every pointer hover — 1.3 to 1.9 us and about 3 KB per event —
  to produce a result nothing could act on. It also runs once when the modifier
  goes down under a stationary pointer, so a link still lights up without
  moving the mouse.
* The editable rect is published once per frame instead of once per terminal
  change. Fifty writes between frames were fifty walks to the root to update an
  observable that is read once; it is now marked dirty and flushed from
  `paint`.
* The painter's record of run texts already known not to shape into a
  grid-aligned ligature no longer grows without bound. It exists so that a run
  a font declines to ligate stops competing for slots in the paragraph cache,
  but it carried no limit of its own and was discarded only when the font or
  colours changed. Ordinary content settles it at a few dozen entries; a
  session that keeps producing unfamiliar punctuation runs grew it for as long
  as the painter lived. Dropping an entry is never a correctness matter: it
  costs exactly the one re-layout the entry was there to avoid.
* API reference fixes. Literal values written as `[true]`, `[false]` and
  `[null]` rendered as unresolved links rather than as code, and the types
  reachable through more than one library now name `xterm` as their canonical
  home rather than leaving dartdoc to pick one at low confidence.

## [6.1.3] - 2026-08-10

* Add explicit type annotations to the terminal tap-down callback and circular
  buffer index assignment operator to satisfy pub.dev's stricter analysis.

## [6.1.2] - 2026-08-09

* `Terminal.onReply` separates the data the terminal sends on its own
  initiative — device attributes, status and cursor-position reports, colour
  and size queries, terminfo capabilities, focus reports, OSC 52 clipboard
  reads — from the data the user types. Both have always travelled the same
  wire, and the bytes cannot be told apart after the fact: an arrow key and a
  cursor-position report are both an escape sequence. An embedder that reads
  traffic as "the user is typing", or that mirrors one session across two
  terminals and must not answer a query twice, needs the distinction. Replies
  fall back to `onOutput` when no reply sink is set, so nothing changes for
  existing callers.

## [6.1.1] - 2026-08-09

* `TerminalView.commitComposing()` emits a pending IME composition as terminal
  input and reports whether there was one. Input that reaches the terminal from
  outside the keyboard — a mobile extra-keys bar, a paste button — is appended
  to what the terminal has already received, but an open composition has not
  been received yet: it is deferred until the composition resolves. Sending Tab
  while the IME still holds `www` completed an empty line rather than `www`.
  Callers should commit before such a key; `resetEditingState()` remains for
  when the composition is genuinely to be thrown away.
* Fixed an out-of-band commit being typed twice in `deleteDetection` mode. The
  guard that swallows the IME's delayed echo of a committed composition existed
  only on the non-`deleteDetection` path, so on Android — where terminals turn
  `deleteDetection` on to keep backspace working — pressing Enter sent the
  command and then the keyboard's own delayed commit replayed the whole word on
  the next line. The guard now covers both paths and is spent on the very next
  editing value, so the same word typed again later is still genuine input.

## [6.1.0] - 2026-08-08

* `TerminalView.predictionText` draws caller-supplied text at the cursor,
  underlined, without it ever entering the buffer. It exists for clients that
  can show a keystroke before the far end confirms it — a Mosh client's local
  echo, say — where writing the character into the buffer would be wrong,
  because a screen diff computed against the frame the server believes you have
  will never repair a locally invented cell.
* The text is suppressed while IME composition is active: a user composing a
  character must not also be shown a speculative one.
* It is drawn whenever the cursor's row is on screen, not when the cursor
  itself is painted, so it stays readable through the cursor's blink-off phase
  and while an application has hidden the cursor. Composition keeps its old
  behaviour of forcing the cursor visible; predictions deliberately do not.

## [6.0.1] - 2026-08-06

* No library changes. The published archive drops from 5 MB to 377 KB: 6.0.0
  shipped the example app's 4 MB suggestion corpus, the benchmark inputs under
  `script/`, a bundled font and the README screenshots, none of which anyone
  depending on the package has a use for. The README still renders its images
  on pub.dev, which links them from raw.githubusercontent.
* Move `docs/` to `doc/`, the directory name pub's layout conventions expect.

## [6.0.0] - 2026-08-06

* **Renamed the package from `xterm2` to `xterm3`.** The code has diverged far
  enough from the `xterm2` line — renderer, buffer and reflow, input and search —
  that it continues under its own name at
  [`klc/xterm3`](https://github.com/klc/xterm3). The public API is unchanged, so
  migration is mechanical:
  * `xterm2: ^5.3.0` becomes `xterm3: ^6.0.0` in `pubspec.yaml`.
  * `package:xterm2/...` becomes `package:xterm3/...` in imports. The entry
    point keeps its name: `import 'package:xterm3/xterm.dart';`.
  * `XTERM2_FUZZ_ROUNDS` becomes `XTERM3_FUZZ_ROUNDS`.

* **Relicensed from MIT to AGPL-3.0-or-later.** From this release on, an
  application that links `xterm3` is a covered work: distributing it, or
  letting users interact with it over a network, requires offering the
  complete corresponding source under the AGPL. The MIT-licensed `xterm` /
  `xterm2` work this package derives from keeps its terms — the notice is in
  `LICENSE.MIT` and `NOTICE` — and `xterm2` 5.3.0 and earlier remain MIT.

* Make plain-text `http(s)://` and `www.` URLs clickable, not just OSC 8
  hyperlinks. `Terminal.urlAt(CellOffset)` detects a URL in buffer text
  (soft-wrap aware, joined the same way `Terminal.search` joins wrapped rows)
  and `TerminalView.onHyperlinkTap` now fires for it too. On desktop this
  follows the existing OSC 8 convention — hold Cmd (macOS) or Ctrl and click,
  with a hover underline — while touch has no modifier to hold, so a direct
  tap opens the link. `Terminal.search` and the new detector now share one
  logical-line/cell-mapping implementation (`terminal_logical_line.dart`)
  instead of duplicating it.
* Add `PacedTerminalWriter`, an opt-in way to feed PTY output to a terminal a frame's
  worth at a time. Writing every chunk as it arrives lets a burst own the UI thread
  between frames: 32 MiB of `cat`-style output on a 170x50 grid drains in 566ms at 37
  frames per second. Through the writer with its default 8ms budget, the same burst
  takes 854ms and holds 75 frames per second. It is a trade — around 50% slower to
  drain, smooth while it drains — so nothing uses it by default.
* Allocate less slack per buffer line. Line storage rounded its capacity up by
  doubling from 64, so a 170-column line reserved 256 cells and never addressed half
  of them. Scrolling allocates one line per line of output, so that slack was charged
  on the hottest path in the terminal. Capacity now rounds up to a multiple of 32,
  which still absorbs the small widenings a resize does: 12% more throughput on
  ordinary output and 16% on long lines.
* Batch writes for alphabets other than English. The parser wrote a run of printable
  ASCII into cells in one go and handed everything else to the per-code-point path,
  so the first accented letter ended the run and a language written entirely in
  non-ASCII letters never batched at all — Cyrillic ran at 6 MiB/s, a fifteenth of
  ASCII. Runs are now defined by `isSingleCellPrintable`: ASCII, Latin-1, Latin
  Extended-A and B, IPA, spacing modifiers, Greek, Cyrillic and Armenian, each of
  which is width 1 and cannot continue a grapheme cluster. Cyrillic 6 to 73 MiB/s,
  Turkish 32 to 54.
* Roughly double the throughput of non-ASCII text. Grapheme cluster detection had a
  fast path only for the case where both the previous cell and the incoming code
  point are ASCII, so a single accented letter — `ö` in Turkish, any Latin-1 word —
  dropped every following character into full grapheme segmentation, at two string
  allocations and two segmentation passes each. Nothing below U+0300 can continue a
  cluster, so that is now the cut, and `writeChar` skips both cluster checks for such
  code points. Measured with `bin/parse_bench.dart`: 15 MiB/s to 32 MiB/s on Turkish
  text, against a 35 MiB/s ceiling with grapheme clustering disabled entirely.
* Add `bin/parse_bench.dart`, which measures write-path throughput with no Flutter and
  no renderer, separating the parser from the buffer writes it drives.
* Stop the procedural glyph cache from making large terminals slower than no cache
  at all. Its keys are (codepoint, cell size, colour), so a screen drawing box lines
  in many colours can reference thousands of distinct keys, and at the old 512-entry
  capacity a full-screen grid thrashed it — a miss pays for the recording and the
  insert on top of the drawing, so the cache cost 1.9ms of UI time per frame *over*
  painting uncached. Capacity is now 4096. Block elements (`U+2580..U+259F`), which
  are one or two `drawRect` calls, now bypass the cache entirely: replaying a
  recorded picture per cell put a picture boundary in the raster command stream for
  every cell and cost 0.4ms of raster per frame at a 100% hit rate, for no saving on
  the UI thread.
* Fix wide characters corrupting the cell grid. `BufferLine.setCell` now repairs the
  width-2 lead / width-0 placeholder pairing itself, so no caller can leave half a
  wide character behind — a filler cell written when a wide character does not fit
  before the right margin used to overwrite an existing placeholder in place, and
  growing a previously shrunk line could resurrect a stale lead whose placeholder was
  cut off. Found by the new parser fuzz harness.
* Defer soft-keyboard input while an IME composition is open, in both `deleteDetection`
  modes, so Turkish and CJK text reaches the terminal only once the keyboard commits it.
  Previously an uncorrected preview (`gg` before `ğıİşçöü`, `ni` before `nihao`) was
  written to the terminal as literal text. Composition is now tracked by composing-range
  identity rather than length, which keeps single keypresses that Android keyboards wrap
  in a never-collapsing composing range landing exactly once.
* Recognise a backspace at offset 0 as a delete when `deleteDetection` is off. It
  previously produced an empty insert and no delete ever reached the terminal.
* Add an opt-in `Terminal.onUnknownSequence` diagnostic callback, reporting ESC, CSI, OSC
  and DCS sequences the parser does not recognise. It costs nothing when unset, and
  deliberately stays silent for sequences that are handled internally.
* **Behavior change:** `Observable.listeners` is now an `Iterable<void Function()>`
  view instead of a `Set<void Function()>`. Iterating, `length` and `contains`
  keep working; code that mutated the set directly must call `addListener` and
  `removeListener` instead. The backing storage is now an append-only list with
  tombstoned removals, so `notifyListeners` no longer allocates a defensive copy
  on every notification — it ran once per `Terminal.write`.
* Cache rasterised procedural glyphs (box drawing, block elements, Powerline,
  Braille) as `ui.Picture` keyed on code point, cell size and colour. They were
  re-tesselated as vector paths on every repaint, including on a static screen.
* Replace the paragraph cache's O(n log n) eviction with a lazily repaired
  binary min-heap. Eviction previously copied and sorted every entry once per
  batch; the cache-hit path stays allocation-free and untouched.
* Prune OSC 8 hyperlink URIs when scrollback lines are evicted, instead of only
  when the registry hits its ceiling. Eviction scans are batched so hyperlink
  heavy output does not pay a full buffer scan per evicted line.
* Assert that `Terminal.write` is not re-entered. Re-entering it from a listener
  or an `onOutput`/`onBell`/`onTitleChange` callback corrupts parser state.
* **Deprecated:** `EscapeHandler.unkownEscape` is superseded by the correctly
  spelled `unknownEscape`. The old name still works and forwards to the new one;
  it will be removed in the next major.
* **Deprecated:** `CellData.getHash` is unused inside the package and will be
  removed in the next major.
* `BufferLine.data` is deprecated and marked `@visibleForTesting`; it exposed raw
  cell storage for mutation. `BufferLine.anchors` now returns an unmodifiable
  live view.
* Add a seeded parser fuzz harness and assert real invariants in the stress test,
  which previously only checked that nothing threw. Two pre-existing bugs the
  harness uncovered — a `RangeError` in resize reflow and a wide character left
  in a line's last column without room for its placeholder — are recorded as
  skipped regression tests pending a fix.
* **Behavior change:** `TerminalController` now defaults to `PointerInputs.all()`,
  so pointer motion and drag events reach the terminal. Applications that enable
  DEC private modes 1002 (button-event tracking) and 1003 (any-event tracking)
  now receive mouse reports out of the box, matching xterm, iTerm2 and Kitty.
  Reports are still gated on the mouse mode the application requests, so a
  terminal with mouse reporting disabled emits nothing. To restore the previous
  default, pass
  `TerminalController(pointerInputs: PointerInputs({PointerInput.tap, PointerInput.scroll}))`.
* Render font ligatures when `TerminalStyle.enableLigatures` is set, keeping
  the cell grid intact by falling back to per-cell painting whenever a shaped
  run would not fill exactly the cells it covers. Requires a font that ships
  ligatures, such as Fira Code, JetBrains Mono or Iosevka.

## [5.3.0] - 2026-07-28

* Render bounded search matches with a distinct active result.
* Auto-scroll scrollback while extending a selection beyond the viewport.
* Add Shift+Home/End/PageUp/PageDown scrollback navigation.
* Track primary OSC 133/633 prompts across scrollback and reflow.
* Navigate semantic prompts with native platform shortcuts.
* Correct modified arrow-key sequences across main and alternate screens.
* Encode modified F1–F4 keys with xterm-compatible CSI sequences.
* Preserve Shift+wheel scrollback while applications report mouse input.
* Report horizontal wheel gestures and simulate them in alternate screens.
* Keep application scrolling active when Flutter replaces its scroll position.
* Preserve active and saved cursor positions through resize reflow.
* Leave double- and triple-click handling to applications using mouse tracking.
* Complete application mouse drags with release events without host selection.
* Report mouse buttons immediately without gesture-recognizer delays.
* Report back and forward mouse buttons through extended mouse protocols.
* Ignore unsupported highlight tracking without disrupting active mouse input.
* Respond to legacy DECID terminal identification requests.
* Report the current xterm3 version to terminal applications.
* Preserve complete semicolon-rich OSC titles, paths, and cursor names.
* Render the British national replacement character set.
* Render text decorations consistently across blank cells.
* Ignore orphaned zero-width marks instead of altering existing cells.
* Preserve combining marks after changing grapheme-cluster mode.
* Let wide symbol glyphs use adjacent blank cells instead of clipping.
* Keep IME composition text on the active row near the right edge.
* Preserve Ctrl+A and Ctrl+V input with standard terminal clipboard shortcuts.
* Preserve AltGr-composed text on Windows and Linux keyboards.
* Encode modified Enter keys distinctly for modern interactive CLIs.
* Preserve distinct Ctrl+Shift letter chords with fixterms encoding.
* Add standard Ctrl+Insert copy and Shift+Insert paste shortcuts.
* Correct Ctrl+Alt+Backspace and DEC backarrow modifier handling.
* Encode modified Escape keys distinctly for interactive applications.
* Preserve legacy Ctrl+number-row control chords.
* Bound streaming clipboard capture memory and recover after overflow.
* Reduce allocation overhead for non-ASCII terminal output.
* Avoid duplicate Unicode width lookups while processing terminal output.
* Preserve supplementary Unicode glyphs split across output chunks.
* Reduce memory overhead when sanitizing unsafe paste payloads.
* Release consumed terminal input buffers without waiting for more output.
* Ignore unsupported control bytes instead of rendering them as glyphs.
* Harden hyperlink hit testing during concurrent resize and reflow.
* Update hovered OSC 8 links immediately when the platform modifier changes.

## [5.2.0] - 2026-07-25

* Harden resize behavior for synchronized output, tab stops, and size reports.
* Reduce parser, allocation, and cell-copy overhead during dense TUI output.
* Allocate scrollback cell metadata lazily to reduce idle memory use.
* Match modern terminal handling for Alt-modified text input.
* Expose complete OSC 3008 hierarchical context metadata.
* Add bounded Unicode-aware scrollback search across soft wraps.

## [5.1.0] - 2026-07-19

* Add Unicode 17 width handling and broader emoji grapheme support.
* Add Kitty keyboard modifiers and expanded VT/xterm protocol compatibility.
* Improve OSC 8 hyperlinks, selection isolation, clear behavior, and inline TUI scrolling.
* Expand procedural rendering for box drawing, blocks, mosaics, branch graphs, and legacy symbols.
* Improve glyph fallback, wide-character rendering, contrast, and decoration accuracy.
* Reduce parser, resize, repaint, and paragraph-cache overhead under sustained output.
* Harden resize reflow and buffer editing across wrapped and wide lines.

## [5.0.0] - 2026-07-11

* Rename package to `xterm3` for the maintained fork.
* Support DEC synchronized updates with Alacritty-compatible timeout recovery.
* Report terminal view focus changes for DEC focus tracking mode.
* Render application-selected DECSCUSR cursor shapes.
* Animate blinking cursors with Alacritty-compatible interval and timeout.
* Bound OSC payload memory and safely discard oversized fragmented sequences.
* Bound CSI payload and parameter memory across fragmented sequences.
* Expose authoritative current-directory updates from OSC 7.
* Parse, render, hit-test, and activate bounded OSC 8 hyperlinks.
* Render common block and box-drawing glyphs procedurally without font seams.
* Reuse cell paints to reduce per-frame rendering allocations.
* Keep the full viewport available when `maxLines` is smaller than its height.
* Improve terminal glyph rendering, prompt symbols, OSC hyperlinks, cursor visibility, and scroll behavior.

## [4.0.0] - 2024-02-27
* Update for Flutter 3.19 [#190]. Thanks [@domesticmouse].
* Fix designate charset logic [#186]. Thanks [@djnalluri].

## [3.6.1-pre] - 2023-04-28
* Add Termianl.onPrivateOSC callback
* Copy shortcut on Windows default to Ctrl+Shift+V (#173)

## [3.6.0-pre] - 2023-04-27
* Basic ZMODEM support

## [3.5.0] - 2023-04-20
* Support customizing word separators for selection [#160]. Thanks [@itzhoujun].
* Fix incorrect tab stop handling [#161]. Thanks [@itzhoujun].
* Added support for Ctrl+Home, Ctrl+End etc [#169]. Thanks [@nuc134r].

## [3.4.1] - 2023-01-27
* Fix Flutter 3.7 incompatibilities [#151], thanks [@jpnurmi].

## [3.4.0] - 2022-11-4
* Mouse input is enabled by default.
* Support scrolling in alternate buffer.
* Fix `deleteLines` behavior.
* Fix `eraseDisplayFromCursor` removes characters before the cursor.

## [3.3.0] - 2022-10-30
* Sync ShortcutManager's shortcuts in didUpdateWidget [#140], thanks [@jpnurmi].
* fix: terminal font size not respecting system level font scale [#138], thanks [@LucasAschenbach].
* Fix selection color [#135], thanks [@jpnurmi].
* fix: dispose controllers of TerminalView [#132], thanks [@tauu].
* feat: add hardwareKeyboardOnly flag to TerminalView [#131], thanks [@tauu].
* feat: initial mouse support [#130], thanks [@tauu].
* feat: limited window manipulation support [#129], thanks [@tauu].
* fix: workaround to draw underlined spaces [#128], thanks [@tauu].
* feat: block selection [#127], thanks [@tauu].
* feat: enable changing the inputHandler of a terminal [#126], thanks [@tauu].
* fix: export TerminalTargetPlatform [#125], thanks [@tauu].
* fix: only dispose the FocusNodes which TerminalView creates [#124], thanks [@tauu].
* feat: expose readOnly flag of CustomTextEdit in TerminalView [#123], thanks [@tauu].
* fix: supports numpad enter key [#137].
* feat: expose `reflowEnabled` flag [#104].
* docs: add virtual keyboard example [#141].

## [3.2.7] - 2022-9-13
* Fix lint issues.

## [3.2.6] - 2022-9-13
* First stable release of xterm.dart v3.

## [3.2.6-alpha] - 2022-9-13
* Fix new line width in reflow.

## [3.2.5-alpha] - 2022-9-12
* Fix intent related issue.

## [3.2.4-alpha] - 2022-9-12
* Use flutter native shortcut intents.

## [3.2.3-alpha] - 2022-9-12
* Export shortcut related classes.

## [3.2.2-alpha] - 2022-9-12
* Implement default keyboard shortcuts.

## [3.2.1-alpha] - 2022-9-12
* Disable optional line scroll mode that is under development.

## [3.2.0-alpha] - 2022-9-12
* Enhanced selection handing.
* More tests.

## [3.1.0-alpha] - 2022-9-4
* Update dependencies & merge into master

## [3.0.6-alpha] - 2022-4-4
* Export `TerminalViewState`
* Added `onTap` callback to `TerminalView`

## [3.0.5-alpha] - 2022-4-4
* Avoid resize when `RenderBox.size` is zero.
* Added `charInput` and `textInput`method.
* Added `requestKeyboard`, `closeKeyboard` and `hasInputConnection`method.
* Export `KeyboardVisibilty`

## [3.0.4-alpha] - 2022-4-1
* Improved text editing
* Added composing state painting
* Adapt to `MediaQuery.padding`

## [3.0.3-alpha] - 2022-3-28
* Improved scroll handing
* Improved resize handing
* Fix focus repaint
* Fix OSC title update

## [3.0.2-alpha] - 2022-3-28
* Re-design `KeyboardVisibilty`

## [3.0.1-alpha] - 2022-3-27
* Add `KeyboardVisibilty`

## [3.0.0-alpha] - 2022-3-26
* Initial release of v3.

## [2.6.0] - 2021-12-28
* Add scrollBehavior field to the TerminalView class [#55].
* Feature: Search [#60]. Thanks [@devmil].
* Fixes for occasional unintended multi character input [#61]. Thanks [@devmil].
* Fixes ALT + L for a Mac (German Layout) [#62]. Thanks [@devmil].
* Fixes example build problem of flutter-windows for new version of flutter [#63]. Thanks [@linhanyu].
* Fixes inverse color text (when background == 0) [#66]. Thanks [@devmil].
* Fixes assert of scrollController.position [#67]. Thanks [@linhanyu].
* Change interface of ssh.dart example to satisfied new dartssh [#69]. Thanks [@linhanyu].
* add configuration options for keyboard [#74]. Thanks [@jda258].
* Adds check if the TerminalIsolate has already been started  [#77]. Thanks [@devmil].

## [2.5.0-pre] - 2021-8-4
* Support select word / whole row via double tap [#40]. Thanks [@devmil].
* Adds "selectAll" to TerminalUiInteraction [#43]. Thanks [@devmil].
* Fixes sgr processing [#44],[#45]. Thanks [@devmil].
* Adds blinking Cursor support [#46]. Thanks [@devmil].
* Fixes Zoom adaptions on non active buffer [#47]. Thanks [@devmil].
* Adds Padding option to TerminalView  [#48]. Thanks [@devmil].
* Removes no longer supported LogicalKeyboardKey  [#49]. Thanks [@devmil].
* Adds the composing state [#50]. Thanks [@devmil].
* Fix scroll problem in mobile device [#51]. Thanks [@linhanyu].

## [2.4.0-pre] - 2021-6-13
* Update the signature of TerminalBackend.resize() to also receive dimensions in
 pixels[(#39)](https://github.com/TerminalStudio/xterm.dart/pull/39). Thanks [@michaellee8](https://github.com/michaellee8).

## [2.3.1-pre] - 2021-6-1
* Export `theme/terminal_style.dart`

## [2.3.0-pre] - 2021-6-1
* Add `import 'package:xterm/isolate.dart';`

## [2.2.1-pre] - 2021-6-1
* Make BufferLine work on web.

## [2.2.0-pre] - 2021-4-12

## [2.1.0-pre] - 2021-3-20
* Better support for resizing and scrolling.
* Reflow support (in progress [#13](https://github.com/TerminalStudio/xterm.dart/pull/13)), thanks [@devmil](https://github.com/devmil).

## [2.0.0] - 2021-3-7
* Clean up for release

## [2.0.0-pre] - 2021-3-7
* Migrate to nnbd

## [1.3.0] - 2021-2-24
* Performance improvement.

## [1.2.0] - 2021-2-15

* Pass TerminalView's autofocus to the InputListener that it creates. [#10](https://github.com/TerminalStudio/xterm.dart/pull/10), thanks [@timburks](https://github.com/timburks)

## [1.2.0-pre] - 2021-1-20

* add the ability to use fonts from the google_fonts package [#9](https://github.com/TerminalStudio/xterm.dart/pull/9)

## [1.1.1+1] - 2020-10-4

* Update readme


## [1.1.1] - 2020-10-4

* Add brightWhite to TerminalTheme

## [1.1.0] - 2020-9-29

* Fix web support.

## [1.0.2] - 2020-9-29

* Update link.

## [1.0.1] - 2020-9-29

* Disable debug print.

## [1.0.0] - 2020-9-28

* Update readme.

## [1.0.0-dev] - 2020-9-28

* Major issues are fixed.

## [0.1.0] - 2020-8-9

* Bug fixes

## [0.0.4] - 2020-8-1

* Revert version constrain

## [0.0.3] - 2020-8-1

* Update version constrain


## [0.0.2] - 2020-8-1

* Update readme


## [0.0.1] - 2020-8-1

* First version


[@devmil]: https://github.com/devmil
[@michaellee8]: https://github.com/michaellee8
[@linhanyu]: https://github.com/linhanyu
[@jda258]: https://github.com/jda258
[@jpnurmi]: https://github.com/jpnurmi
[@LucasAschenbach]: https://github.com/LucasAschenbach
[@tauu]: https://github.com/tauu
[@itzhoujun]: https://github.com/itzhoujun
[@nuc134r]: https://github.com/nuc134r
[@djnalluri]: https://github.com/djnalluri
[@domesticmouse]: https://github.com/domesticmouse


[#40]: https://github.com/TerminalStudio/xterm.dart/pull/40
[#43]: https://github.com/TerminalStudio/xterm.dart/pull/43
[#44]: https://github.com/TerminalStudio/xterm.dart/pull/44
[#45]: https://github.com/TerminalStudio/xterm.dart/pull/45
[#46]: https://github.com/TerminalStudio/xterm.dart/pull/46
[#47]: https://github.com/TerminalStudio/xterm.dart/pull/47
[#48]: https://github.com/TerminalStudio/xterm.dart/pull/48
[#49]: https://github.com/TerminalStudio/xterm.dart/pull/49
[#50]: https://github.com/TerminalStudio/xterm.dart/pull/50
[#51]: https://github.com/TerminalStudio/xterm.dart/pull/51


[#55]: https://github.com/TerminalStudio/xterm.dart/pull/55
[#60]: https://github.com/TerminalStudio/xterm.dart/pull/60
[#61]: https://github.com/TerminalStudio/xterm.dart/pull/61
[#62]: https://github.com/TerminalStudio/xterm.dart/pull/62
[#63]: https://github.com/TerminalStudio/xterm.dart/pull/63
[#66]: https://github.com/TerminalStudio/xterm.dart/pull/66
[#67]: https://github.com/TerminalStudio/xterm.dart/pull/67
[#69]: https://github.com/TerminalStudio/xterm.dart/pull/69
[#74]: https://github.com/TerminalStudio/xterm.dart/pull/74
[#77]: https://github.com/TerminalStudio/xterm.dart/pull/77

[#104]: https://github.com/TerminalStudio/xterm.dart/issues/104
[#123]: https://github.com/TerminalStudio/xterm.dart/pull/123
[#124]: https://github.com/TerminalStudio/xterm.dart/pull/124
[#125]: https://github.com/TerminalStudio/xterm.dart/pull/125
[#126]: https://github.com/TerminalStudio/xterm.dart/pull/126
[#127]: https://github.com/TerminalStudio/xterm.dart/pull/127
[#128]: https://github.com/TerminalStudio/xterm.dart/pull/128
[#129]: https://github.com/TerminalStudio/xterm.dart/pull/129
[#130]: https://github.com/TerminalStudio/xterm.dart/pull/130
[#131]: https://github.com/TerminalStudio/xterm.dart/pull/131
[#132]: https://github.com/TerminalStudio/xterm.dart/pull/132
[#135]: https://github.com/TerminalStudio/xterm.dart/pull/135
[#137]: https://github.com/TerminalStudio/xterm.dart/issues/137
[#138]: https://github.com/TerminalStudio/xterm.dart/pull/138
[#140]: https://github.com/TerminalStudio/xterm.dart/pull/140
[#141]: https://github.com/TerminalStudio/xterm.dart/pull/141

[#151]: https://github.com/TerminalStudio/xterm.dart/pull/151

[#160]: https://github.com/TerminalStudio/xterm.dart/pull/160
[#161]: https://github.com/TerminalStudio/xterm.dart/pull/161
[#169]: https://github.com/TerminalStudio/xterm.dart/pull/169

[#186]: https://github.com/TerminalStudio/xterm.dart/pull/186
[#190]: https://github.com/TerminalStudio/xterm.dart/pull/190
 
