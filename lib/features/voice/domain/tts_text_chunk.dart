/// A single chunk of text prepared for TTS synthesis, with offset tracking for
/// seeking support. Ported from Kelivo's `TtsTextChunker`.
class TtsTextChunk {
  const TtsTextChunk({
    required this.index,
    required this.text,
    required this.startOffset,
  });

  final int index;
  final String text;
  final int startOffset;

  int get endOffset => startOffset + text.length;
}
