// Throughput of the write path, with no Flutter and no renderer.
//
//   dart compile exe bin/parse_bench.dart -o /tmp/parse_bench && /tmp/parse_bench
//
// JIT numbers (`dart run`) are not comparable to what ships; compile it.
//
// The Flutter benchmark's `flood` workload reports about 55 MiB/s and roughly
// 49 fps during a write burst, which says output starves the frame pipeline.
// That number mixes three things together: the parser, the buffer writes it
// drives, and the repaints it schedules. This tool separates them, so a change
// can be aimed at whichever one is actually paying.
//
// Every workload is fed in 8 KiB chunks, the size a PTY read hands over, and
// the terminal is sized to the same 170x50 grid the render comparison uses.

import 'package:xterm3/src/core/escape/parser.dart';
import 'package:xterm3/src/terminal.dart';

import 'noop_escape_handler.dart';

const _columns = 170;
const _rows = 50;
const _chunkSize = 8192;
const _totalBytes = 32 * 1024 * 1024;

void main(List<String> args) {
  final workloads = <String, String Function(int)>{
    'ascii': _asciiChunk,
    'ascii-long-lines': _longLineChunk,
    'sgr': _sgrChunk,
    'utf8': _utf8Chunk,
    'cyrillic': _cyrillicChunk,
    'altscreen': _altScreenChunk,
  };

  print('grid ${_columns}x$_rows, '
      '${_totalBytes ~/ (1024 * 1024)} MiB per workload in '
      '${_chunkSize ~/ 1024} KiB chunks');
  print('');
  print('workload            full   parser   buffer%  scrollback  no-grapheme');
  print('                  MiB/s    MiB/s              MiB/s        MiB/s');

  for (final entry in workloads.entries) {
    final chunks = _buildChunks(entry.value);

    final full = _measure(chunks, () {
      final terminal = Terminal(maxLines: 10000)..resize(_columns, _rows);
      return terminal.write;
    });

    // The same bytes through the parser with a handler that does nothing, so
    // the difference is everything the terminal does per token: cell writes,
    // scrolling, scrollback eviction, mode bookkeeping.
    //
    // [NoopEscapeHandler] implements every member explicitly. It must never
    // grow a `noSuchMethod` - see that file's header for the measurement
    // that fell over when it had one.
    final parserOnly = _measure(chunks, () {
      final parser = EscapeParser(NoopEscapeHandler());
      return parser.write;
    });

    // No scrollback at all. Against `full`, the difference is the cost of
    // retaining and evicting lines.
    final noScrollback = _measure(chunks, () {
      final terminal = Terminal(maxLines: 0)..resize(_columns, _rows);
      return terminal.write;
    });

    // DEC mode 2027 off: no grapheme cluster bookkeeping per code point.
    // Against `full`, the difference is what cluster detection costs.
    final noGraphemes = _measure(chunks, () {
      final terminal = Terminal(maxLines: 10000)
        ..resize(_columns, _rows)
        ..write('\x1b[?2027l');
      return terminal.write;
    });

    final bufferShare = (1 - full / parserOnly) * 100;

    print('${entry.key.padRight(18)}'
        '${full.toStringAsFixed(0).padLeft(5)}'
        '${parserOnly.toStringAsFixed(0).padLeft(9)}'
        '${bufferShare.toStringAsFixed(0).padLeft(9)}%'
        '${noScrollback.toStringAsFixed(0).padLeft(11)}'
        '${noGraphemes.toStringAsFixed(0).padLeft(13)}');
  }

  print('');
  print('full       = Terminal.write, 10000 lines of scrollback');
  print('parser     = EscapeParser with a complete do-nothing handler');
  print('buffer%    = share of full-path time that is not parsing');
  print('scrollback = Terminal.write with scrollback disabled');
  print('no-grapheme = Terminal.write with DEC mode 2027 off');
}

/// Runs [chunks] through a freshly built write function and returns MiB/s.
///
/// [build] is called inside the timed region's setup, not inside it, so
/// terminal construction is not counted.
double _measure(List<String> chunks, void Function(String) Function() build) {
  final write = build();

  // One pass to let the JIT/AOT warm its inline caches before the timed pass.
  for (var i = 0; i < 8; i++) {
    write(chunks[i % chunks.length]);
  }

  final stopwatch = Stopwatch()..start();
  var bytes = 0;
  var index = 0;
  while (bytes < _totalBytes) {
    final chunk = chunks[index++ % chunks.length];
    write(chunk);
    bytes += chunk.length;
  }
  stopwatch.stop();

  return bytes / 1024 / 1024 / (stopwatch.elapsedMicroseconds / 1000000);
}

/// Builds a ring of distinct chunks, so the workload does not degenerate into
/// writing one string the caches have already seen.
List<String> _buildChunks(String Function(int) generator) {
  return List.generate(16, generator, growable: false);
}

/// Ordinary program output: `ls -l`-shaped lines, all printable ASCII.
String _asciiChunk(int seed) {
  final buffer = StringBuffer();
  var line = seed * 1000;
  while (buffer.length < _chunkSize) {
    buffer.write('-rw-r--r--  1 user  staff  ${line * 7919 % 1000000} '
        'Aug  2 12:${(line % 60).toString().padLeft(2, '0')} '
        'file_${line}_with_a_reasonably_long_name.dart\r\n');
    line++;
  }
  return buffer.toString();
}

/// Lines several times wider than the terminal, so most of the cost is
/// wrapping rather than line feeds.
String _longLineChunk(int seed) {
  final buffer = StringBuffer();
  var word = seed * 1000;
  while (buffer.length < _chunkSize) {
    final line = StringBuffer();
    while (line.length < _columns * 4) {
      line.write('token_${word % 9973}=${word * 7919 % 100000} ');
      word++;
    }
    buffer.write(line);
    buffer.write('\r\n');
  }
  return buffer.toString();
}

/// Colored output - a build log or a grep with highlighting. Same glyphs as
/// `ascii`, but the parser leaves the text fast path on every segment.
String _sgrChunk(int seed) {
  final buffer = StringBuffer();
  var line = seed * 1000;
  while (buffer.length < _chunkSize) {
    for (var segment = 0; segment < 6; segment++) {
      buffer.write('\x1b[38;5;${(line * 13 + segment * 31) % 256}m');
      buffer.write('segment${segment}_of_line_$line ');
    }
    buffer.write('\x1b[0m\r\n');
    line++;
  }
  return buffer.toString();
}

/// Non-ASCII text, which cannot use the printable-ASCII run fast path.
String _utf8Chunk(int seed) {
  final buffer = StringBuffer();
  var line = seed * 1000;
  while (buffer.length < _chunkSize) {
    buffer.write('satır $line — ölçüm değeri ${line * 7919 % 100000} '
        'açıklama_metni_$line şüpheli\r\n');
    line++;
  }
  return buffer.toString();
}

/// Cyrillic, which sits in the second range the single-cell run scan covers.
String _cyrillicChunk(int seed) {
  final buffer = StringBuffer();
  var line = seed * 1000;
  while (buffer.length < _chunkSize) {
    buffer.write('строка $line значение измерения ${line * 7919 % 100000} '
        'описание_текста_$line подозрительно\r\n');
    line++;
  }
  return buffer.toString();
}

/// A TUI redrawing itself: alternate screen, cursor addressing, no scrolling.
String _altScreenChunk(int seed) {
  final buffer = StringBuffer();
  var frame = seed * 100;
  while (buffer.length < _chunkSize) {
    for (var row = 0; row < _rows; row++) {
      buffer.write('\x1b[${row + 1};1H');
      buffer.write('\x1b[48;5;${(row * 3 + frame) % 256}m');
      final bar = (frame + row) % _columns;
      for (var column = 0; column < _columns; column++) {
        buffer.write(column < bar ? '#' : ' ');
      }
      buffer.write('\x1b[0m');
    }
    frame++;
  }
  return buffer.toString();
}
