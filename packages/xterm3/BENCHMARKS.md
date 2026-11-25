# Benchmarks

Baseline numbers for the render pipeline, and the procedure that produced them.
Every phase of the render plan was accepted or rejected against this table — a
change that does not move a number here has not been shown to do anything. The
plan itself, which the phase numbers below refer to, is retired and kept in
history: `git show 50f0211:RENDER_PLAN.md`.

## Running

```sh
cd example
flutter run --profile -d macos -t lib/benchmark.dart
```

Profile mode is mandatory. Debug-mode frame times are dominated by assertions
and are not comparable to anything a user sees; the misleading DevTools charts
that started this investigation were debug-mode charts.

The harness lives in `example/lib/benchmark.dart`. It drives the terminal with a
precomputed, fixed byte stream — one write per frame, no PTY, no shell — so two
runs on the same machine do the same work.

The grid is pinned to **100x37 cells**, not to a pixel size. Cell count drives
every cost in the paint path, and cell metrics are not stable across builds:
`fix(ui): size cells from a reference glyph, not the widest ASCII glyph` moved
them, so the 1000x600 viewport the first tables in this file were taken at
yields 100 columns on today's build and 102 on the published one. The harness
therefore bisects the viewport extent at startup until the terminal reports
exactly 100x37 and aborts the run if it cannot, rather than reporting numbers
from two different grids as if they were comparable.

Results print to the console prefixed with `[xterm3-bench]`.

To compare this working tree against an older commit:

```sh
script/bench-compare.sh [baseline-ref] [rounds]   # default 8d938de, 3 rounds
```

It puts the baseline in a git worktree, copies *this* tree's harness over it so
both sides run identical measurement code, and alternates the two builds. Runs
must be interleaved: sequential ones drift (see the `fullscreen` note below).
`example/lib/bench/bench_stats.dart` is the one harness file that differs
between the sides — the baseline gets `bench_stats_stub.dart`, because
`TerminalRenderStats` does not exist there. Frame timings come from
`SchedulerBinding` and are unaffected.

## Workloads

| Name | What it exercises |
|---|---|
| `plain` | Scrolling ASCII. Small glyph set, every lookup a paragraph cache hit after warm-up. |
| `sgr` | Same glyphs, heavy SGR churn. Much larger cache key space. |
| `boxdraw` | Box drawing and block elements — the procedural glyph path, which never touches the paragraph cache. |
| `fullscreen` | Cursor-addressed full-screen redraw on the alternate screen. Every cell rewritten every frame. The deterministic stand-in for htop. |
| `static` | A full screen drawn once, then **one cell** changes per frame. The damage-tracking workload. |
| `flood` | `cat bigfile`: chunks handed to `Terminal.write` as fast as the event loop takes them. Measures whether output starves the frame pipeline, not the paint path. |

`static` is the one to watch. It is the case where the renderer does the most
work it did not need to do, so it is where partial repaint has to show up. If a
change improves `fullscreen` but leaves `static` where it is, it did not
implement damage tracking.

## Baseline — 2026-08-05

Commit `6172f9a`, before any render pipeline changes.
Apple M1 Pro, macOS 26.5.1, Flutter 3.44.2 stable, profile mode.
Terminal grid 100x37 (3700 cells) at 1000x600 logical px.
400 measured frames per workload after 60 warm-up frames.

Frame times in milliseconds:

| workload | frames | UI p50 | p90 | p99 | raster p50 | p90 | p99 | over 16.7ms |
|---|---|---|---|---|---|---|---|---|
| plain | 416 | 1.0 | 1.1 | 1.4 | 1.6 | 1.9 | 2.3 | 0.0% |
| sgr | 408 | 1.7 | 1.9 | 2.0 | 2.0 | 2.1 | 2.3 | 0.0% |
| boxdraw | 408 | 2.4 | 2.6 | 2.8 | 3.3 | 3.5 | 3.6 | 0.0% |
| fullscreen | 408 | 1.7 | 2.2 | 2.6 | 1.9 | 2.5 | 2.9 | 0.0% |
| static | 408 | 1.6 | 1.8 | 1.9 | 2.5 | 2.6 | 2.8 | 0.0% |

Paint path counters (`TerminalRenderStats`), reset after warm-up:

| workload | paints | lines/paint | paragraph hit% | lookups/frame | glyph hit% | lookups/frame |
|---|---|---|---|---|---|---|
| plain | 400 | 38.0 | 100.0% | 2110 | — | 0 |
| sgr | 400 | 39.0 | 100.0% | 2496 | — | 0 |
| boxdraw | 400 | 38.0 | — | 0 | 97.1% | 2220 |
| fullscreen | 400 | 37.0 | — | 0 | 100.0% | 1831 |
| static | 400 | 37.0 | 100.0% | 3514 | — | 0 |

Flood: 32.2 MiB in 467ms (70.6 MiB/s), 23 frames rendered during the burst
(49.2 fps), worst UI frame 3.4ms.

### What the baseline says

**Rendering is not close to the frame budget.** Worst p99 across every workload
is 2.8ms UI and 3.6ms raster against a 16.7ms budget — 0.0% of frames go over,
on every workload. This corroborates the earlier profile-mode observation that
render sits at roughly 15% of the frame budget. Nothing in the paint path is
currently costing users frames on this machine.

**The waste damage tracking would remove is real but small in absolute terms.**
`static` changes exactly one cell per frame, yet still visits 37 lines and does
3514 paragraph cache lookups every frame, all of them hits. Its UI p50 (1.6ms)
is indistinguishable from `fullscreen`'s (1.7ms), which rewrites all 3700 cells
— the renderer genuinely cannot tell the two apart. Damage tracking would take
most of that 1.6ms, but 1.6ms out of 16.7ms is headroom that is already there.

**`boxdraw` is the most expensive workload, not `fullscreen`.** 2.4ms UI /
3.3ms raster, at a 97.1% glyph cache hit rate. The 2.9% miss rate is doing real
work: procedural glyphs rebuild vector paths on a miss. Raising that hit rate
is a cheaper, more targeted win than any of the render plan's phases.

**The flood number is the one that looks wrong.** 49.2 fps during a write burst
means output starves the frame pipeline — that is the unbounded parse-per-write
path, not the paint path. No amount of render work fixes it.

Taken together: the render pipeline plan targets a bottleneck the measurements
do not show. Phase 4 of the render plan — "measure, then decide" — can be
answered now rather than after building phases 1 through 3.

## Phase 1 — revision counters — 2026-08-05 — **not merged**

`BufferLine.revision` and `Buffer.viewportRevision` add an integer increment to
every cell write and every structural change to the line array. Same machine
and settings as the baseline above.

Kept on the `render-line-picture-cache` branch rather than merged: phase 3 was
its only consumer, and on master it would be a counter nobody reads, bumped on
hot paths like `setAsciiCells`.

| workload | UI p50 | p90 | p99 | raster p50 | p90 | p99 |
|---|---|---|---|---|---|---|
| plain | 0.9 | 0.9 | 1.0 | 1.4 | 1.5 | 1.7 |
| sgr | 1.5 | 1.7 | 1.9 | 1.8 | 2.1 | 2.2 |
| boxdraw | 2.3 | 2.4 | 2.6 | 3.2 | 3.4 | 3.5 |
| fullscreen | 2.0 | 2.3 | 2.5 | 2.2 | 2.6 | 2.8 |
| static | 1.6 | 1.8 | 1.9 | 2.6 | 2.8 | 2.9 |

Flood: 32.2 MiB in 439ms (75.2 MiB/s), 21 frames during the burst (47.9 fps).

Cache counters are identical to the baseline in every column, which is the
expected result: the counters observe mutations, they do not change them.

**No measurable cost.** Four of the five workloads came out *faster* than the
baseline, which adding work cannot do, so the increments sit under the noise.
See the run-to-run spread below before reading anything into a small delta.

## Phase 2 — paint pass split — 2026-08-05 — merged

`_paint` split into four passes plus a per-frame `_CursorPaintState`. Draw
calls are unchanged by construction and the golden tests confirm it, so any
movement here is either the extra call overhead or noise. Two runs, same
machine and settings.

| workload | UI p50 (run 1 / run 2) | raster p50 (run 1 / run 2) |
|---|---|---|
| plain | 1.3 / 1.0 | 2.1 / 1.7 |
| sgr | 1.6 / 1.7 | 2.2 / 2.4 |
| boxdraw | 2.3 / 2.3 | 3.3 / 3.3 |
| fullscreen | 2.1 / 2.2 | 2.3 / 2.3 |
| static | 1.6 / 1.7 | 2.6 / 2.7 |

Cache counters identical to both earlier tables.

These runs had phase 1's counters compiled in, since phase 2 was built on top
of phase 1. What master actually ships is phase 0 + phase 2 without them, and
that combination has not been measured on its own. Phase 1 measured as free, so
the difference should be nothing, but nobody has checked.

### Run-to-run spread, measured

Across the four runs now on record (baseline, phase 1, phase 2 ×2), `plain`
UI p50 came in at 1.0, 0.9, 1.3 and 1.0 — a 0.4ms spread with no code change
that could explain it, and its raster p50 spread 1.4 to 2.1. **Treat ±0.5ms on
p50 as noise, and more than that on p99.** An earlier note in this file put the
band at ±0.3ms; that was too tight.

This means the harness cannot currently resolve a change smaller than roughly
half a millisecond. Anything claiming a win under that needs repeated runs,
interleaved A/B rather than sequential, on an otherwise idle machine.

### One thing to watch

`fullscreen` UI p50 has gone 1.7 → 2.0 → 2.1 → 2.2 across the four runs in
order. That is a monotonic climb rather than a scatter, which noise does not
usually produce. It is also consistent with the machine warming up over an
afternoon of runs, and the runs were sequential rather than interleaved, so the
two cannot be separated from this data. Re-measure `fullscreen` from a cold
machine with the phase 1 and phase 2 commits checked out alternately before
concluding anything.

## Phase 3 — line picture cache — 2026-08-05 — **not merged**

Per-line `ui.Picture` recordings replayed while `BufferLine.revision` holds
still. Lives on the `render-line-picture-cache` branch and stays there; the
numbers below are why. Two runs.

| workload | UI p50 (1 / 2) | raster p50 (1 / 2) | line hit% |
|---|---|---|---|
| plain | 0.6 / 0.6 | 2.3 / 2.2 | 89.5% |
| sgr | 0.3 / 0.4 | 2.6 / 2.7 | 100% (see below) |
| boxdraw | 1.2 / 1.1 | 3.5 / 3.4 | 89.5% |
| fullscreen | 2.4 / 2.4 | 2.1 / 2.1 | 0.0% |
| static | 0.4 / 0.4 | 3.4 / 3.5 | 97.3% |

The cache does what it was built to do. `static` goes from 3514 paragraph
lookups per frame to 95, and its UI p50 from 1.7ms to 0.4ms — a 76% cut, well
outside the noise band. `fullscreen` hits 0% exactly as predicted: every line
changes every frame, so there is nothing to replay.

### Why it is not merged

Raster time went up everywhere the UI time went down, and by enough to matter:

| workload | UI + raster (phase 2 → 3) | max(UI, raster) (phase 2 → 3) |
|---|---|---|
| plain | 2.7 → 2.8 | 1.7 → **2.2** |
| boxdraw | 5.6 → 4.5 | 3.3 → 3.4 |
| fullscreen | 4.5 → 4.5 | 2.3 → 2.4 |
| static | 4.4 → 3.9 | 2.7 → **3.5** |

UI and raster run on separate threads and are pipelined across frames, so
sustained frame rate is bounded by the slower of the two, not their sum. Raster
was already the slower thread on every cache-friendly workload, and this change
makes it slower still — roughly 0.55ms of raster bought per 1ms of UI saved.
By that measure `static` gets **worse**, 2.7ms to 3.5ms, and `plain` worse by
0.5ms; both deltas repeat across the two runs, so neither is noise.

Read as single-frame latency (UI + raster) instead, `static` improves slightly,
4.4ms to 3.9ms. Both readings are defensible, and neither is actionable,
because no workload is anywhere near the 16.7ms budget in either model.

The cause is the one the plan predicted: 37 lines × 2 recordings is 74
`drawPicture` calls per frame, and Skia batches across a single command stream
better than across many small pictures.

The plan's own acceptance criterion for this phase was "if raster goes up and
build goes down, there is no net win — revert phase 3." That is what the
measurements say, so the branch stays unmerged.

### The `sgr` row is not trustworthy in any phase

`sgr` reports 100% line hits and zero paragraph lookups, meaning no foreground
was recorded across 400 frames — impossible for a workload writing three fresh
lines per frame. The cache is not the culprit:
`test/src/ui/line_picture_cache_test.dart` covers re-recording on revision
change, on a new line object and after a cache clear, and a standalone replay
of `sgr`'s exact byte stream through the cached painter behaves identically to
`plain` (433 misses and 21312 paragraph lookups over 100 frames).

The likely explanation is that `sgr`'s viewport is not following the scroll in
the benchmark, so the visible lines genuinely never change. That would have
been just as true in phases 0-2, where a frozen viewport still costs full-price
lookups every frame and so looked normal. Until that is confirmed, treat the
`sgr` row as measuring an unknown, in every table in this file.

## Against the published package — 2026-08-05

`8d938de` (head of `klc/xterm3` master, 2026-07-28) versus `d6f7b59`,
73 commits later. Apple M1 Pro, macOS 26.5.1, Flutter 3.44.2 stable, profile
mode, three interleaved rounds per build via `script/bench-compare.sh`.

Both builds measured a 100x37 grid — which is the only reason the table means
anything. At a fixed 1000x600 viewport the published build lays out **102**
columns to this build's 100, because cell width changed from 7.86px to 8.00px.
Comparing those two runs directly would have credited this build with a 2%
smaller grid.

Median of three rounds, milliseconds. Within-build spread was at most 0.2ms on
every cell below, so unlike the phase tables in this file, differences of 0.3ms
are outside the noise here.

| workload | UI p50 pub → now | raster p50 pub → now |
|---|---|---|
| plain | 1.3 → **0.8** | 1.5 → **1.3** |
| sgr | 2.2 → **1.4** | 1.8 → 1.6 |
| boxdraw | 2.1 → 2.2 | 2.7 → **3.0** |
| fullscreen | 1.2 → 1.4 | 1.4 → 1.6 |
| static | 2.4 → **1.5** | 2.4 → 2.1 |

Flood, MiB/s across the three rounds: 72.9 / 66.8 / 67.5 published,
74.6 / 71.8 / 75.1 now. Every pairwise round favours the newer build, by around
7%. Nothing in these 73 commits touched the parse loop, so read this as the
write path being marginally less obstructed, not as the unbounded-parse-per-
write problem having moved. It has not.

### What moved

**The cached text path got a third faster.** `plain` UI p50 1.3 → 0.8, `sgr`
2.2 → 1.4, `static` 2.4 → 1.5. The three commits that can account for it are
`21c8773` (no defensive listener copy per `Terminal.write`), `53ae0e3` (O(1)
paragraph cache eviction) and `c3051b7` (cached procedural glyph rasters). All
three are on the per-frame path these workloads sit in.

**The procedural glyph path got slower to rasterise.** `boxdraw` raster
2.7 → 3.0, `fullscreen` raster 1.4 → 1.6, and both are repeatable across all
three rounds with no overlap between the builds. This is the opposite of what
`c3051b7` was supposed to do, and it is the one result here worth chasing:
replaying a cached `ui.Picture` per glyph appears to cost the raster thread
more than re-tesselating the path cost it, even at a 97.1% hit rate. Note that
`3e9266c` also changed how heavily box-drawing bars are stroked, so some of the
extra raster work is extra pixels rather than extra draw calls — the two have
not been separated.

Neither direction matters to a user yet: the worst number in the table is
3.0ms against a 16.7ms budget, and no workload put a single frame over budget
on either build.

### At a full-screen grid, where the differences are visible

3700 cells is a small window. Re-run at **170x50 (8500 cells)**, the size a
maximised terminal actually is, and the same commits look different — every
paint-path cost scales with cell count, so both the wins and the regression
scale with it. Same three-interleaved-rounds procedure, medians, and the
within-build spread stayed at 0.1-0.2ms.

| workload | UI p50 pub → now | raster p50 pub → now |
|---|---|---|
| plain | 2.1 → **1.6** | 2.4 → 2.6 |
| sgr | 3.0 → **1.9** | 2.4 → 2.6 |
| boxdraw | 2.9 → **2.6** | 3.6 → 3.9 |
| fullscreen | 3.0 → 3.0 | 3.2 → 3.2 |
| static | 5.1 → **2.7** | 8.6 → **4.5** |

`static` is the headline: raster p50 halves, 8.6ms to 4.5ms, and UI drops 47%.
At 3700 cells the same commits moved it by under a millisecond and it read as
noise-adjacent; at 8500 it is a quarter of the frame budget on the raster
thread. Flood is unchanged at about 55 MiB/s on both builds — the grid is
bigger, so more of each burst goes into painting, and nothing here touched the
parse loop anyway.

The remaining `boxdraw` raster gap is **not** a regression. It survives with
the glyph cache compiled out entirely, and it is explained by cell size: the
same 170 columns come out 1366.8px wide on this build against 1330.9px on the
published one, so 2.7% more pixels are rasterised per frame. 3.6 x 1.027 = 3.7.

### The glyph cache defect this run found

The first 170x50 run had `boxdraw` UI p50 at **4.6ms** against the published
build's 2.9ms, and `fullscreen` raster at 3.6ms against 3.2ms. Both were
`c3051b7`, the procedural glyph cache, and both are fixed above. Two separate
faults:

**The cache was too small to hold one screen, and a miss cost more than not
caching.** Keys are (codepoint, cell size, colour), so `boxdraw`'s 15 glyphs
across 256 colours reach 3840 live keys against a 512-entry cache. The hit rate
fell from 97.1% at 3700 cells to **75.0%** at 8500, and because a miss pays for
the recording and the insert *on top of* the drawing, the cache made the build
1.9ms per frame slower than painting uncached. Capacity is now 4096. Measured
at 8192 for comparison: 99.9% hit, and no further gain over 4096's key space.

**Block elements should never have been cached.** `U+2580..U+259F` are one or
two `drawRect` calls. Recording that into a `Picture` and replaying it per cell
puts a picture boundary in the raster command stream for every cell, and Skia
batches worse across many small pictures than across one stream — the same
effect that sank phase 3 above. On `fullscreen`, which is entirely `U+2588` at
a 100% hit rate, the cache cost 0.4ms of raster per frame and saved nothing on
the UI thread. They now bypass the cache, and `fullscreen` is back to parity
with the published build on both threads.

The general lesson, and it is the second time this file records it: **a cache
that hands the raster thread more, smaller pictures is not free, and has to be
measured on the raster thread, not just on the UI thread.**

### Correctness, which is where most of the 73 commits went

Running this build's test suite against the published library:

| | published `8d938de` | now `d6f7b59` |
|---|---|---|
| tests run | 391 | 809 |
| failures | 20 | 0 |

Five of those 20 are whole files that do not compile against the published
library — `painter_test`, `render_test`, `render_stats_test`,
`android_ime_input_test` and `terminal_test` — so the tests inside them never
ran, and 391 is an undercount rather than a comparable total. The 15 that ran
and failed are the regressions the commits since then fixed: wide-char
lead/placeholder corruption (five, from the fuzz harness), Kitty keyboard
release and modifier reporting (three), mobile IME double-insertion and
backspace-at-zero (two), `TerminalView.textScaler` (two), default pointer
input reporting, box-drawing stroke weight, and a colour golden.

## The write path — 2026-08-06

`flood` says output starves the frame pipeline, but it cannot say which part of
the write path is paying, because it measures the parser, the buffer writes it
drives and the repaints it schedules all at once. `bin/parse_bench.dart` splits
them, with no Flutter and no renderer:

```sh
dart compile exe bin/parse_bench.dart -o /tmp/parse_bench && /tmp/parse_bench
```

Compile it — JIT numbers are not comparable to what ships. 32 MiB per workload
in 8 KiB chunks, 170x50 grid, Apple M1 Pro.

| workload | full | parser | buffer% | no scrollback | no graphemes |
|---|---|---|---|---|---|
| ascii | 108 | 439 | 75% | 143 | 108 |
| ascii-long-lines | 125 | 699 | 82% | 174 | 126 |
| sgr | 55 | 100 | 45% | 67 | 56 |
| utf8 | 60 | 260 | 77% | 70 | 82 |
| cyrillic | 87 | 286 | 70% | 116 | 88 |
| altscreen | 136 | 226 | 40% | 138 | 138 |

MiB/s. `full` is `Terminal.write`; `parser` is the same bytes through
`EscapeParser` with a handler that does nothing; the other two columns turn off
scrollback and DEC mode 2027 respectively.

Medians of three interleaved rounds, taken on `master` after phase 6.1. The
absolute values are lower across the board than the tables further down this
file, which were taken on a faster day on the same machine — day-to-day drift
on this hardware runs to about 20%, so read a row against its own table and
never across two of them.

**The parser is not the bottleneck, except on `sgr`.** Plain text parses at
439 MiB/s and the full path manages 108, so 75% of the time is what the
terminal does per token. `sgr` is the exception: 100 MiB/s through the parser
alone means CSI dispatch itself is the ceiling there, and no amount of buffer
work will move it. Three attempts at the CSI parameter loop confirmed that from
the other side - see phases 5.4 and 5.5 of the render plan, and
`script/csi_param_census.dart` for why no fourth is worth writing.

**Scrolling still costs about a third.** `ascii` at 108 against 143 with
scrollback disabled, and `altscreen` — which never scrolls — runs at 136. A
line of output allocates a `BufferLine`, and its cell storage is a
`Uint32List`. Two things have been taken off that bill. Capacity rounding was
the cheap part: `_calcCapacity` doubled from 64, so a 170-column line reserved
256 cells and addressed 170; rounding to 32 instead took `ascii` from 92 to 103
MiB/s and long lines from 129 to 149. The larger part was the size of the store
itself, which phase 6.1 addressed by letting the first write size it instead of
allocating at viewport width — `ascii` +18%, `cyrillic` +19%, `utf8` +24%, at
the cost of 13% on `sgr`.

What is left of the gap is not work a faster path can skip. It is the garbage
collector holding the retained lines: phase 7 of the render plan measured that
`IndexAwareCircularBuffer.push` does *less* work at a depth of 10000 than at
50, and is slower anyway. Recycling the storage does not work either — see
below.

**Non-ASCII text used to run at a sixth of ASCII speed.** Both causes are
fixed below; the table above is after those fixes.

### Grapheme clustering no longer costs Latin text anything

`utf8` measured **15 MiB/s** before this section was written, against a
34 MiB/s ceiling with mode 2027 turned off — grapheme detection was more than
half the cost of writing Turkish, and by extension of every non-English
language written in Latin script.

`_joinsPreviousGrapheme` had a fast path for the case where the previous cell
and the incoming code point are both ASCII. One accented letter breaks it: with
`ö` in the previous cell, every following character fell through to real
grapheme segmentation, which allocates two strings and segments both of them.
Nothing below U+0300 can continue a grapheme cluster — the first combining
marks live there, and everything else that can extend a cluster (SpacingMark,
ZWJ, regional indicators, emoji modifiers, Hangul V and T) sits higher — so the
cut is now made on the code point, and Latin text never reaches the segmenter.
The same cut lets `writeChar` skip both cluster checks outright.

15 → 32 MiB/s, against a 35 MiB/s ceiling. What was left is the per-code-point
path, dealt with next.

### Batched writes for alphabets other than English

The parser batches a run of printable ASCII into one `writeText` call and hands
everything else to `writeChar`, one code point at a time. So the first accented
letter ended the run, and every letter after it started a run of its own — an
alphabet that is *entirely* non-ASCII never batched at all. Cyrillic measured
**6 MiB/s**, a fifteenth of ASCII.

`isSingleCellPrintable` now defines the run: ASCII, Latin-1, Latin Extended-A
and B, IPA, spacing modifiers, Greek, Cyrillic and Armenian, minus the two
combining blocks inside that span and U+00AD. Every code point in it is width 1
and cannot continue a grapheme cluster, which is exactly what a batched write
needs in order to skip the width table and the cluster rules. The same
predicate replaces the U+0300 cut in `writeChar`, so a single such character
outside a run is just as cheap.

Cyrillic 6 → 73 MiB/s. Turkish 32 → 54, where the rest of the gap to ASCII is
the em dashes and other punctuation the ranges leave out. CJK is deliberately
not in this set: it is width 2 and needs the path that allocates a lead cell
and a placeholder.

### Pacing the write path — measured, offered as opt-in

`flood` writes chunks as fast as the event loop takes them, which is what a PTY
stream listener does. At 170x50 that drains 32 MiB in 566ms and produces 37
frames per second while it does — the burst spends about 89% of its time
parsing and 11% painting, so frames happen in whatever gaps parsing leaves.

The harness now also measures a paced variant: parse until a budget is spent,
hand the thread back, repeat.

| mode | drain | throughput | frames | worst UI frame |
|---|---|---|---|---|
| unpaced | 566ms | 58.3 MiB/s | 37.1 fps | 3.2ms |
| paced, 8ms budget | 854ms | 38.6 MiB/s | **74.9 fps** | 1.9ms |
| paced, 4ms budget | 1068ms | 30.9 MiB/s | 74.9 fps | 1.4ms |

Pacing doubles the frame rate to the display's full refresh rate, and costs
about 50% in drain time. 4ms buys no more frames than 8ms and only drains more
slowly, so 8ms is the default in `PacedTerminalWriter`, which is the opt-in
this measurement produced. Nothing in the package uses it by default: which
side of that trade an application wants is not the package's call.

Note what this is not: the unpaced case was never freezing. Its worst UI frame
during the burst is 3.2ms. The frame rate is low because parsing owns the
thread between frames, not because any single frame is slow.

### Recycling evicted lines — measured, rejected

The obvious answer to the scrolling cost is to blank the line that just fell
off the scrollback and push it back on, instead of allocating a replacement.
Implemented as `BufferLine.reset` plus a bounded pool in `Buffer`, it made
`ascii` **worse**: 92 → 41 MiB/s zeroing the whole capacity, 92 → 52 zeroing
only the live cells. The VM's allocator hands out typed data that is already
zeroed, and clearing 3 KiB by hand costs more than asking for a fresh one.

Anything else aimed at the scrolling cost has to reduce the *number* of lines
allocated or their size, or find a way to reuse one without clearing all of it.

Two things this experiment settled without a further run. First, its own
numbers answer how much of the scrollback penalty is allocation: pooling
without the clear recovers 63% of it on `ascii`, 84% on `cyrillic` and 93% on
`utf8`. Nearly all of it. Second, the explanation offered above — that the VM
hands out typed data the OS already zeroed — needed checking before a second
attempt, because whether clearing only the written span can pay depends on it.
It was checked, and it holds: see "Recycling evicted lines, take two" below.

## Where it stands against the published package — 2026-08-06

Everything above, re-measured against `8d938de` after the render and write-path
work was done. Render: three interleaved rounds at 170x50, medians, spread
0.1-0.2ms within a build. Write path: `bin/parse_bench.dart` compiled against
each build, 32 MiB per workload.

### Frame times, milliseconds

| workload | UI p50 pub → now | raster p50 pub → now |
|---|---|---|
| plain | 2.1 → **1.6** | 2.3 → 2.5 |
| sgr | 3.0 → **1.8** | 2.4 → 2.5 |
| boxdraw | 2.8 → **2.5** | 3.5 → 3.9 |
| fullscreen | 3.0 → 3.0 | 3.1 → 3.1 |
| static | 5.1 → **2.7** | 8.7 → **4.5** |

### Write path, MiB/s

| workload | pub | now |
|---|---|---|
| ascii | 93 | **103** |
| ascii-long-lines | 131 | **146** |
| sgr | 74 | 76 |
| utf8 (Turkish) | 16 | **57** |
| cyrillic | 6 | **84** |
| altscreen | 172 | 169 |

### Draining 32 MiB into a 170x50 grid

| | pub | now |
|---|---|---|
| unpaced | 596ms, 32 fps, worst UI 4.9ms | **532ms, 41 fps**, worst UI 4.0ms |
| paced 8ms | 855ms, 75 fps, worst UI 4.2ms | **761ms**, 75 fps, worst UI **1.9ms** |
| paced 4ms | 1563ms, 75 fps | **1068ms**, 75 fps |

Unpaced is both faster to drain and smoother than the published build, which is
the write-path work showing up. Paced is available on both builds — the harness
provides the pacing — and the published build pays for its slower parser there
too, taking 12% longer at an 8ms budget and 46% longer at 4ms.

### What has not moved

`sgr` is unchanged in every table: 74 → 76 MiB/s on the write path, and the
parser alone caps it at 99 — see "The `parser` column was wrong until
2026-08-29" below, which re-measures that cap at 121 and cuts the parser's
share of `sgr` from 77% to 64%. Nothing here touched CSI dispatch either way. `altscreen` is unchanged because it neither scrolls nor allocates
lines. `fullscreen` frame times are at parity by design — the glyph cache
regression that had moved them was removed rather than tuned.

The `boxdraw` raster gap is not a regression: it survives with the glyph cache
compiled out, and 170 columns are 1366.8px wide on this build against 1330.8px
on the published one, so 2.7% more pixels are rasterised per frame.

## The `parser` column was wrong until 2026-08-29

Every `parser` number above this line, and every `buffer%` derived from one, was
measured with a no-op handler that implemented `writeChar` and `writeText` and
let the other 233 `EscapeHandler` members fall through to `noSuchMethod`. Each
of those calls allocated an `Invocation` and boxed its arguments, so the column
charged the parser for work the real `Terminal` never does.

The comment justifying it said escape sequences are rare per byte. The workload
generators in the same file disagree: `ascii` reaches a handler about 22,000
times per MiB through `\r\n` alone, and `sgr` about 50,000 times.

`bin/noop_escape_handler.dart` now implements every member explicitly, with no
`noSuchMethod`, generated from the declarations by `script/gen_noop_handler.dart`.
Leaving `noSuchMethod` out is the point: `implements` without it turns a member
the benchmark has not caught up with into an analyzer error rather than a
quietly poisoned number.

### Old and new, medians of three runs each

| workload | full | parser | buffer% | scrollback | no-grapheme |
|---|---|---|---|---|---|
| ascii | 107 → 105 | 437 → **568** | 76 → **82** | 173 → 171 | 105 → 107 |
| ascii-long-lines | 149 → 151 | 824 → **910** | 82 → **84** | 230 → 227 | 148 → 149 |
| sgr | 76 → 77 | 99 → **121** | 23 → **36** | 86 → 88 | 75 → 77 |
| utf8 | 58 → 59 | 267 → **333** | 78 → **82** | 86 → 86 | 70 → 69 |
| cyrillic | 85 → 85 | 294 → **360** | 71 → **76** | 140 → 139 | 83 → 86 |
| altscreen | 172 → 170 | 232 → **279** | 26 → **39** | 174 → 175 | 174 → 175 |

`full`, `scrollback` and `no-grapheme` all run against the real `Terminal` and
never touched `noSuchMethod`. They are unmoved across three runs each, which is
the control the change had to pass: only the intended column moved.

Backing the artifact out of the column difference gives 22-24 ns per
zero-argument handler call and 37-44 ns per call carrying arguments — consistent
with an `Invocation` allocation plus argument boxing, and the reason the
artifact weighed on `sgr` about 2.3x what it weighed on `ascii`.

### What this changes

The buffer's share of the write path is **larger** than the earlier tables said,
not smaller: 82-84% on plain text, and 36-39% even on the two escape-heavy
workloads. `sgr` is still the most parser-bound workload and its parser column
is still by far the slowest at 121 MiB/s, but the "SGR is 77% parser" reading
was really 64%.

What did not change: `sgr`'s full-path throughput, and the cost of retaining
scrollback. Both come from columns the defect never touched.

## Taking the surrogate decode off `consume()` — 2026-08-29

`ByteConsumer.consume()` called `_decodeCodePoint` and `_codePointCodeUnitLength`
per code point, and both re-ran the same high-surrogate test to reach the same
answer. Testing once and returning early covers everything outside astral text.

Measured as an interleaved A/B — three rounds of each binary, alternating, so
thermal drift lands on both conditions. A first attempt that ran the two
conditions back to back was thrown away: columns that never touch `consume()`
moved 4-8% with it, which is drift, not signal.

| workload | full | parser | scrollback | no-grapheme |
|---|---|---|---|---|
| ascii | 105 → 106 | 567 → 579 | 166 → 172 | 106 → 103 |
| ascii-long-lines | 152 → 152 | 916 → 922 | 225 → 226 | 148 → 149 |
| sgr | 76 → **81** | 121 → **133** | 85 → 88 | 76 → **80** |
| utf8 | 58 → 59 | 334 → 342 | 86 → 86 | 69 → 69 |
| cyrillic | 85 → 85 | 348 → 364 | 140 → 138 | 85 → 85 |
| altscreen | 171 → **178** | 276 → **296** | 174 → **182** | 175 → **182** |

The gain is concentrated on the two escape-heavy workloads, which is where
`consume()` is hot. Plain text goes through `printableTextRunLength` and
`consumeAsciiCodeUnits` instead and barely reaches it. Nothing regressed in any
of the 24 cells, and the two conditions do not overlap on `sgr` (76/76/77
against 80/81/82) or `altscreen`'s parser column (272/276/279 against
296/296/300).

### The baseline after this

| workload | full | parser | buffer% | scrollback | no-grapheme |
|---|---|---|---|---|---|
| ascii | 106 | 579 | 82% | 172 | 103 |
| ascii-long-lines | 152 | 922 | 84% | 226 | 149 |
| sgr | 81 | 133 | 39% | 88 | 80 |
| utf8 | 59 | 342 | 82% | 86 | 69 |
| cyrillic | 85 | 364 | 77% | 138 | 85 |
| altscreen | 178 | 296 | 40% | 182 | 182 |

This also prescreened CSI bulk scanning, which was the point of doing it first:
`consume()` was carrying real cost, so that candidate survives. Its ceiling
narrowed though - the same derivation now puts CSI at **at most** ~17 ns per
character, down from ~19, and that bound still contains the CSI handler's own
parameter walk and dispatch rather than `consume()` alone.

## Recycling evicted lines, take two — measured, rejected again — 2026-08-29

The first attempt cleared the whole capacity with `fillRange` and lost. The
obvious repair was to clear only what the line had actually written. Measured
with `script/line_reuse_probe.dart` before building anything, because the
repair only makes sense if allocation's zeroing is genuinely free.

A `BufferLine` at 170 columns is `Uint32List(192 * 4)` — 3072 bytes, not the
680 an earlier note claimed. Per line, on an M-series macOS:

| | ns per line | ns per word |
|---|---|---|
| allocate | 92 | **0.12** |
| indexed store loop | — | **0.475** |
| `fillRange` | — | **1.6** |

Allocating is four times cheaper per word than the cheapest thing that actually
writes those words, so allocation is not writing them. The explanation offered
for the first attempt was right.

The consequence, with `written` as the cells a line holds text in out of a
192-cell capacity, and `loop-tail` clearing only the span between the new write
extent and the previous high-water mark — the best form of the design:

| written | alloc | fill-all | fill-written | loop-written | loop-tail |
|---|---|---|---|---|---|
| 30 | 153 | 1287 | 251 | 161 | 197 |
| 60 | **199** | 1323 | 492 | 307 | 242 |
| 120 | **304** | 1445 | 988 | 611 | 340 |
| 192 | 450 | 1565 | 1565 | 1023 | **355** |

Pooling wins only at full width, and only because there is nothing left to
clear there — what it wins is exactly the 92 ns of allocation. Across the
middle widths, where shell output sits, it loses. The prediction that a bounded
clear "pays on typical short shell lines" came out backwards: a short line
leaves a *long* tail to clear, because the line under it was wider. Pool depth
does not matter — 8, 64 and 512 give the same table.

So the closing line of the first attempt stands unchanged: anything aimed at
the scrolling cost has to reduce the *number* of lines allocated or their size,
not try to reuse them.

One finding with no use here: `fillRange` costs 3.4x an indexed store loop, so
it does not lower to a memset. `BufferLine.eraseRange` already clears cell by
cell, and the only other `fillRange` calls in `lib/` are one-time table setup —
recorded so nobody puts one on a hot path later.

## CSI parameter bulk scanning — measured, rejected — 2026-08-29

The candidate the write-path briefing opened with: CSI parameters are ASCII
digits, so scanning a run of them should beat calling `ByteConsumer.consume()`
per digit the way the printable-text path already does. Two implementations,
both slower than what they replaced.

A free experiment first. The digit case sat seventh in `_consumeCsi`'s branch
chain, and digits are about two thirds of the parameter bytes; none of the six
tests before it can match 0x30-0x39, so hoisting it is semantically identical.
It measured **nothing** — `sgr` parser 133 → 132, `altscreen` 297 → 299, both
inside the noise. The branch chain is not what a CSI byte pays for.

| | sgr full | sgr parser | altscreen full | altscreen parser |
|---|---|---|---|---|
| baseline | 81 | 132 | 179 | 298 |
| run scanner + bulk advance | 74 | 115 | 166 | 267 |
| scan and accumulate fused | 77 | 121 | 170 | 278 |

The first version scanned the run in one getter and accumulated it in another
loop, which cost four separate `_advancePastConsumedBlocks()` calls per run and
read every digit twice. Fusing the two loops recovered about half of the loss
and still landed 8% below the baseline, with the two conditions disjoint across
three interleaved rounds.

The reason is that the fast path merged earlier the same day left nothing to
batch. `consume()` is now one normalisation compare, one block read, one
`codeUnitAt` and four field updates. The bulk path replaces `run` of those with
an emptiness check, two getters that each normalise again, a limit computation,
a scan loop, and a `consumeAsciiCodeUnits` that normalises a third time. In
`sgr` a sequence averages 9.6 bytes and its parameters are one to three digits;
with the first digit already consumed, the bulk path is left with about 1.5
digits to amortise all of that over. It cannot.

Worth keeping from the attempt: the fuzzer earns its place. The fused version
initially called `currentBlock` unguarded, which throws `StateError` when the
digit just consumed was the last byte of the chunk.
`test/src/core/escape/parser_fuzz_test.dart` caught it on three separate seeds.
Anything reaching into the queue after `consume()` inside the CSI loop has to
assume the queue may now be empty.

## Where the scrollback cost actually is — 2026-08-29

The `scrollback` column runs with `maxLines: 0`, which `Buffer` widens to
`max(maxLines, viewHeight)`. The ring is still 50 lines, the allocation per
scroll is the same and so is the eviction bookkeeping — the only thing that
changes is how many lines stay alive. On `ascii` that column is worth 328 ns
per line and `line_reuse_probe` put allocation on its own at 92 ns, so
`script/scrollback_cost_probe.dart` went looking for the other 236.

It is the live set. A line writing 30 cells costs 151 ns with 50 alive and
**561 ns with 10000 alive** — the collector promoting each line's 3072-byte
backing store into old space, at a copy proportional to the store rather than
to the text in it.

| depth | live | w=30 | w=60 | w=120 | w=192 |
|---|---|---|---|---|---|
| 50 | 0 MB | 151 | 174 | 274 | 388 |
| 1000 | 3 MB | 169 | 203 | 307 | 424 |
| 4000 | 12 MB | 285 | 326 | 415 | 533 |
| 10000 | 29 MB | 561 | 629 | 767 | 814 |

So the lever is line size, which is the half of Phase 5's closing line nobody
had tried. Allocating each line at `_calcCapacity` of the width it actually
writes, at 10000 deep: 561 → 180 at 30 cells, 629 → 345 at 60, 767 → 590 at
120. It would also take scrollback's resident cost from 30 MB down to roughly
10-15 MB on a realistic mix.

### Trimming on the way into scrollback does not work

The obvious form, and the one with the narrow blast radius: keep the line at
full capacity while it is in the viewport, give it a right-sized store when it
drops into scrollback. Nothing in the write path changes, the painter already
drives off `line.length`, `getText` skips zero code points so its output is
unchanged, and `Buffer.resize` already grows lines back on a window change.

`script/trim_variant_probe.dart` says no, in every cell measured:

| depth | written | today | trim | born small |
|---|---|---|---|---|
| 1000 | 30 | 171 | 224 | 79 |
| 1000 | 95 | 248 | 336 | 186 |
| 10000 | 30 | 544 | 601 | 181 |
| 10000 | 95 | 646 | 819 | 394 |
| 10000 | 120 | 691 | 970 | 581 |

Trimming spends an allocation and a copy of the small store to save promoting
the large one, and the two are the same order of magnitude. The saving is in
never allocating the large store, not in handing it back. Recorded because this
is the form of the idea that looks best on paper.

Not implemented: a line born at the 64-cell floor and grown from inside
`BufferLine`'s own write methods. Ceiling measured at 1.2-3.0x, cost on the
per-code-point write path unmeasured.

## Costs of a code review's findings — 2026-08-29

A review flagged thirteen things by inspection. Nine held up against the code;
`bin/review_bench.dart` then measured the ones that are measurable, because
inspection cannot tell a finding that costs a microsecond a minute from one
that costs a millisecond a frame. Numbers are medians of five, interleaved
before and after.

| finding | before | after |
|---|---|---|
| `wholeWord` search, matches abutting word chars | 14.3 ms | **12.9 ms** |
| `wholeWord` search, matches at word boundaries | 7.2 ms (+10% over plain) | **6.6 ms (+1%)** |
| `urlAt` per pointer hover | 1.3-1.9 us + ~3 KB | **not run while the modifier is up** |
| editable rect reports per 50 writes | 50 ancestor walks | **1, at the next paint** |
| `runes.length` + `runes.first` per keystroke | 25 ns | **3 ns** |
| `isSemanticPromptLine`, 1000 prompts queued | 14.5 us | 19.4 us |
| reflow 10000 lines, one anchor each | 199-214 ns/line | 204-249 ns/line |
| OSC 52 clipboard, 8 KiB payload | 12.6 ns/byte | 12.7 ns/byte |

The last three are the honest part of the table.

**Reflow anchors and the OSC rejoin measured neutral.** `BufferLine.anchors`
really does allocate an `UnmodifiableListView` per call and reflow really did
call it inside its copy loop, and `_osc.sublist(n).join(';')` really does
allocate a list to copy strings that mostly did not need copying. Both are now
avoided, and neither shows up in the timing. They are kept because they remove
provably dead work and because `hasAnchors` is the API the code wanted, not
because they made anything faster - and this table is where that is written
down rather than implied.

**The semantic prompt queue got slower, deliberately.** The prune only dropped
stale anchors from the front, so anchors that went stale in the middle stayed.
That is not just wasted scanning: the queue is capped at the buffer's line
count and the cap evicts from the front, so enough stale entries push a
still-valid prompt out and the terminal forgets a prompt that is on screen.
`terminal_test.dart` has that as a regression test, and it fails against the
old prune. The full sweep costs one extra traversal of the queue - 5 us at
1000 queued prompts - on a path that only `ui/shortcut/actions.dart` reaches,
from a keyboard shortcut. Not a frame path.

**Two flagged items were left alone.** `_csi.params` could be a fixed
`Int32List` instead of a growable list, but Phase 5.4 measured that whole loop
and found reordering it worth nothing and batching it worth -8%, so there is no
reason to expect this one to pay. And `PacedTerminalWriter`'s unbounded queue
is real, but bounding it means either dropping output or a threshold mode with
an API surface - recorded as Phase 7, not something to slip into a cleanup.

## Against `xterm` and `xterm2` — 2026-09-03

The tables above compare this tree against its own earlier commits. This one
compares the published packages the line came from, which is the comparison a
reader of the README is actually asking about.

`script/cross_bench/` is its own package so that it can depend on all three at
once. Each is driven through `package:<name>/core.dart` — the headless half,
no Flutter — and all three expose the same `Terminal(maxLines:)`, `resize`,
`write`, so one harness reaches them with nothing per-package in the measured
path. Versions: `xterm` 4.0.0, `xterm2` 5.2.0 (the last published on that
line), `xterm3` 6.3.0. Grid 170x50, 10000 lines of scrollback, 32 MiB per
workload in 8 KiB chunks, AOT-compiled. Apple M1 Pro, macOS 26.5.1, Dart
3.12.2. One package per process; three interleaved rounds, medians below. The
spread across rounds was under 2% on every cell.

### Throughput, MiB/s

| workload | `xterm` 4.0.0 | `xterm2` 5.2.0 | `xterm3` 6.3.0 | vs `xterm` |
|---|---|---|---|---|
| ascii | 15.8 | 86.6 | **113.4** | 7.2x |
| ascii-long-lines | 16.6 | 117.8 | **135.5** | 8.2x |
| sgr | 18.8 | **60.8** | 57.4 | 3.1x |
| utf8 (Turkish) | 15.4 | 14.2 | **63.5** | 4.1x |
| cyrillic | 14.8 | 5.5 | **90.4** | 6.1x |
| altscreen | 19.2 | 133.2 | **139.1** | 7.2x |

`sgr` is the one row where `xterm3` is behind `xterm2`, by 6%, and it is a
known price rather than a surprise: 6.3.0's born-small `BufferLine` sizes a
line's store from its first write, and an SGR-heavy line arrives as several
short runs between colour changes, so a later run has to grow the store. The
6.3.0 changelog records the two alternatives measured against it, at -22% and
-14% elsewhere.

`utf8` and `cyrillic` are where the distance is real rather than incremental.
Both older packages leave the batched write path at the first non-ASCII letter,
so a language not written in ASCII never batches at all — `xterm2` is *slower*
than `xterm` on Cyrillic because the rest of its write path got faster around a
per-code-point loop that did not.

### Scrollback residency, MiB

10000 lines of `ls -l`-shaped output retained at a 170-column window, resident
set after the collector has been given its chances, minus the same process
before the terminal existed. Medians of five.

| | `xterm` 4.0.0 | `xterm2` 5.2.0 | `xterm3` 6.3.0 |
|---|---|---|---|
| scrollback RSS | 85.8 | 79.3 | **52.8** |

Lines here are about 90 columns wide in a 170-column window, so this is the
case born-small storage was built for: the line no longer reserves the 80
columns it never reaches.

### Resize reflow, ms

One narrow-and-restore pair (170 → 80 → 170 columns) with the scrollback full,
which rewraps all 10000 retained lines twice. Median of three runs of ten.

| | `xterm` 4.0.0 | `xterm2` 5.2.0 | `xterm3` 6.3.0 |
|---|---|---|---|
| per resize pair | 10.6 | 4.7 | **4.6** |

`xterm3` and `xterm2` are level here; the 2.3x is against `xterm`. Reflow has
not been worked on since, and this row is here to say so.

### What this does not measure

Everything above the terminal core. No renderer, no Flutter, no PTY — the
`flood` workload in the tables above is what says whether output starves the
frame pipeline, and it only exists for this tree. A cross-package render
comparison would need three example apps whose cell metrics agree, and cell
metrics are the thing this file already records as not stable across builds.

## Adding a workload

Workloads are lists of per-frame strings built by a `_*Frames` function and
registered in `_run()`. Pass `setup:` for screen content that should be written
once before measurement rather than counted as per-frame work, and
`enterAltScreen: true` for anything that should not touch scrollback. Keep
generators deterministic — no clocks, no randomness without a fixed seed —
or the numbers stop being comparable between runs.
