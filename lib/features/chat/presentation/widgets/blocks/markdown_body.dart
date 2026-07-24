import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

/// Returns the markdown body widget for a *finished* block, memoized by
/// (content, style) in an LRU cache. Finished bodies are pure functions of
/// their input, but list-window changes (history reveal, entry ramp) rebuild
/// every visible row wholesale — and GptMarkdown re-parses its content on
/// every build. Handing `Element.updateChild` the *identical* widget instance
/// makes it skip the whole subtree, so the visible bodies are parsed and laid
/// out once per (content, style) instead of once per list rebuild.
Widget finishedMarkdown(String content, TextStyle? style) {
  final key = (content, style);
  final cached = _finishedMarkdownCache.remove(key);
  if (cached != null) {
    _finishedMarkdownCache[key] = cached; // re-insert as most recently used
    return cached;
  }
  final built = AppMarkdown(content: content, style: style);
  _finishedMarkdownCache[key] = built;
  if (_finishedMarkdownCache.length > _kFinishedMarkdownCacheLimit) {
    _finishedMarkdownCache.remove(_finishedMarkdownCache.keys.first);
  }
  return built;
}

const int _kFinishedMarkdownCacheLimit = 512;
final Map<(String, TextStyle?), Widget> _finishedMarkdownCache = {};

/// Target size (chars) of one markdown chunk — small enough that a single
/// chunk's parse + text layout fits a 120Hz frame's budget.
const int _kMarkdownChunkSize = 3000;

/// Chunk size for the *streaming* split: bounds how much text the active
/// tail re-parses per frame while keeping the widget count modest.
const int _kStreamingChunkSize = 512;

/// Renders a streaming markdown body as a column of paragraph chunks with
/// per-chunk widget reuse. During a stream the text is append-only, so every
/// chunk except the last is stable: its cached [AppMarkdown] instance is
/// returned identically, which makes Flutter skip that subtree's rebuild
/// entirely. Only the growing tail chunk is re-parsed on each delta.
class StreamingMarkdownBody extends StatefulWidget {
  const StreamingMarkdownBody({required this.content, this.style, super.key});

  final String content;
  final TextStyle? style;

  @override
  State<StreamingMarkdownBody> createState() => _StreamingMarkdownBodyState();
}

class _StreamingMarkdownBodyState extends State<StreamingMarkdownBody> {
  final List<String> _chunkTexts = [];
  final List<Widget> _chunkWidgets = [];
  TextStyle? _cachedStyle;

  @override
  Widget build(BuildContext context) {
    if (widget.style != _cachedStyle) {
      // Theme/style change invalidates every cached chunk.
      _cachedStyle = widget.style;
      _chunkTexts.clear();
      _chunkWidgets.clear();
    }
    final chunks = splitMarkdownChunks(
      widget.content,
      chunkSize: _kStreamingChunkSize,
    );
    if (chunks.length == 1) {
      _chunkTexts.clear();
      _chunkWidgets.clear();
      return _StreamTailFade(
        child: AppMarkdown(content: chunks.first, style: widget.style),
      );
    }
    if (_chunkTexts.length > chunks.length) {
      // Content was reset/shrunk (e.g. 重试) — drop stale cache entries.
      _chunkTexts.removeRange(chunks.length, _chunkTexts.length);
      _chunkWidgets.removeRange(chunks.length, _chunkWidgets.length);
    }
    for (var i = 0; i < chunks.length; i++) {
      final cached = i < _chunkTexts.length;
      if (cached && _chunkTexts[i] == chunks[i]) continue;
      final built = AppMarkdown(content: chunks[i], style: widget.style);
      if (cached) {
        _chunkTexts[i] = chunks[i];
        _chunkWidgets[i] = built;
      } else {
        _chunkTexts.add(chunks[i]);
        _chunkWidgets.add(built);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < _chunkWidgets.length - 1; i++) _chunkWidgets[i],
        _StreamTailFade(child: _chunkWidgets.last),
      ],
    );
  }
}

/// Fades the bottom edge of the active streaming tail so freshly arrived
/// text “淡入” instead of popping in at full opacity — the Flutter take on
/// 千问 TypingTextView's per-character alpha gradient cursor trail. The fade
/// zone covers roughly the last line; as the text grows, earlier lines scroll
/// out of the zone and turn fully opaque. Only the tail chunk pays the
/// saveLayer, and only while streaming (finished messages render through
/// [AppMarkdown] directly).
class _StreamTailFade extends StatelessWidget {
  const _StreamTailFade({required this.child});

  final Widget child;

  /// Height (logical px) of the faded zone at the bottom of the tail chunk.
  static const double _fadeZone = 24;

  /// Alpha at the very end of the gradient — matches 千问's faintest
  /// cursor-trail step (0x4C ≈ 30%).
  static const Color _tailColor = Color(0x4CFFFFFF);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final h = bounds.height;
        final start = h <= _fadeZone ? 0.0 : 1 - _fadeZone / h;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.white, Colors.white, _tailColor],
          stops: [0, start, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// Splits [src] into rendering chunks of roughly [chunkSize] chars
/// (default [_kMarkdownChunkSize]).
///
/// Cuts only at blank-line paragraph boundaries that are *outside* fenced
/// code blocks, and never right before a continuation-looking line (list
/// item, indent, blockquote, table row) so lists / tables / quotes stay in
/// one chunk. Returns `[src]` unchanged when it's short enough.
List<String> splitMarkdownChunks(String src, {int? chunkSize}) {
  final minChunk = chunkSize ?? _kMarkdownChunkSize;
  if (src.length <= minChunk * 2) return [src];
  final lines = src.split('\n');
  final chunks = <String>[];
  final current = StringBuffer();
  var currentLen = 0;
  var inFence = false;

  bool isContinuation(String line) {
    final t = line.trimLeft();
    if (t.isEmpty) return false;
    if (line.startsWith(' ') || line.startsWith('\t')) return true;
    return t.startsWith('- ') ||
        t.startsWith('* ') ||
        t.startsWith('+ ') ||
        t.startsWith('>') ||
        t.startsWith('|') ||
        RegExp(r'^\d+[.)] ').hasMatch(t);
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final fenceMark = RegExp(r'^\s*(```|~~~)').hasMatch(line);
    if (fenceMark) inFence = !inFence;

    if (!inFence &&
        !fenceMark &&
        line.trim().isEmpty &&
        currentLen >= minChunk) {
      // Cut here unless the next non-empty line continues this construct.
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      if (j >= lines.length || !isContinuation(lines[j])) {
        chunks.add(current.toString());
        current.clear();
        currentLen = 0;
        continue; // drop the separating blank line
      }
    }
    if (currentLen > 0) {
      current.write('\n');
      currentLen++;
    }
    current.write(line);
    currentLen += line.length;
  }
  if (currentLen > 0) chunks.add(current.toString());
  return chunks.isEmpty ? [src] : chunks;
}
